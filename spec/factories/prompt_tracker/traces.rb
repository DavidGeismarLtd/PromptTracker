# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_tracker_trace, class: "PromptTracker::Trace" do
    sequence(:name) { |n| "trace_#{n}" }
    status { "running" }
    started_at { Time.current }
    session_id { "session_#{SecureRandom.hex(4)}" }
    user_id { "user_#{SecureRandom.hex(4)}" }
    input { "Test input" }
    metadata { {} }

    trait :completed do
      status { "completed" }
      ended_at { started_at + 2.seconds }
      output { "Test output" }
    end

    trait :with_error do
      status { "error" }
      ended_at { started_at + 1.second }
      metadata { { error: "Something went wrong" } }
    end

    trait :with_spans do
      after(:create) do |trace|
        create_list(:prompt_tracker_span, 2, trace: trace)
      end
    end
  end
end
