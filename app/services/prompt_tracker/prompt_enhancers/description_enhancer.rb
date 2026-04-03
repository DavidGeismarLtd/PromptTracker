# frozen_string_literal: true

require "ruby_llm/schema"

module PromptTracker
  module PromptEnhancers
    # AI-powered enhancer for prompt descriptions.
    #
    # Expands a short, user-provided description into a clear summary that can
    # be shown in the UI alongside the prompt.
    class DescriptionEnhancer
      FALLBACK_MODEL = "gpt-4o-mini"
      FALLBACK_TEMPERATURE = 0.4

      def self.enhance(name:, raw_description: nil, system_prompt_concept: nil)
        new(name:, raw_description:, system_prompt_concept:).enhance
      end

      attr_reader :name, :raw_description, :system_prompt_concept

      def initialize(name:, raw_description:, system_prompt_concept:)
        @name = name.to_s.strip
        @raw_description = raw_description.to_s.strip
        @system_prompt_concept = system_prompt_concept.to_s.strip
      end

      def enhance
        response = LlmClientService.call_with_schema(
          provider: provider,
          api: api,
          model: model,
          prompt: build_prompt,
          schema: schema,
          temperature: temperature
        )

        parsed = JSON.parse(response[:text])

        {
          description: parsed["description"] || fallback_description
        }
      end

      private

      def provider
        PromptTracker.configuration.default_provider_for(:prompt_generation) || :openai
      end

      def api
        PromptTracker.configuration.default_api_for(:prompt_generation)
      end

      def model
        PromptTracker.configuration.default_model_for(:prompt_generation) || FALLBACK_MODEL
      end

      def temperature
        PromptTracker.configuration.default_temperature_for(:prompt_generation) || FALLBACK_TEMPERATURE
      end

      def schema
        @schema ||= Class.new(RubyLLM::Schema) do
          string :description, description: "A clear, concise description of what the prompt does"
        end
      end

      def build_prompt
        lines = []
        lines << "You are an expert technical writer for an LLM prompt catalog."
        lines << "Write a short description (1-3 sentences) suitable for a UI tooltip or list."
        lines << ""
        lines << "Prompt name: #{name.present? ? name : '(unnamed prompt)'}"
        lines << ""
        if raw_description.present?
          lines << "Existing short description:"
          lines << raw_description
          lines << ""
        end
        if system_prompt_concept.present?
          lines << "System prompt concept:"
          lines << system_prompt_concept
          lines << ""
        end
        lines << "Return a JSON object with:"
        lines << "- description: the improved description"

        lines.join("\n")
      end

      def fallback_description
        return raw_description if raw_description.present?
        return system_prompt_concept if system_prompt_concept.present?

        "AI-powered prompt."
      end
    end
  end
end
