# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_prompt_versions
#
#  created_at       :datetime         not null
#  created_by       :string
#  id               :bigint           not null, primary key
#  model_config     :jsonb
#  notes            :text
#  prompt_id        :bigint           not null
#  status           :string           default("draft"), not null
#  template         :text             not null
#  updated_at       :datetime         not null
#  variables_schema :jsonb
#  version_number   :integer          not null
#
FactoryBot.define do
  factory :prompt_version, class: "PromptTracker::PromptVersion" do
    association :prompt, factory: :prompt
    template { "Hello {{name}}, how can I help you today?" }
    sequence(:version_number) { |n| n }
    status { "draft" }
    variables_schema do
      [
        { "name" => "name", "type" => "string", "required" => true }
      ]
    end
    model_config { {} }
    notes { "Test version" }

    trait :active do
      status { "active" }
    end

    trait :deprecated do
      status { "deprecated" }
    end

    trait :with_model_config do
      model_config do
        {
          "model" => "gpt-4",
          "temperature" => 0.7,
          "max_tokens" => 150
        }
      end
    end

    trait :with_responses do
      after(:create) do |version|
        create_list(:llm_response, 5, prompt_version: version)
      end
    end
  end
end
