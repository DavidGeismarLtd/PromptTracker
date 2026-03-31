# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Assistants::PromptCreationWizardAssistant do
  describe "#system_prompt" do
    it "reflects prompts list context when present" do
      assistant = described_class.new(context: { page_type: :prompts_list })

      prompt = assistant.system_prompt

      expect(prompt).to include("Browsing prompts list")
      expect(prompt).to include("Prompt Creation Wizard Assistant")
    end

    it "mentions missing prompt context when not provided" do
      assistant = described_class.new(context: {})

      prompt = assistant.system_prompt

      expect(prompt).to include("Prompt is not explicitly specified")
    end

    it "describes the JSON plan format for create_prompt" do
      assistant = described_class.new(context: { page_type: :prompts_list })

      prompt = assistant.system_prompt

      expect(prompt).to include("The JSON object MUST have this shape")
      expect(prompt).to include("\"name\"")
      expect(prompt).to include("\"system_prompt_concept\"")
      expect(prompt).to include("create_prompt")
    end
  end
end
