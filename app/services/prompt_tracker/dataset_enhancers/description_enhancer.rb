# frozen_string_literal: true

require "ruby_llm/schema"

module PromptTracker
  module DatasetEnhancers
    # AI-powered enhancer for dataset descriptions.
    #
    # Turns a short purpose statement into a clear explanation of what the
    # dataset contains and how it is used.
    class DescriptionEnhancer
      FALLBACK_MODEL = "gpt-4o"
      FALLBACK_TEMPERATURE = 0.5

      def self.enhance(name:, raw_description: nil, dataset_type:, testable_name: nil)
        new(name:, raw_description:, dataset_type:, testable_name:).enhance
      end

      attr_reader :name, :raw_description, :dataset_type, :testable_name

      def initialize(name:, raw_description:, dataset_type:, testable_name:)
        @name = name.to_s.strip
        @raw_description = raw_description.to_s.strip
        @dataset_type = dataset_type.to_s.strip
        @testable_name = testable_name.to_s.strip
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
        PromptTracker.configuration.default_provider_for(:dataset_generation) || :openai
      end

      def api
        PromptTracker.configuration.default_api_for(:dataset_generation)
      end

      def model
        PromptTracker.configuration.default_model_for(:dataset_generation) || FALLBACK_MODEL
      end

      def temperature
        PromptTracker.configuration.default_temperature_for(:dataset_generation) || FALLBACK_TEMPERATURE
      end

      def schema
        @schema ||= Class.new(RubyLLM::Schema) do
          string :description, description: "Clear explanation of what the dataset contains and how it is used"
        end
      end

      def build_prompt
        lines = []
        lines << "You are documenting datasets for an LLM prompt testing tool."
        lines << "Write a clear description (1-3 sentences) for this dataset."
        lines << ""
        lines << "Dataset name: #{name.present? ? name : '(unnamed dataset)'}"
        lines << "Dataset type: #{dataset_type}"
        lines << ""
        if testable_name.present?
          lines << "Associated prompt/assistant: #{testable_name}"
          lines << ""
        end
        if raw_description.present?
          lines << "Existing short description:"
          lines << raw_description
          lines << ""
        end
        lines << "Return a JSON object with:"
        lines << "- description: the improved description"

        lines.join("\n")
      end

      def fallback_description
        return raw_description if raw_description.present?

        "Dataset for testing #{testable_name.presence || 'an LLM prompt'}."
      end
    end
  end
end
