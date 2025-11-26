# frozen_string_literal: true

module PromptTracker
  # Background job to run a single prompt test.
  #
  # This job:
  # 1. Loads an existing PromptTestRun (created by controller with "running" status)
  # 2. Executes the LLM call (real or mock)
  # 3. Creates the LlmResponse
  # 4. Runs evaluators
  # 5. Updates the test run with results
  # 6. Broadcasts completion via Turbo Streams
  #
  # @example Enqueue a test run
  #   test_run = PromptTestRun.create!(prompt_test: test, prompt_version: version, status: "running")
  #   RunTestJob.perform_later(test_run.id, use_real_llm: true)
  #
  class RunTestJob < ApplicationJob
    queue_as :prompt_tracker_tests

    # Execute the test run
    #
    # @param test_run_id [Integer] ID of the PromptTestRun to execute
    # @param use_real_llm [Boolean] whether to use real LLM API or mock
    def perform(test_run_id, use_real_llm: false)
      Rails.logger.info "🚀 RunTestJob started for test_run #{test_run_id}"

      test_run = PromptTestRun.find(test_run_id)
      test = test_run.prompt_test
      version = test_run.prompt_version

      start_time = Time.current

      llm_response = execute_llm_call(test, version, use_real_llm)

      # Run evaluators
      evaluator_results = run_evaluators(test, llm_response, use_real_llm)

      # Determine if test passed (all evaluators must pass)
      passed = evaluator_results.all? { |r| r[:passed] }

      # Calculate execution time
      execution_time = ((Time.current - start_time) * 1000).to_i

      # Update test run with results
      update_test_run_success(
        test_run: test_run,
        llm_response: llm_response,
        evaluator_results: evaluator_results,
        passed: passed,
        execution_time_ms: execution_time
      )

      Rails.logger.info "✅ RunTestJob completed for test_run #{test_run_id}: #{passed ? 'PASSED' : 'FAILED'}"
    end

    private

    # Execute the LLM call
    #
    # @param test [PromptTest] the test to run
    # @param version [PromptVersion] the version to test
    # @param use_real_llm [Boolean] whether to use real LLM API
    # @return [LlmResponse] the LLM response record
    def execute_llm_call(test, version, use_real_llm)
      # Render the template
      renderer = TemplateRenderer.new(version.template)
      rendered_prompt = renderer.render(test.template_variables)

      # Get model config from test
      model_config = test.model_config.with_indifferent_access
      provider = model_config[:provider] || "openai"
      model = model_config[:model] || "gpt-4"

      # Call LLM (real or mock)
      if use_real_llm
        llm_api_response = call_real_llm(rendered_prompt, model_config)
      else
        llm_api_response = generate_mock_llm_response(rendered_prompt, model_config)
      end

      # Extract token usage and response text
      tokens = extract_token_usage(llm_api_response)
      response_text = extract_response_text(llm_api_response)

      # Create LlmResponse record (marked as test run to skip auto-evaluation)
      llm_response = LlmResponse.create!(
        prompt_version: version,
        rendered_prompt: rendered_prompt,
        variables_used: test.template_variables,
        provider: provider,
        model: model,
        response_text: response_text,
        tokens_prompt: tokens[:prompt],
        tokens_completion: tokens[:completion],
        tokens_total: tokens[:total],
        status: "success",
        is_test_run: true,
        response_metadata: { test_run: true }
      )

      # Calculate and update cost
      if tokens[:total] && tokens[:total] > 0
        cost = calculate_cost(provider, model, tokens[:prompt], tokens[:completion])
        llm_response.update!(cost_usd: cost) if cost
      end

      llm_response
    end

    # Call real LLM API
    #
    # @param rendered_prompt [String] the rendered prompt
    # @param model_config [Hash] the model configuration
    # @return [RubyLLM::Message] LLM API response
    def call_real_llm(rendered_prompt, model_config)
      config = model_config.with_indifferent_access
      provider = config[:provider] || "openai"
      model = config[:model] || "gpt-4"
      temperature = config[:temperature] || 0.7
      max_tokens = config[:max_tokens]

      Rails.logger.info "🔧 Calling REAL LLM: #{provider}/#{model}"

      LlmClientService.call(
        provider: provider,
        model: model,
        prompt: rendered_prompt,
        temperature: temperature,
        max_tokens: max_tokens
      )[:raw] # Return raw RubyLLM::Message
    end

    # Generate a mock LLM response for testing
    #
    # @param rendered_prompt [String] the rendered prompt
    # @param model_config [Hash] the model configuration
    # @return [Hash] mock LLM response in OpenAI format
    def generate_mock_llm_response(rendered_prompt, model_config)
      provider = model_config["provider"] || model_config[:provider] || "openai"

      Rails.logger.info "🎭 Generating MOCK LLM response for #{provider}"

      # Generate a realistic mock response based on the prompt
      mock_text = "This is a mock response to: #{rendered_prompt.truncate(100)}\n\n"
      mock_text += "In a production environment, this would be replaced with an actual API call to #{provider}.\n"
      mock_text += "The response would be generated by the configured model and would address the prompt appropriately."

      # Return in OpenAI-like format for compatibility
      {
        "choices" => [
          {
            "message" => {
              "content" => mock_text
            }
          }
        ]
      }
    end

    # Run evaluators
    #
    # @param test [PromptTest] the test
    # @param llm_response [LlmResponse] the LLM response to evaluate
    # @param use_real_llm [Boolean] whether to use real LLM for judge evaluators
    # @return [Array<Hash>] array of evaluator results
    def run_evaluators(test, llm_response, use_real_llm)
      evaluator_configs = test.evaluator_configs.enabled.order(:created_at)
      results = []

      evaluator_configs.each do |config|
        evaluator_key = config.evaluator_key.to_sym
        threshold = config.threshold || 0
        evaluator_config = config.config || {}

        # Build and run evaluator
        evaluator = EvaluatorRegistry.build(evaluator_key, llm_response, evaluator_config)

        # Check if this is an LLM judge evaluator that needs a block
        evaluation = if evaluator.is_a?(PromptTracker::Evaluators::LlmJudgeEvaluator)
          # Call with block to generate LLM judge response (real or mock)
          evaluator.evaluate do |judge_prompt|
            if use_real_llm
              Rails.logger.info "🚀 Using REAL LLM Judge API"
              call_real_llm_judge(judge_prompt, evaluator_config)
            else
              Rails.logger.info "🎭 Using MOCK LLM Judge response"
              generate_mock_judge_response(judge_prompt, evaluator_config)
            end
          end
        else
          # Regular evaluators don't need a block
          evaluator.evaluate
        end

        # Set evaluation context to test_run
        evaluation.update!(evaluation_context: "test_run")

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

    # Update test run with success
    #
    # @param test_run [PromptTestRun] the test run to update
    # @param llm_response [LlmResponse] the LLM response
    # @param evaluator_results [Array<Hash>] evaluator results
    # @param passed [Boolean] whether test passed
    # @param execution_time_ms [Integer] execution time in milliseconds
    def update_test_run_success(test_run:, llm_response:, evaluator_results:, passed:, execution_time_ms:)
      passed_evaluators = evaluator_results.count { |r| r[:passed] }
      failed_evaluators = evaluator_results.count { |r| !r[:passed] }

      test_run.update!(
        llm_response: llm_response,
        status: passed ? "passed" : "failed",
        passed: passed,
        evaluator_results: evaluator_results,
        passed_evaluators: passed_evaluators,
        failed_evaluators: failed_evaluators,
        total_evaluators: evaluator_results.length,
        execution_time_ms: execution_time_ms,
        cost_usd: llm_response.cost_usd
      )
    end

    # Broadcast Turbo Stream updates when test completes

    # Extract response text from LLM API response
    #
    # @param llm_api_response [Object] the LLM API response
    # @return [String] the response text
    def extract_response_text(llm_api_response)
      if llm_api_response.is_a?(String)
        llm_api_response
      elsif llm_api_response.is_a?(RubyLLM::Message)
        llm_api_response.content
      elsif llm_api_response.respond_to?(:dig)
        llm_api_response.dig("choices", 0, "message", "content") ||
          llm_api_response.dig(:choices, 0, :message, :content) ||
          llm_api_response.to_s
      else
        llm_api_response.to_s
      end
    end

    # Extract token usage from LLM API response
    #
    # @param llm_api_response [Object] the LLM API response
    # @return [Hash] hash with :prompt, :completion, :total keys
    def extract_token_usage(llm_api_response)
      if llm_api_response.is_a?(RubyLLM::Message)
        return {
          prompt: llm_api_response.input_tokens,
          completion: llm_api_response.output_tokens,
          total: (llm_api_response.input_tokens || 0) + (llm_api_response.output_tokens || 0)
        }
      end

      return { prompt: nil, completion: nil, total: nil } unless llm_api_response.respond_to?(:dig)

      {
        prompt: llm_api_response.dig("usage", "prompt_tokens") || llm_api_response.dig(:usage, :prompt_tokens),
        completion: llm_api_response.dig("usage", "completion_tokens") || llm_api_response.dig(:usage, :completion_tokens),
        total: llm_api_response.dig("usage", "total_tokens") || llm_api_response.dig(:usage, :total_tokens)
      }
    end

    # Calculate cost based on provider, model, and token usage
    #
    # @param provider [String] the LLM provider
    # @param model [String] the model name
    # @param prompt_tokens [Integer] number of prompt tokens
    # @param completion_tokens [Integer] number of completion tokens
    # @return [Float, nil] cost in USD or nil if pricing not available
    def calculate_cost(provider, model, prompt_tokens, completion_tokens)
      return nil unless prompt_tokens && completion_tokens

      # Pricing per 1M tokens (as of 2024)
      pricing = case provider.to_s.downcase
      when "openai"
        case model.to_s.downcase
        when /gpt-4o/
          { prompt: 2.50, completion: 10.00 }
        when /gpt-4-turbo/, /gpt-4-1106/, /gpt-4-0125/
          { prompt: 10.00, completion: 30.00 }
        when /gpt-4-32k/
          { prompt: 60.00, completion: 120.00 }
        when /gpt-4/
          { prompt: 30.00, completion: 60.00 }
        when /gpt-3.5-turbo/
          { prompt: 0.50, completion: 1.50 }
        else
          nil
        end
      when "anthropic"
        case model.to_s.downcase
        when /claude-3-opus/
          { prompt: 15.00, completion: 75.00 }
        when /claude-3-sonnet/
          { prompt: 3.00, completion: 15.00 }
        when /claude-3-haiku/
          { prompt: 0.25, completion: 1.25 }
        else
          nil
        end
      else
        nil
      end

      return nil unless pricing

      # Calculate cost: (tokens / 1,000,000) * price_per_million
      prompt_cost = (prompt_tokens / 1_000_000.0) * pricing[:prompt]
      completion_cost = (completion_tokens / 1_000_000.0) * pricing[:completion]

      prompt_cost + completion_cost
    end

    # Call real LLM API for judge evaluation
    #
    # @param judge_prompt [String] the prompt sent to the judge LLM
    # @param evaluator_config [Hash] the evaluator configuration
    # @return [String] judge response text
    def call_real_llm_judge(judge_prompt, evaluator_config)
      config = evaluator_config.with_indifferent_access
      judge_model = config[:judge_model] || "gpt-4"

      # Determine provider from model name
      provider = if judge_model.start_with?("gpt-", "o1-")
        "openai"
      elsif judge_model.start_with?("claude-")
        "anthropic"
      elsif judge_model.start_with?("gemini-")
        "google"
      else
        "openai"
      end

      response = LlmClientService.call(
        provider: provider,
        model: judge_model,
        prompt: judge_prompt,
        temperature: 0.3
      )

      response[:text]
    end

    # Generate a mock judge response for testing
    #
    # @param judge_prompt [String] the prompt sent to the judge LLM
    # @param evaluator_config [Hash] the evaluator configuration
    # @return [String] mock judge response with scores
    def generate_mock_judge_response(judge_prompt, evaluator_config)
      criteria = evaluator_config["criteria"] || evaluator_config[:criteria] || ["overall"]
      score_max = evaluator_config["score_max"] || evaluator_config[:score_max] || 100

      # Generate mock scores for each criterion (80-95% of max)
      criterion_scores = criteria.map do |criterion|
        score = rand(80..95) * score_max / 100.0
        "#{criterion}: #{score.round(1)}/#{score_max}"
      end.join("\n")

      # Calculate overall score (average of criteria)
      overall_score = (rand(80..95) * score_max / 100.0).round(1)

      # Return a structured response that the judge evaluator can parse
      <<~RESPONSE
        EVALUATION RESULTS:

        #{criterion_scores}

        Overall Score: #{overall_score}/#{score_max}

        Feedback: This is a mock evaluation for testing purposes. In production, this would be replaced with an actual LLM judge evaluation. The response meets the expected criteria and demonstrates good quality.

        Reasoning: The mock evaluator assigns high scores to simulate a passing test. In a real scenario, the LLM judge would analyze the response based on the specified criteria and provide detailed feedback.
      RESPONSE
    end
  end
end
