# frozen_string_literal: true

module PromptTracker
  module Evaluators
    # Base class for automated evaluators.
    #
    # Automated evaluators analyze LLM responses using rule-based logic
    # and assign scores based on specific criteria.
    #
    # Subclasses should implement:
    # - #evaluate_score: Calculate the numeric score
    # - .metadata: Class method providing evaluator metadata (optional)
    #
    # @example Creating a custom evaluator
    #   class MyEvaluator < BaseEvaluator
    #     def self.metadata
    #       {
    #         name: "My Evaluator",
    #         description: "Evaluates response length",
    #         category: :custom,
    #         icon: "gear"
    #       }
    #     end
    #
    #     def evaluate_score
    #       response_text.length > 100 ? 100 : 50
    #     end
    #   end
    #
    class BaseEvaluator
      attr_reader :llm_response, :config

      # Initialize the evaluator
      #
      # @param llm_response [LlmResponse] the response to evaluate
      # @param config [Hash] optional configuration for the evaluator
      def initialize(llm_response, config = {})
        @llm_response = llm_response
        @config = config
      end

      # Evaluate the response and create an Evaluation record
      # All scores are 0-100
      #
      # @return [Evaluation] the created evaluation
      def evaluate
        score = evaluate_score
        feedback_text = generate_feedback

        Evaluation.create!(
          llm_response: llm_response,
          evaluator_type: self.class.name,
          evaluator_config_id: config[:evaluator_config_id],
          score: score,
          passed: passed?,
          feedback: feedback_text,
          metadata: metadata,
          evaluation_context: config[:evaluation_context] || "tracked_call",
          prompt_test_run_id: config[:prompt_test_run_id]
        )
      end

      # Calculate the overall score (0-100)
      # Subclasses should override this method
      #
      # @return [Numeric] the calculated score (0-100)
      def evaluate_score
        raise NotImplementedError, "Subclasses must implement #evaluate_score"
      end

      # Generate feedback text explaining the score
      # Subclasses can override this method
      #
      # @return [String, nil] feedback text
      def generate_feedback
        nil
      end

      # Get additional metadata for the evaluation
      # Subclasses can override this method
      #
      # @return [Hash] metadata hash
      def metadata
        { config: config }
      end

      # Determine if the evaluation passed
      # Default implementation: normalized score >= 0.8 (80%)
      # Subclasses can override this method for custom pass/fail logic
      #
      # @return [Boolean] true if evaluation passed
      def passed?
        normalized_score >= 0.8
      end

      protected

      # Calculate normalized score (0.0 to 1.0)
      #
      # @return [Float] normalized score
      def normalized_score
        return 0.0 if score_max == score_min

        score = evaluate_score
        (score - score_min) / (score_max - score_min).to_f
      end

      # Helper to get the response text
      #
      # @return [String] the response text
      def response_text
        llm_response.response_text || ""
      end

      # Helper to get the rendered prompt
      #
      # @return [String] the rendered prompt
      def rendered_prompt
        llm_response.rendered_prompt || ""
      end
    end
  end
end
