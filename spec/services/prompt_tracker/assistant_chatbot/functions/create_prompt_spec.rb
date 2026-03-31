# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Functions::CreatePrompt do
  let(:context) { {} }

  let(:arguments) do
    {
      name: "Raw Prompt Name",
      description: "short description",
      system_prompt_concept: "short concept",
      model: "gpt-4o-mini",
      provider: "openai",
      temperature: 0.9
    }
  end

  subject(:function) { described_class.new(arguments, context) }

  before do
    allow(PromptTracker::PromptEnhancers::NameEnhancer).to receive(:enhance).and_return(
      name: "Enhanced Name"
    )

    allow(PromptTracker::PromptEnhancers::DescriptionEnhancer).to receive(:enhance).and_return(
      description: "Enhanced Description"
    )

      allow(PromptTracker::PromptEnhancers::SystemPromptEnhancer).to receive(:enhance).and_return(
        system_prompt: "Final system prompt",
        variables: [ "customer_name", "question" ],
        explanation: "LLM reasoning"
      )
  end

  describe "#call" do
    it "creates a prompt and version using enhanced attributes" do
      result = function.call

      expect(result.success?).to be true

      prompt = PromptTracker::Prompt.last
      expect(prompt).to be_present
      expect(prompt.name).to eq("Enhanced Name")
      expect(prompt.description).to eq("Enhanced Description")

      version = prompt.prompt_versions.last
      expect(version.system_prompt).to eq("Final system prompt")
        expect(version.user_prompt).to be_nil
      expect(version.status).to eq("draft")
      expect(version.model_config["model"]).to eq("gpt-4o-mini")
      expect(version.model_config["provider"]).to eq("openai")
      expect(version.model_config["temperature"]).to eq(0.9)
      expect(version.variables_schema.map { |v| v["name"] }).to match_array(%w[customer_name question])

      expect(PromptTracker::PromptEnhancers::NameEnhancer).to have_received(:enhance).with(
        raw_name: "Raw Prompt Name",
        description: "short description",
        system_prompt_concept: "short concept"
      )
      expect(PromptTracker::PromptEnhancers::DescriptionEnhancer).to have_received(:enhance).with(
        name: "Enhanced Name",
        raw_description: "short description",
        system_prompt_concept: "short concept"
      )
      expect(PromptTracker::PromptEnhancers::SystemPromptEnhancer).to have_received(:enhance).with(
        system_prompt_concept: "short concept",
        description: "Enhanced Description"
      )
    end

    it "prefers explicit user_prompt over generated one" do
      arguments[:user_prompt] = "Explicit template"

      result = function.call
      expect(result.success?).to be true

      version = PromptTracker::Prompt.last.prompt_versions.last
      expect(version.user_prompt).to eq("Explicit template")
    end

    it "returns a failure result when required arguments are missing" do
      arguments.delete(:name)

      result = function.call

      expect(result.success?).to be false
      expect(result.error).to include("name is required")
    end
  end
end
