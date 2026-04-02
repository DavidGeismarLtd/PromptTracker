# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Functions
      # Central registry of all function classes and their tool definitions.
      #
      # Each function class exposes a `self.tool_definition` class method
      # that returns the JSON schema hash for the LLM tool call.
      #
      # This replaces the ~340 lines of hardcoded schema that previously
      # lived in AssistantChatbotService.
      module Registry
        # Ordered list of all function classes.
        FUNCTION_CLASSES = [
          Functions::CreatePrompt,
          Functions::CreateDataset,
          Functions::GenerateTests,
          Functions::RunTests,
          Functions::DeployAgent,
          Functions::GetPromptVersionInfo,
          Functions::GetTestsSummary,
          Functions::AvailableTestsForPromptVersion,
          Functions::AvailableDatasetsForPromptVersion,
          Functions::SearchPrompts
        ].freeze

        # Action functions that require user confirmation before execution.
        ACTION_FUNCTION_NAMES = %w[
          create_prompt
          create_dataset
          generate_tests
          run_tests
          deploy_agent
        ].freeze

        # Return all tool definitions.
        def self.all_tool_definitions
          FUNCTION_CLASSES.map(&:tool_definition)
        end

        # Return tool definitions filtered by allowed names.
        def self.tool_definitions_for(allowed_names)
          FUNCTION_CLASSES
            .select { |klass| allowed_names.include?(klass.tool_definition[:name]) }
            .map(&:tool_definition)
        end

        # Whether this function requires user confirmation.
        def self.requires_confirmation?(function_name)
          ACTION_FUNCTION_NAMES.include?(function_name)
        end

        # Look up a function class by name.
        def self.find_function_class(name)
          FUNCTION_CLASSES.find { |klass| klass.tool_definition[:name] == name }
        end
      end
    end
  end
end
