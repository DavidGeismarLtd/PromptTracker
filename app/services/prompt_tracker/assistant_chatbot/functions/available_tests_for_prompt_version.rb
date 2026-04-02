# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Functions
      # Read-only helper that lists enabled tests for a PromptVersion.
      #
      # Used by the assistant as a discovery step before deciding which
      # tests to run in the run_tests wizard.
      #
      # Arguments:
      # - prompt_version_id: (required) ID of the prompt version
      #
      # The result message is a human-readable summary that includes test
      # IDs and names so the model can ask the user to pick specific tests
      # or run them all.
      class AvailableTestsForPromptVersion < Base
        def self.tool_definition
          {
            name: "available_tests_for_prompt_version",
            description: "List enabled tests for a PromptVersion to help choose which tests to run.",
            parameters: {
              type: "object",
              properties: {
                prompt_version_id: { type: "integer", description: "ID of the prompt version" }
              },
              required: %w[prompt_version_id]
            }
          }
        end

        protected

        def execute
          version = find_prompt_version
          tests = version.tests.enabled.order(created_at: :desc)

          if tests.empty?
            return success(
              <<~MSG.strip,
              ℹ️ There are currently no enabled tests for PromptVersion ##{version.id}.

              You can ask me to generate tests for this prompt version, or create them manually from the Testing tab.
              MSG
              links: build_links(version)
            )
          end

          list_lines = tests.map do |test|
            "- ID #{test.id}: #{test.name}"
          end.join("\n")

          message = <<~MSG.strip
            ✅ Here are the enabled tests for PromptVersion ##{version.id}:

            #{list_lines}

            Use these IDs when deciding whether to run all tests or only a subset.
          MSG

          success(message, links: build_links(version))
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

        def build_links(version)
          base_path = "/prompt_tracker/testing/prompts/#{version.prompt_id}/versions/#{version.id}"

          [
            link("Open tests tab", "#{base_path}#tests", icon: "list-check")
          ]
        end
      end
    end
  end
end
