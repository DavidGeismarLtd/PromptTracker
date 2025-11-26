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
    # - #evaluator_id: Unique identifier for this evaluator
    #
    # @example Creating a custom evaluator
    #   class MyEvaluator < BaseEvaluator
    #     def evaluate_score
    #       response_text.length > 100 ? 100 : 50
    #     end
    #
    #     def evaluator_id
    #       "my_evaluator_v1"
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
      #
      # @return [Evaluation] the created evaluation
      def evaluate
        score = evaluate_score
        feedback_text = generate_feedback

        EvaluationService.create_automated(
          llm_response: llm_response,
          evaluator_id: evaluator_id,
          score: score,
          score_min: score_min,
          score_max: score_max,
          criteria_scores: {},
          feedback: feedback_text,
          metadata: metadata
        )
      end

      # Calculate the overall score
      # Subclasses should override this method
      #
      # @return [Numeric] the calculated score
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

      # Get the evaluator identifier
      # Subclasses should override this method
      #
      # @return [String] unique identifier for this evaluator
      def evaluator_id
        raise NotImplementedError, "Subclasses must implement #evaluator_id"
      end

      # Get the minimum possible score
      # Subclasses can override this method
      #
      # @return [Numeric] minimum score (default: 0)
      def score_min
        0
      end

      # Get the maximum possible score
      # Subclasses can override this method
      #
      # @return [Numeric] maximum score (default: 100)
      def score_max
        100
      end

      # Get additional metadata for the evaluation
      # Subclasses can override this method
      #
      # @return [Hash] metadata hash
      def metadata
        { config: config }
      end

      protected

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
