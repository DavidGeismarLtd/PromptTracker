# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_tracker_span, class: "PromptTracker::Span" do
    association :trace, factory: :prompt_tracker_trace
    sequence(:name) { |n| "span_#{n}" }
    span_type { "function" }
    status { "running" }
    started_at { Time.current }
    input { "Test input" }
    metadata { {} }

    trait :completed do
      status { "completed" }
      ended_at { started_at + 1.second }
      output { "Test output" }
    end

    trait :with_error do
      status { "error" }
      ended_at { started_at + 500.milliseconds }
      metadata { { error: "Span failed" } }
    end

    trait :retrieval do
      span_type { "retrieval" }
    end

    trait :tool do
      span_type { "tool" }
    end

    trait :with_child_spans do
      after(:create) do |span|
        create_list(:prompt_tracker_span, 2, trace: span.trace, parent_span: span)
      end
    end
  end
end
