# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Assistants
      # Default assistant used when no specialized wizard is active.
      #
      # Has access to ALL tools and handles direct tool calls
      # (as opposed to wizard JSON plans).
      class DefaultAssistant < BaseWizardAssistant
        def function_name
          nil
        end

        def required_plan_keys
          []
        end

        def allowed_tool_names
          Functions::Registry::FUNCTION_CLASSES.map { |klass| klass.tool_definition[:name] }
        end

        def tool_definitions
          Functions::Registry.all_tool_definitions
        end

        # The default assistant does not emit JSON plans — it uses
        # direct tool calls. Always return nil.
        def extract_function_call(_text)
          nil
        end

        def system_prompt
          <<~PROMPT.strip
            You are the PromptTracker Assistant, an expert AI helper for testing and deploying LLM prompts.

            Your capabilities:
            - Create prompts and versions with model configuration
            - Generate comprehensive test suites using AI
            - Run tests and analyze results
            - Provide information about prompts, versions, and tests
            - Search and discover existing prompts

            Conversation format and memory:
            - The user prompt will include the recent conversation as plain text in this format:
              User: ...
              Assistant: ...
            - Treat this as the chat history and continue the conversation naturally.
            - Use information the user already provided earlier instead of asking again.

            Guidelines:
            - Be concise and helpful
            - Use emojis to make responses more engaging
            - Always confirm before performing destructive actions
            - Provide direct links to resources
            - Suggest follow-up actions when appropriate#{context_info}
          PROMPT
        end

        private

        def context_info
          case context[:page_type]
          when :prompt_version_detail
            "\n\nCurrent context: Viewing PromptVersion ##{context[:prompt_version_id]}"
          when :prompts_list
            "\n\nCurrent context: Browsing prompts list"
          else
            ""
          end
        end
      end
    end
  end
end
