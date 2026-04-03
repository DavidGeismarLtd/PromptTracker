# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_ab_tests
#
#  cancelled_at              :datetime
#  completed_at              :datetime
#  confidence_level          :float            default(0.95)
#  created_at                :datetime         not null
#  created_by                :string
#  description               :text
#  hypothesis                :string
#  id                        :bigint           not null, primary key
#  metadata                  :jsonb
#  metric_to_optimize        :string           not null
#  minimum_detectable_effect :float            default(0.05)
#  minimum_sample_size       :integer          default(100)
#  name                      :string           not null
#  optimization_direction    :string           default("minimize"), not null
#  agent_id                 :bigint           not null
#  results                   :jsonb
#  started_at                :datetime
#  status                    :string           default("draft"), not null
#  traffic_split             :jsonb            not null
#  updated_at                :datetime         not null
#  variants                  :jsonb            not null
#
FactoryBot.define do
  factory :ab_test, class: "PromptTracker::AbTest" do
    association :agent, factory: :agent
    sequence(:name) { |n| "A/B Test #{n}" }
    description { "Testing different prompt versions" }
    hypothesis { "Version B will perform better than Version A" }
    metric_to_optimize { "response_time" }
    optimization_direction { "minimize" }
    status { "draft" }
    traffic_split { { "A" => 50, "B" => 50 } }
    confidence_level { 0.95 }
    minimum_sample_size { 100 }
    results { {} }

    # Create variants after the test is created
    transient do
      version_a { nil }
      version_b { nil }
    end

    after(:build) do |ab_test, evaluator|
      # Create versions if not provided
      v_a = evaluator.version_a || create(:agent_version, agent: ab_test.agent, version_number: 1)
      v_b = evaluator.version_b || create(:agent_version, agent: ab_test.agent, version_number: 2)

      ab_test.variants = [
        { "name" => "A", "version_id" => v_a.id, "description" => "Control version" },
        { "name" => "B", "version_id" => v_b.id, "description" => "Test version" }
      ]
    end

    trait :draft do
      status { "draft" }
    end

    trait :running do
      status { "running" }
      started_at { 1.day.ago }
    end

    trait :paused do
      status { "paused" }
      started_at { 2.days.ago }
    end

    trait :completed do
      status { "completed" }
      started_at { 7.days.ago }
      completed_at { 1.day.ago }
      results { { "winner" => "B", "confidence" => 0.98 } }
    end

    trait :cancelled do
      status { "cancelled" }
      started_at { 3.days.ago }
      cancelled_at { 1.day.ago }
    end

    trait :optimizing_cost do
      metric_to_optimize { "cost" }
      optimization_direction { "minimize" }
    end

    trait :optimizing_quality do
      metric_to_optimize { "quality_score" }
      optimization_direction { "maximize" }
    end

    trait :with_responses do
      after(:create) do |ab_test|
        # Create responses for variant A
        create_list(:llm_response, 10,
          agent_version: ab_test.agent.agent_versions.first,
          ab_test: ab_test,
          ab_test_variant: "A"
        )
        # Create responses for variant B
        create_list(:llm_response, 10,
          agent_version: ab_test.agent.agent_versions.second,
          ab_test: ab_test,
          ab_test_variant: "B"
        )
      end
    end
  end
end
