# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_agents
#
#  archived_at :datetime
#  category    :string
#  created_at  :datetime         not null
#  created_by  :string
#  description :text
#  id          :bigint           not null, primary key
#  name        :string           not null
#  slug        :string           not null
#  tags        :jsonb
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :agent, class: "PromptTracker::Agent" do
    sequence(:name) { |n| "Test Prompt #{n}" }
    sequence(:slug) { |n| "test_prompt_#{n}" }
    description { "A test prompt for #{name}" }
    created_by { "test@example.com" }
    archived_at { nil }

    trait :archived do
      archived_at { 1.day.ago }
    end

    trait :with_versions do
      after(:create) do |prompt|
        create_list(:agent_version, 3, agent: prompt)
      end
    end

    trait :with_active_version do
      after(:create) do |prompt|
        create(:agent_version, :active, agent: prompt)
      end
    end
  end
end
