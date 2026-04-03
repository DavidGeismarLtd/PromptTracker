# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Functions
      # Runs tests for a PromptVersion.
      #
      # This function is used by the assistant as the final step of a
      # conversational wizard. By the time it is called, the assistant
      # should already have:
      # - Decided which tests to run (all enabled or a subset of IDs)
      # - Chosen between running against a dataset vs custom variables
      # - Collected values for all required variables when using
      #   custom_variables.
      #
      # Arguments:
      # - prompt_version_id: (required) ID of the prompt version
      # - test_ids: (optional) Array of specific test IDs to run. If omitted, runs all tests.
      # - run_mode: (required) "dataset" or "custom"
      # - dataset_id: (required when run_mode == "dataset") ID of the dataset to use
      # - execution_mode: (optional, custom runs only) "single" or "conversation" (default: "single")
      # - custom_variables: (required when run_mode == "custom") Hash of variables to use
      #
      # For dataset runs, execution_mode is inferred from the dataset's
      # dataset_type (single_turn vs conversational).
      #
      class RunTests < Base
        def self.tool_definition
          {
            name: "run_tests",
            description: "Run tests for a PromptVersion using either datasets or custom variables.",
            parameters: {
              type: "object",
              properties: {
                prompt_version_id: { type: "integer", description: "ID of the prompt version" },
                test_ids: { type: "array", items: { type: "integer" }, description: "Specific test IDs to run (optional, runs all if omitted)" },
                run_mode: { type: "string", description: "How to run the tests: 'dataset' to run against a dataset, or 'custom' to run once with custom variables.", enum: %w[dataset custom] },
                dataset_id: { type: "integer", description: "Dataset to run tests against (required when run_mode is 'dataset')." },
                execution_mode: { type: "string", description: "Execution mode for custom runs: 'single' for a single-turn response or 'conversation' for a multi-turn simulated conversation (default: 'single').", enum: %w[single conversation] },
                custom_variables: { type: "object", description: "Custom variables to use for a single run when not using a dataset. Keys should match variable names from the prompt version's variables_schema. For conversational runs, MUST include interlocutor_simulation_prompt and MAY include max_turns." }
              },
              required: %w[prompt_version_id run_mode]
            }
          }
        end

        protected

        def execute
          version = find_prompt_version
          tests = find_tests(version)
          run_mode = determine_run_mode

          case run_mode
          when "dataset"
            dataset = find_dataset(version)
            execution_mode = dataset.conversational? ? "conversation" : "single"
            total_runs = queue_dataset_runs(tests, dataset, execution_mode)

            success(
              build_success_message(version, tests, dataset, total_runs),
              links: build_links(version),
              entities: { test_ids: tests.map(&:id) }
            )
          when "custom"
            custom_vars = arg(:custom_variables) || {}
            execution_mode = (arg(:execution_mode).presence || "single").to_s

            validate_custom_variables!(version, custom_vars, execution_mode)

            total_runs = queue_custom_runs(tests, custom_vars, execution_mode)

            success(
              build_success_message(version, tests, nil, total_runs, execution_mode: execution_mode),
              links: build_links(version),
              entities: { test_ids: tests.map(&:id) }
            )
          else
            raise ArgumentError, "run_mode must be 'dataset' or 'custom'"
          end
        end

        def validate_arguments!
          raise ArgumentError, "prompt_version_id is required" if arg(:prompt_version_id).blank?
          raise ArgumentError, "run_mode is required" if arg(:run_mode).blank?
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

        def determine_run_mode
          value = arg(:run_mode)
          mode = value.to_s

          return mode if %w[dataset custom].include?(mode)

          raise ArgumentError, "run_mode must be 'dataset' or 'custom'"
        end

        def find_dataset(version)
          dataset_id = arg(:dataset_id)
          raise ArgumentError, "dataset_id is required when run_mode is 'dataset'" if dataset_id.blank?

          dataset = version.datasets.find_by(id: dataset_id)
          raise ArgumentError, "Dataset #{dataset_id} not found" unless dataset

          dataset
        end

        def required_custom_run_variables(version, execution_mode: "single")
          base_required = (version.variables_schema || [])
                           .select { |v| v["required"] }
                           .map { |v| v["name"] }

          if execution_mode.to_s == "conversation"
            conversational_required = Dataset::CONVERSATIONAL_FIELDS
                                      .select { |v| v["required"] }
                                      .map { |v| v["name"] }

            (base_required + conversational_required).uniq
          else
            base_required
          end
        end

          def validate_custom_variables!(version, custom_vars, execution_mode)
            required_vars = required_custom_run_variables(version, execution_mode: execution_mode)
            missing_vars = required_vars.select { |var| custom_vars[var].blank? }

          if missing_vars.any?
            human_list = missing_vars.map { |var| var.tr("_", " ") }.join(", ")
            raise ArgumentError, "Missing required custom variables: #{human_list}"
          end
        end

        def queue_dataset_runs(tests, dataset, execution_mode)
          total_runs = 0
          use_real_llm = true # Chatbot actions always use real LLM

          tests.each do |test|
            dataset.dataset_rows.each do |row|
              test_run = TestRun.create!(
                test: test,
                dataset: dataset,
                dataset_row: row,
                status: "running",
                metadata: {
                  triggered_by: "assistant_chatbot",
                  run_mode: "dataset",
                  execution_mode: execution_mode
                }
              )

              RunTestJob.perform_later(test_run.id, use_real_llm: use_real_llm)
              total_runs += 1
            end
          end

          total_runs
        end

        def queue_custom_runs(tests, custom_vars, execution_mode)
          total_runs = 0
          use_real_llm = true # Chatbot actions always use real LLM

          tests.each do |test|
            test_run = TestRun.create!(
              test: test,
              status: "running",
              metadata: {
                triggered_by: "assistant_chatbot",
                run_mode: "custom",
                execution_mode: execution_mode,
                custom_variables: custom_vars
              }
            )

            RunTestJob.perform_later(test_run.id, use_real_llm: use_real_llm)
            total_runs += 1
          end

          total_runs
        end

        def build_success_message(version, tests, dataset, total_runs, execution_mode: nil)
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
              mode_label = execution_mode == "conversation" ? "with a conversational custom scenario" : "with a custom scenario"

              <<~MSG.strip
	              🚀 Running #{tests.size} test#{tests.size == 1 ? '' : 's'} #{mode_label}!

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
