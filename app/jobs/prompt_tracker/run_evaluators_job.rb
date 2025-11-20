# frozen_string_literal: true

module PromptTracker
  # Background job to run evaluators for a test run asynchronously.
  #
  # This job is enqueued after the LLM response is received to run all
  # configured evaluators (human, llm_judge, automated) in the background.
  #
  # @example Enqueue the job
  #   RunEvaluatorsJob.perform_later(test_run.id)
  #
  class RunEvaluatorsJob < ApplicationJob
    queue_as :prompt_tracker_evaluators

    # Run evaluators for a test run
    #
    # @param test_run_id [Integer] the ID of the test run
    def perform(test_run_id)
      Rails.logger.info "🔧 RunEvaluatorsJob started for test_run #{test_run_id}"

      test_run = PromptTestRun.find(test_run_id)

      # Skip if already completed or no LLM response
      if test_run.completed?
        Rails.logger.info "⏭️  Test run #{test_run_id} already completed, skipping"
        return
      end

      unless test_run.llm_response
        Rails.logger.warn "⚠️  Test run #{test_run_id} has no LLM response, skipping"
        return
      end

      # Mark as running
      test_run.update!(status: "running")
      Rails.logger.info "▶️  Test run #{test_run_id} marked as running"

      # Get the test and version
      prompt_test = test_run.prompt_test
      llm_response = test_run.llm_response

      # Run evaluators
      evaluator_results = run_evaluators(prompt_test, llm_response)
      Rails.logger.info "📊 Evaluators completed: #{evaluator_results.length} results"

      # Run assertions
      assertion_results = check_assertions(prompt_test, llm_response)
      Rails.logger.info "✅ Assertions checked: #{assertion_results.length} assertions"

      # Determine if test passed
      evaluators_passed = evaluator_results.all? { |r| r[:passed] }
      assertions_passed = assertion_results.values.all?
      passed = evaluators_passed && assertions_passed

      # Update test run with results
      passed_evaluators = evaluator_results.count { |r| r[:passed] }
      failed_evaluators = evaluator_results.count { |r| !r[:passed] }

      test_run.update!(
        status: passed ? "passed" : "failed",
        passed: passed,
        evaluator_results: evaluator_results,
        assertion_results: assertion_results,
        passed_evaluators: passed_evaluators,
        failed_evaluators: failed_evaluators,
        total_evaluators: evaluator_results.length
      )

      Rails.logger.info "✨ Test run #{test_run_id} completed: #{passed ? 'PASSED' : 'FAILED'}"

      # Broadcast update via ActionCable
      broadcast_test_run_update(test_run)
      Rails.logger.info "📡 Broadcast sent for test run #{test_run_id}"
    end

    private

    # Run all configured evaluators
    #
    # @param prompt_test [PromptTest] the test configuration
    # @param llm_response [LlmResponse] the LLM response to evaluate
    # @return [Array<Hash>] array of evaluator results
    def run_evaluators(prompt_test, llm_response)
      results = []
      evaluator_configs = prompt_test.evaluator_configs || []

      evaluator_configs.each do |config|
        config = config.with_indifferent_access
        evaluator_key = config[:evaluator_key].to_sym
        threshold = config[:threshold] || 0
        evaluator_config = config[:config] || {}

        # Build and run evaluator
        evaluator = EvaluatorRegistry.build(evaluator_key, llm_response, evaluator_config)
        next unless evaluator

        # All evaluators now use RubyLLM directly - no block needed!
        evaluation = evaluator.evaluate

        # Check if score meets threshold
        passed = evaluation.score >= threshold

        results << {
          evaluator_key: evaluator_key.to_s,
          score: evaluation.score,
          threshold: threshold,
          passed: passed,
          feedback: evaluation.feedback
        }
      end

      results
    end

    # Check all configured assertions
    #
    # @param prompt_test [PromptTest] the test configuration
    # @param llm_response [LlmResponse] the LLM response to check
    # @return [Hash] hash of assertion name => passed (boolean)
    def check_assertions(prompt_test, llm_response)
      results = {}
      response_text = llm_response.response_text || ""

      # Check expected output (exact match)
      if prompt_test.expected_output.present?
        results["expected_output"] = response_text.strip == prompt_test.expected_output.strip
      end

      # Check expected patterns (regex)
      if prompt_test.expected_patterns.present?
        prompt_test.expected_patterns.each_with_index do |pattern, index|
          results["pattern_#{index + 1}"] = Regexp.new(pattern).match?(response_text)
        end
      end

      results
    end

    # Broadcast test run update via Turbo Streams
    #
    # @param test_run [PromptTestRun] the test run that was updated
    def broadcast_test_run_update(test_run)
      test = test_run.prompt_test
      version = test_run.prompt_version
      prompt = version.prompt

      # Broadcast to test run detail page (trigger refresh)
      Turbo::StreamsChannel.broadcast_refresh_to("test_run_#{test_run.id}")

      # Broadcast to tests index page - update test row
      broadcast_turbo_stream_replace(
        stream: "prompt_version_#{version.id}",
        target: "test_row_#{test.id}",
        partial: "prompt_tracker/prompt_tests/test_row",
        locals: { test: test, prompt: prompt, version: version }
      )

      # Broadcast to tests index page - update overall status card
      all_tests = version.prompt_tests.order(created_at: :desc)
      broadcast_turbo_stream_replace(
        stream: "prompt_version_#{version.id}",
        target: "overall_status_card",
        partial: "prompt_tracker/prompt_tests/overall_status_card",
        locals: { tests: all_tests }
      )

      # Broadcast to individual test detail page - update status card
      broadcast_turbo_stream_replace(
        stream: "prompt_test_#{test.id}",
        target: "test_status_card",
        partial: "prompt_tracker/prompt_tests/test_status_card",
        locals: { test: test }
      )

      # Broadcast to individual test detail page - update test run row in recent runs table
      broadcast_turbo_stream_replace(
        stream: "prompt_test_#{test.id}",
        target: "test_run_row_#{test_run.id}",
        partial: "prompt_tracker/prompt_tests/test_run_row",
        locals: { run: test_run }
      )
    end

    # Helper to broadcast Turbo Stream replace with proper route context
    #
    # @param stream [String] the stream name
    # @param target [String] the DOM target ID
    # @param partial [String] the partial path
    # @param locals [Hash] the locals to pass to the partial
    def broadcast_turbo_stream_replace(stream:, target:, partial:, locals:)
      # Render with ApplicationController to include helpers
      html = PromptTracker::ApplicationController.render(
        partial: partial,
        locals: locals
      )
      Turbo::StreamsChannel.broadcast_replace_to(
        stream,
        target: target,
        html: html
      )
    end
  end
end
