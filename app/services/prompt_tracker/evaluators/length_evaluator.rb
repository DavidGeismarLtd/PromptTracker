# frozen_string_literal: true

module PromptTracker
  module Evaluators
    # Evaluates response based on length criteria.
    #
    # Scores responses based on whether they fall within expected length ranges.
    # Useful for ensuring responses are not too short or too long.
    #
    # @example Evaluate with default config
    #   evaluator = LengthEvaluator.new(llm_response)
    #   evaluation = evaluator.evaluate
    #
    # @example Evaluate with custom length ranges
    #   evaluator = LengthEvaluator.new(llm_response, {
    #     min_length: 50,
    #     max_length: 500,
    #     ideal_min: 100,
    #     ideal_max: 300
    #   })
    #   evaluation = evaluator.evaluate
    #
    class LengthEvaluator < BaseEvaluator
      # Default configuration
      DEFAULT_CONFIG = {
        min_length: 10,      # Minimum acceptable length
        max_length: 2000,    # Maximum acceptable length
        ideal_min: 50,       # Ideal minimum length
        ideal_max: 500       # Ideal maximum length
      }.freeze

      def initialize(llm_response, config = {})
        super(llm_response, DEFAULT_CONFIG.merge(config))
      end

      def evaluate_score
        length = response_text.length

        # Too short or too long: low score
        if length < config[:min_length]
          return 20 # Very short
        elsif length > config[:max_length]
          return 30 # Too long
        end

        # Within ideal range: high score
        if length >= config[:ideal_min] && length <= config[:ideal_max]
          return 100 # Perfect length
        end

        # Between min and ideal_min, or between ideal_max and max: medium score
        if length < config[:ideal_min]
          # Scale from min_length (50) to ideal_min (100)
          range = config[:ideal_min] - config[:min_length]
          position = length - config[:min_length]
          50 + ((position.to_f / range) * 50).round
        else
          # Scale from ideal_max (100) to max_length (50)
          range = config[:max_length] - config[:ideal_max]
          position = length - config[:ideal_max]
          100 - ((position.to_f / range) * 50).round
        end
      end

      def generate_feedback
        length = response_text.length

        if length < config[:min_length]
          "Response is too short (#{length} chars). Minimum: #{config[:min_length]} chars."
        elsif length > config[:max_length]
          "Response is too long (#{length} chars). Maximum: #{config[:max_length]} chars."
        elsif length >= config[:ideal_min] && length <= config[:ideal_max]
          "Response length is ideal (#{length} chars)."
        elsif length < config[:ideal_min]
          "Response is acceptable but shorter than ideal (#{length} chars). Ideal: #{config[:ideal_min]}-#{config[:ideal_max]} chars."
        else
          "Response is acceptable but longer than ideal (#{length} chars). Ideal: #{config[:ideal_min]}-#{config[:ideal_max]} chars."
        end
      end

      def evaluator_id
        "length_evaluator_v1"
      end

      def metadata
        super.merge(
          response_length: response_text.length,
          min_length: config[:min_length],
          max_length: config[:max_length],
          ideal_min: config[:ideal_min],
          ideal_max: config[:ideal_max]
        )
      end
    end
  end
end
