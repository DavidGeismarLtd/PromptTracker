# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Assistants::AgentCreationWizardAssistant do
  describe "#system_prompt" do
    before do
      allow(PromptTracker.configuration)
        .to receive(:assistant_chatbot)
        .and_return({ model: { provider: :openai, model: "gpt-4o-mini" } })

      allow(PromptTracker::RubyLlmModelAdapter)
        .to receive(:models_for)
        .with(:openai)
        .and_return([
          { id: "gpt-4o", name: "GPT-4o" },
          { id: "gpt-4o-mini", name: "GPT-4o mini" },
          { id: "gpt-5", name: "GPT-5" }
        ])
    end

    it "reflects prompts list context when present" do
      assistant = described_class.new(context: { page_type: :prompts_list })

      prompt = assistant.system_prompt

      expect(prompt).to include("Browsing prompts list")
      expect(prompt).to include("Agent Creation Wizard Assistant")
    end

    it "mentions missing agent context when not provided" do
      assistant = described_class.new(context: {})

      prompt = assistant.system_prompt

      expect(prompt).to include("Agent is not explicitly specified")
    end

    it "requires asking for name, description, and model in order" do
      assistant = described_class.new(context: { page_type: :prompts_list })

      prompt = assistant.system_prompt

      expect(prompt).to include("How should we name the agent?")
      expect(prompt).to include("ask for a brief description of the agent")
      expect(prompt).to include("ask which model to use")
    end

    it "includes model suggestions from RubyLlmModelAdapter" do
      assistant = described_class.new(context: { page_type: :prompts_list })

      prompt = assistant.system_prompt

      expect(prompt).to include("- gpt-4o-mini (workspace default)")
      expect(prompt).to include("- gpt-4o")
      expect(prompt).to include("- gpt-5")
    end

    it "describes the JSON plan format for create_prompt" do
      assistant = described_class.new(context: { page_type: :prompts_list })

      prompt = assistant.system_prompt

      expect(prompt).to include("The JSON object MUST have this shape")
      expect(prompt).to include("\"name\"")
      expect(prompt).to include("\"model\"")
      expect(prompt).to include("create_prompt")
    end
  end
end
