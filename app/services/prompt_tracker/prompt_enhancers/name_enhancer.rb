# frozen_string_literal: true

require "ruby_llm/schema"

module PromptTracker
  module PromptEnhancers
    # AI-powered enhancer for prompt names.
    #
    # Takes a rough or user-provided name plus optional context and returns
    # a concise, professional name suitable for listing in the UI.
    class NameEnhancer
      FALLBACK_MODEL = "gpt-4o-mini"
      FALLBACK_TEMPERATURE = 0.4

      def self.enhance(raw_name:, description: nil, system_prompt_concept: nil)
        new(raw_name:, description:, system_prompt_concept:).enhance
      end

      attr_reader :raw_name, :description, :system_prompt_concept

      def initialize(raw_name:, description:, system_prompt_concept:)
        @raw_name = raw_name.to_s.strip
        @description = description.to_s.strip
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
          name: parsed["name"] || fallback_name,
          reasoning: parsed["reasoning"]
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
          string :name, description: "A short, professional name for the prompt"
          string :reasoning, description: "One-sentence explanation of why this name fits"
        end
      end

      def build_prompt
        lines = []
        lines << "You are an expert at naming LLM prompts for a developer-facing UI."
        lines << ""
        lines << "Propose a concise, professional name (2-6 words) for this prompt."
        lines << ""
        if raw_name.present?
          lines << "Current rough name:"
          lines << raw_name
          lines << ""
        end
        if description.present?
          lines << "Short description:"
          lines << description
          lines << ""
        end
        if system_prompt_concept.present?
          lines << "System prompt concept:"
          lines << system_prompt_concept
          lines << ""
        end
        lines << "Return a JSON object with:"
        lines << "- name: the improved name"
        lines << "- reasoning: a brief explanation for the choice"

        lines.join("\n")
      end

      def fallback_name
        return system_prompt_concept.truncate(60) if raw_name.blank? && system_prompt_concept.present?

        raw_name.presence || "New prompt"
      end
    end
  end
end
