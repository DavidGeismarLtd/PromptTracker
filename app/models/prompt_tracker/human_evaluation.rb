# frozen_string_literal: true

module PromptTracker
  # Represents a human evaluation/review.
  #
  # HumanEvaluations can be used in three ways:
  # 1. Review of automated evaluations (evaluation_id set)
  # 2. Direct evaluation of LLM responses (llm_response_id set)
  # 3. Direct evaluation of test runs (prompt_test_run_id set)
  #
  # @example Creating a review of an automated evaluation
  #   human_eval = HumanEvaluation.create!(
  #     evaluation: evaluation,
  #     score: 85,
  #     feedback: "The automated evaluation was mostly correct, but missed some nuance in tone."
  #   )
  #
  # @example Creating a direct human evaluation of a response
  #   human_eval = HumanEvaluation.create!(
  #     llm_response: response,
  #     score: 90,
  #     feedback: "Excellent response, very helpful and professional."
  #   )
  #
  # @example Creating a direct human evaluation of a test run
  #   human_eval = HumanEvaluation.create!(
  #     prompt_test_run: test_run,
  #     score: 95,
  #     feedback: "Test passed with excellent results."
  #   )
  #
  class HumanEvaluation < ApplicationRecord
    # Associations
    belongs_to :evaluation, optional: true
    belongs_to :llm_response,
               class_name: "PromptTracker::LlmResponse",
               optional: true
    belongs_to :prompt_test_run,
               class_name: "PromptTracker::PromptTestRun",
               optional: true

    # Validations
    validates :score, presence: true, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    }
    validates :feedback, presence: true
    validate :must_belong_to_evaluation_or_llm_response

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

    private

    # Validate that exactly one association is set
    def must_belong_to_evaluation_or_llm_response
      associations = [evaluation_id, llm_response_id, prompt_test_run_id].compact

      if associations.empty?
        errors.add(:base, "Must belong to either an evaluation, llm_response, or prompt_test_run")
      elsif associations.size > 1
        errors.add(:base, "Cannot belong to multiple associations")
      end
    end
  end
end
