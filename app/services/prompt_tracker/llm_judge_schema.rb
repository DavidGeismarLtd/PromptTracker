# frozen_string_literal: true

require "ruby_llm/schema"

module PromptTracker
  # Factory for creating RubyLLM::Schema classes for LLM judge evaluations.
  #
  # This replaces the manual JSON Schema building with RubyLLM's elegant DSL.
  # All scores are always 0-100.
  #
  # @example Create a schema for evaluation
  #   schema = LlmJudgeSchema.for_criteria(
  #     criteria: ["clarity", "accuracy", "completeness"]
  #   )
  #
  #   chat = RubyLLM.chat(model: "gpt-4o").with_schema(schema)
  #   response = chat.ask("Evaluate this response...")
  #   response.content[:overall_score]  # => 85.0
  #   response.content[:criteria_scores][:clarity]  # => 90.0
  #
  class LlmJudgeSchema
    # Create a RubyLLM::Schema class for LLM judge evaluation
    # All scores are 0-100
    #
    # @param criteria [Array<String>] list of evaluation criteria
    # @return [Class] a RubyLLM::Schema subclass
    def self.for_criteria(criteria:)
      # Capture variables for use in the class definition
      criteria_list = criteria

      Class.new(RubyLLM::Schema) do
        # Overall score (0-100)
        number :overall_score,
               description: "Overall score from 0 to 100"

        # Criteria scores as a nested object
        object :criteria_scores do
          criteria_list.each do |criterion|
            number criterion.to_sym,
                   description: "Score for #{criterion} (0-100)"
          end
        end

        # Feedback text
        string :feedback,
               description: "Detailed feedback explaining the scores and evaluation"
      end
    end
  end
end
