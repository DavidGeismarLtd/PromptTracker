# frozen_string_literal: true

require "ruby_llm/schema"

module PromptTracker
  module DatasetEnhancers
    # AI-powered enhancer for dataset names.
    #
    # Produces a concise, slug-style name suitable for identifying datasets in
    # the testing UI (e.g. "customer_support_edge_cases").
    class NameEnhancer
      FALLBACK_MODEL = "gpt-4o"
      FALLBACK_TEMPERATURE = 0.5

      def self.enhance(raw_name:, testable_name:, dataset_type:, purpose: nil)
        new(raw_name:, testable_name:, dataset_type:, purpose:).enhance
      end

      attr_reader :raw_name, :testable_name, :dataset_type, :purpose

      def initialize(raw_name:, testable_name:, dataset_type:, purpose:)
        @raw_name = raw_name.to_s.strip
        @testable_name = testable_name.to_s.strip
        @dataset_type = dataset_type.to_s.strip
        @purpose = purpose.to_s.strip
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
          name: parsed["name"] || fallback_name
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
          string :name, description: "Short slug-style dataset name in snake_case"
        end
      end

      def build_prompt
        lines = []
        lines << "You are an expert at naming datasets for LLM prompt testing."
        lines << "Return a short snake_case name (no spaces) suitable for internal use."
        lines << ""
        if testable_name.present?
          lines << "Prompt or assistant name: #{testable_name}"
          lines << ""
        end
        if dataset_type.present?
          lines << "Dataset type: #{dataset_type} (e.g. single_turn or conversational)"
          lines << ""
        end
        if raw_name.present?
          lines << "Existing dataset name: #{raw_name}"
          lines << ""
        end
        if purpose.present?
          lines << "Dataset purpose: #{purpose}"
          lines << ""
        end
        lines << "Return a JSON object with:"
        lines << "- name: the improved snake_case dataset name"

        lines.join("\n")
      end

      def fallback_name
        base = if testable_name.present?
                 [testable_name, dataset_type.presence].compact.join(" ")
               else
                 raw_name.presence || "dataset"
               end

        base.parameterize(separator: "_")
      end
    end
  end
end

