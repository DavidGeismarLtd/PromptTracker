# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Functions
      # Generates tests for a PromptVersion using AI.
      #
      # Arguments:
      # - prompt_version_id: (required) ID of the prompt version
      # - count: (optional) Number of tests to generate (default: 5)
      # - instructions: (optional) Custom instructions for test generation
      #
      # @example
      #   function = GenerateTests.new(
      #     { prompt_version_id: 123, count: 5, instructions: "Focus on edge cases" },
      #     {}
      #   )
      #   result = function.call
      #
      class GenerateTests < Base
        def self.tool_definition
          {
            name: "generate_tests",
            description: "Generate AI-powered tests for a PromptVersion",
            parameters: {
              type: "object",
              properties: {
                prompt_version_id: { type: "integer", description: "ID of the prompt version to generate tests for" },
                count: { type: "integer", description: "Number of tests to generate (1-10, default: 5)" },
                instructions: { type: "string", description: "Custom instructions for test generation (optional)" }
              },
              required: %w[prompt_version_id]
            }
          }
        end

        protected

        def execute
          version = find_prompt_version
          count = arg(:count) || 5
          instructions = arg(:instructions)

          # Call TestGeneratorService
          result = TestGeneratorService.generate(
            prompt_version: version,
            instructions: instructions,
            count: count.to_i.clamp(1, 10)
          )

          success(
            build_success_message(version, result),
            links: build_links(version, result[:tests]),
            entities: { test_ids: result[:tests].map(&:id) }
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

        def build_success_message(version, result)
          tests = result[:tests]
          test_list = tests.first(5).map.with_index do |test, idx|
            "#{idx + 1}. \"#{test.name}\" - #{test.description}"
          end.join("\n")

          <<~MSG.strip
            ✅ Generated #{result[:count]} test#{result[:count] == 1 ? '' : 's'} successfully!

            📊 Test Summary:
            #{test_list}
            #{"... and #{tests.size - 5} more" if tests.size > 5}

            💭 Reasoning: #{result[:overall_reasoning]}

            Would you like to run all tests now?
          MSG
        end

        def build_links(version, tests)
          base_path = "/prompt_tracker/testing/prompts/#{version.prompt_id}/versions/#{version.id}"

          links = [
            link("View all tests", "#{base_path}#tests", icon: "list-check"),
            link("Run all tests", "#{base_path}#tests", icon: "play-circle")
          ]

          # Add links to individual tests (first 3)
          tests.first(3).each do |test|
            links << link("Test: #{test.name}", "#{base_path}#test-#{test.id}", icon: "check-circle")
          end

          links
        end
      end
    end
  end
end
