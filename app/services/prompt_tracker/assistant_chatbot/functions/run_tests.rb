# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Functions
      # Runs tests for a PromptVersion.
      #
      # Arguments:
      # - prompt_version_id: (required) ID of the prompt version
      # - test_ids: (optional) Array of specific test IDs to run. If omitted, runs all tests.
      # - dataset_id: (optional) Dataset to run tests against
      #
      # @example Run all tests
      #   function = RunTests.new({ prompt_version_id: 123 }, {})
      #   result = function.call
      #
      # @example Run specific tests
      #   function = RunTests.new({ prompt_version_id: 123, test_ids: [1, 2, 3] }, {})
      #   result = function.call
      #
      class RunTests < Base
        protected

        def execute
          version = find_prompt_version
          tests = find_tests(version)
          dataset = find_dataset(version) if arg(:dataset_id).present?

          # Queue test runs
          total_runs = queue_test_runs(tests, dataset)

          success(
            build_success_message(version, tests, dataset, total_runs),
            links: build_links(version),
            entities: { test_ids: tests.map(&:id) }
          )
        end

        def validate_arguments!
          raise ArgumentError, "prompt_version_id is required" if arg(:prompt_version_id).blank?
        end

        private

        def find_prompt_version
          version_id = arg(:prompt_version_id)
          version = PromptVersion.find_by(id: version_id)
          raise ArgumentError, "PromptVersion #{version_id} not found" unless version
          version
        end

        def find_tests(version)
          test_ids = arg(:test_ids)

          if test_ids.present?
            tests = version.tests.where(id: test_ids, enabled: true)
            raise ArgumentError, "No enabled tests found with IDs: #{test_ids.join(', ')}" if tests.empty?
            tests
          else
            tests = version.tests.enabled
            raise ArgumentError, "No enabled tests found for this prompt version" if tests.empty?
            tests
          end
        end

        def find_dataset(version)
          dataset_id = arg(:dataset_id)
          dataset = version.datasets.find_by(id: dataset_id)
          raise ArgumentError, "Dataset #{dataset_id} not found" unless dataset
          dataset
        end

        def queue_test_runs(tests, dataset)
          total_runs = 0
          use_real_llm = true # Chatbot actions always use real LLM

          tests.each do |test|
            if dataset.present?
              # Run with dataset: create test run for each dataset row
              dataset.dataset_rows.each do |row|
                test_run = TestRun.create!(
                  test: test,
                  dataset: dataset,
                  dataset_row: row,
                  status: "running",
                  metadata: {
                    triggered_by: "assistant_chatbot",
                    run_mode: "dataset"
                  }
                )
                RunTestJob.perform_later(test_run.id, use_real_llm: use_real_llm)
                total_runs += 1
              end
            else
              # Run without dataset: single test run
              test_run = TestRun.create!(
                test: test,
                status: "running",
                metadata: {
                  triggered_by: "assistant_chatbot",
                  run_mode: "single"
                }
              )
              RunTestJob.perform_later(test_run.id, use_real_llm: use_real_llm)
              total_runs += 1
            end
          end

          total_runs
        end

        def build_success_message(version, tests, dataset, total_runs)
          test_names = tests.first(3).map(&:name).join(", ")
          test_names += ", ..." if tests.size > 3

          if dataset.present?
            <<~MSG.strip
              🚀 Running #{tests.size} test#{tests.size == 1 ? '' : 's'} with dataset "#{dataset.name}"!

              📋 Tests: #{test_names}
              📊 Total runs: #{total_runs} (#{tests.size} tests × #{dataset.dataset_rows.count} scenarios)

              ⏱️ Tests are running in the background. You'll see results appear in real-time on the prompt version page.
            MSG
          else
            <<~MSG.strip
              🚀 Running #{tests.size} test#{tests.size == 1 ? '' : 's'}!

              📋 Tests: #{test_names}

              ⏱️ Tests are running in the background. You'll see results appear in real-time on the prompt version page.
            MSG
          end
        end

        def build_links(version)
          base_path = "/prompt_tracker/testing/prompts/#{version.prompt_id}/versions/#{version.id}"

          [
            link("View test results", "#{base_path}#tests", icon: "list-check"),
            link("View prompt version", base_path, icon: "eye")
          ]
        end
      end
    end
  end
end
