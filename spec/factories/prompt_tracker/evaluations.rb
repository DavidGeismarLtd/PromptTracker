# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_evaluations
#
#  created_at         :datetime         not null
#  evaluation_context :string           default("tracked_call")
#  evaluator_id       :string
#  evaluator_type     :string           not null
#  feedback           :text
#  id                 :bigint           not null, primary key
#  llm_response_id    :bigint           not null
#  metadata           :jsonb
#  passed             :boolean
#  score              :decimal(10, 2)   not null
#  score_max          :decimal(10, 2)   default(5.0)
#  score_min          :decimal(10, 2)   default(0.0)
#  updated_at         :datetime         not null
#
FactoryBot.define do
  factory :evaluation, class: "PromptTracker::Evaluation" do
    association :llm_response, factory: :llm_response
    prompt_test_run { nil }  # Optional association
    score { 4.5 }
    score_min { 0 }
    score_max { 5 }
    passed { true }
    evaluator_type { "PromptTracker::Evaluators::LengthEvaluator" }
    evaluator_id { "length_evaluator" }
    feedback { nil }
    metadata do
      {
        "min_length" => 10,
        "max_length" => 100,
        "ideal_min" => 20,
        "ideal_max" => 80,
        "response_length" => 45
      }
    end

    trait :keyword do
      evaluator_type { "PromptTracker::Evaluators::KeywordEvaluator" }
      evaluator_id { "keyword_evaluator" }
      score { 85 }
      score_min { 0 }
      score_max { 100 }
      passed { true }
    end

    trait :llm_judge do
      evaluator_type { "PromptTracker::Evaluators::LlmJudgeEvaluator" }
      evaluator_id { "gpt-4" }
      feedback { "The response is accurate and well-structured." }
      passed { true }
      metadata do
        {
          "model" => "gpt-4",
          "prompt_used" => "Evaluate this response...",
          "criteria_scores" => {
            "helpfulness" => 5,
            "tone" => 4,
            "accuracy" => 4.5
          }
        }
      end
    end

    trait :passing do
      score { 4.5 }
      score_min { 0 }
      score_max { 5 }
      passed { true }
    end

    trait :failing do
      score { 2.0 }
      score_min { 0 }
      score_max { 5 }
      passed { false }
    end
  end
end
