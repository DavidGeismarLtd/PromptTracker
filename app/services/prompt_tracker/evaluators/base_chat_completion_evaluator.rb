# frozen_string_literal: true

module PromptTracker
  module Evaluators
    # Base class for evaluators that work with Chat Completions API responses.
    #
    # These evaluators receive response_text (String) and evaluate single-turn responses.
    # Used for: single_turn test mode on any testable.
    #
    # Subclasses should implement:
    # - #evaluate_score: Calculate the numeric score (0-100)
    # - .metadata: Class method providing evaluator metadata
    #
    # @example Creating a text-based evaluator
    #   class MyTextEvaluator < BaseChatCompletionEvaluator
    #     def evaluate_score
    #       response_text.length > 100 ? 100 : 50
    #     end
    #   end
    #
    class BaseChatCompletionEvaluator < BaseEvaluator
      attr_reader :response_text

      # Returns the API type this evaluator works with
      #
      # @return [Symbol] :chat_completion
      def self.api_type
        :chat_completion
      end

      # Initialize the evaluator with response text
      #
      # @param response_text [String] the response text to evaluate
      # @param config [Hash] configuration for the evaluator
      def initialize(response_text, config = {})
        @response_text = response_text
        super(config)
      end

      # Evaluate and create an Evaluation record
      # All scores are 0-100
      #
      # @return [Evaluation] the created evaluation
      def evaluate
        score = evaluate_score
        feedback_text = generate_feedback

        Evaluation.create!(
          llm_response: config[:llm_response],
          test_run: config[:test_run],
          evaluator_type: self.class.name,
          evaluator_config_id: config[:evaluator_config_id],
          score: score,
          score_min: 0,
          score_max: 100,
          passed: passed?,
          feedback: feedback_text,
          metadata: metadata,
          evaluation_context: config[:evaluation_context] || "tracked_call"
        )
      end
    end
  end
end
