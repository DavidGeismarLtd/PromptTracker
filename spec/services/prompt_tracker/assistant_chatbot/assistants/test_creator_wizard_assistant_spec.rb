# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Assistants::TestCreatorWizardAssistant do
  describe "#system_prompt" do
    it "includes the prompt version id when present in context" do
      assistant = described_class.new(context: { prompt_version_id: 42 })

      prompt = assistant.system_prompt

      expect(prompt).to include("PromptVersion #42")
      expect(prompt).to include("Test Creator Wizard Assistant")
    end

    it "mentions missing prompt version when not provided" do
      assistant = described_class.new(context: {})

      prompt = assistant.system_prompt

      expect(prompt).to include("PromptVersion is not explicitly specified")
    end

    it "describes the JSON plan format for generate_tests" do
      assistant = described_class.new(context: { prompt_version_id: 1 })

      prompt = assistant.system_prompt

      expect(prompt).to include("The JSON object MUST have this shape")
      expect(prompt).to include("\"prompt_version_id\"")
      expect(prompt).to include("\"count\"")
      expect(prompt).to include("\"instructions\"")
    end

    it "does not mention run_tests or running tests" do
      assistant = described_class.new(context: { prompt_version_id: 1 })

      prompt = assistant.system_prompt

      expect(prompt).not_to include("run_tests")
      expect(prompt).not_to include("run tests")
    end
  end
end
