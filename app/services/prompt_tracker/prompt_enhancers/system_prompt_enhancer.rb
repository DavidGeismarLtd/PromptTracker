# frozen_string_literal: true

module PromptTracker
  module PromptEnhancers
    # Wrapper around PromptGeneratorService for enhancing a system prompt from
    # a short concept plus optional extra description.
    #
    # This keeps PromptGeneratorService as the single place that knows how to
    # produce high-quality system prompts and variables, while giving the
    # Assistant chatbot a small, focused API.
    class SystemPromptEnhancer
      def self.enhance(system_prompt_concept:, description: nil)
        new(system_prompt_concept:, description:).enhance
      end

      attr_reader :system_prompt_concept, :description

      def initialize(system_prompt_concept:, description:)
        @system_prompt_concept = system_prompt_concept.to_s.strip
        @description = description.to_s.strip
      end

      def enhance
        result = PromptGeneratorService.generate(description: generator_description)

        {
          system_prompt: result[:system_prompt],
          variables: result[:variables] || [],
          explanation: result[:explanation]
        }
      end

      private

      def generator_description
        parts = []
        parts << "Prompt concept:\n#{system_prompt_concept}" if system_prompt_concept.present?
        parts << "Additional context:\n#{description}" if description.present?

        combined = parts.join("\n\n").strip
        return system_prompt_concept if combined.blank? && system_prompt_concept.present?

        combined.presence || "Generic AI assistant prompt."
      end
    end
  end
end
