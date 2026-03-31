# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Assistants::DatasetWizardAssistant do
  describe "#system_prompt" do
    it "includes the prompt version id when present in context" do
      assistant = described_class.new(context: { prompt_version_id: 27 })

      prompt = assistant.system_prompt

      expect(prompt).to include("PromptVersion #27")
      expect(prompt).to include("Dataset Wizard Assistant")
    end

    it "mentions missing prompt version when not provided" do
      assistant = described_class.new(context: {})

      prompt = assistant.system_prompt

      expect(prompt).to include("PromptVersion is not explicitly specified")
    end

    it "describes the JSON plan format for create_dataset" do
      assistant = described_class.new(context: { prompt_version_id: 1 })

      prompt = assistant.system_prompt

      expect(prompt).to include("The JSON object MUST have this shape")
      expect(prompt).to include("\"prompt_version_id\"")
      expect(prompt).to include("\"dataset_type\"")
    end
  end
end
