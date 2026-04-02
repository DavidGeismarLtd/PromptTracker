# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Assistants
      # Base class for all wizard assistants.
      #
      # Every wizard must implement:
      # - #system_prompt       → the system prompt string for the LLM
      # - #function_name       → the action function name (e.g. "run_tests")
      # - #required_plan_keys  → keys that must be present in the JSON plan
      # - #allowed_tool_names  → list of read-only tool names this wizard may use
      #
      # The base class provides:
      # - #tool_definitions    → filtered tool schemas from the function registry
      # - #extract_function_call(text) → parse JSON plan from LLM response text
      #
      class BaseWizardAssistant
        def initialize(context: {})
          @context = context || {}
        end

        # Subclasses must override
        def system_prompt
          raise NotImplementedError, "#{self.class.name} must implement #system_prompt"
        end

        # The action function name this wizard produces (e.g. "run_tests").
        # Return nil for wizards that only use tools and never emit a plan.
        def function_name
          raise NotImplementedError, "#{self.class.name} must implement #function_name"
        end

        # Keys that must be present in the JSON plan for it to be valid.
        def required_plan_keys
          raise NotImplementedError, "#{self.class.name} must implement #required_plan_keys"
        end

        # Read-only tool names this wizard is allowed to call.
        def allowed_tool_names
          []
        end

        # Build filtered tool definitions from the function registry.
        def tool_definitions
          Functions::Registry.tool_definitions_for(allowed_tool_names)
        end

        # Parse a JSON plan from the LLM response text.
        # Returns { function_call: { name:, arguments: } } or nil.
        def extract_function_call(text)
          return nil if text.blank?

          stripped = text.strip

          begin
            data = JSON.parse(stripped)
          rescue JSON::ParserError
            Rails.logger.debug "[AssistantChatbot] #{self.class.name} response not valid JSON plan"
            return nil
          end

          unless data.is_a?(Hash)
            Rails.logger.debug "[AssistantChatbot] JSON plan is not an object"
            return nil
          end

          unless required_plan_keys.all? { |key| data.key?(key) }
            Rails.logger.debug "[AssistantChatbot] JSON plan missing required keys: #{required_plan_keys.inspect}"
            return nil
          end

          args = data.deep_symbolize_keys.with_indifferent_access

          Rails.logger.info "[AssistantChatbot] Parsed #{function_name} JSON plan: #{args.inspect}"

          {
            function_call: {
              name: function_name,
              arguments: args
            }
          }
        end

        protected

        attr_reader :context
      end
    end
  end
end
