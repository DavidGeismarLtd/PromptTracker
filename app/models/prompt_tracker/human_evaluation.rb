# frozen_string_literal: true

module PromptTracker
  # Represents a human evaluation/review of an automated evaluation.
  #
  # HumanEvaluations allow humans to provide feedback and scores on
  # automated evaluations, creating a feedback loop for improving
  # evaluation quality.
  #
  # @example Creating a human evaluation
  #   human_eval = HumanEvaluation.create!(
  #     evaluation: evaluation,
  #     score: 85,
  #     feedback: "The automated evaluation was mostly correct, but missed some nuance in tone."
  #   )
  #
  class HumanEvaluation < ApplicationRecord
    # Associations
    belongs_to :evaluation

    # Validations
    validates :score, presence: true, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    }
    validates :feedback, presence: true

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :high_scores, -> { where("score >= ?", 70) }
    scope :low_scores, -> { where("score < ?", 70) }

    # Instance Methods

    # Check if the human evaluation score is passing (>= 70)
    #
    # @param threshold [Float] passing threshold (default: 70)
    # @return [Boolean] true if score is passing
    def passing?(threshold = 70)
      score >= threshold
    end

    # Get the difference between human score and automated evaluation score
    #
    # @return [Float] difference (positive means human scored higher)
    def score_difference
      score - evaluation.score
    end

    # Check if human agrees with automated evaluation
    # (within 10 points tolerance by default)
    #
    # @param tolerance [Float] acceptable difference (default: 10)
    # @return [Boolean] true if scores are within tolerance
    def agrees_with_evaluation?(tolerance = 10)
      score_difference.abs <= tolerance
    end
  end
end

