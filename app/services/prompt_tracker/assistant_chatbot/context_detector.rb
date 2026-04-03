# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    # Detects page context and generates relevant suggestions.
    #
    # @example Generate suggestions
    #   suggestions = ContextDetector.suggestions_for({
    #     page_type: :prompt_version_detail,
    #     version_id: 123
    #   })
    #
    class ContextDetector
      def self.suggestions_for(context)
        new(context).suggestions
      end

      def initialize(context)
        @context = context
      end

      def suggestions
        case @context[:page_type]
        when :prompt_version_detail
          prompt_version_suggestions
        when :prompt_detail
          prompt_suggestions
        when :prompts_list
          prompts_list_suggestions
        when :playground
          playground_suggestions
        when :monitoring
          monitoring_suggestions
        when :agents
          agents_suggestions
        else
          general_suggestions
        end
      end

      private

      def prompt_version_suggestions
        [
          "Write tests for this prompt",
          "Run all tests",
          "Deploy Agent",
          "What model is this prompt using?",
          "Show me a summary of the tests",
          "Create a dataset for this prompt version"
        ]
      end

      def prompt_suggestions
        [
          "Show me the latest version",
          "Create a new version",
          "How many tests are there?"
        ]
      end

      def prompts_list_suggestions
        [
          "Create a new prompt",
          "Show me prompts with failing tests",
          "Find prompts using gpt-4"
        ]
      end

      def playground_suggestions
        [
          "Save this as a new prompt",
          "Generate tests for this configuration",
          "What's the token usage?"
        ]
      end

      def monitoring_suggestions
        [
          "Show me recent errors",
          "Which prompts are being used most?",
          "Analyze test results"
        ]
      end

      def agents_suggestions
        [
          "Deploy a new agent",
          "Show me active agents",
          "Check agent performance"
        ]
      end

      def general_suggestions
        [
          "Create a new prompt",
          "Show me my recent work",
          "Help me get started"
        ]
      end
    end
  end
end
