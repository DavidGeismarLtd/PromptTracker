# frozen_string_literal: true

require "rails_helper"
require "ruby_llm/schema"

RSpec.describe PromptTracker::PromptEnhancers::NameEnhancer do
  describe ".enhance" do
    let(:mock_response) do
      {
        text: {
          name: "Customer Support Triage Assistant",
          reasoning: "Clear, concise name for support triage prompt."
        }.to_json
      }
    end

    before do
      PromptTracker.configuration.contexts = {
        prompt_generation: {
          default_provider: :openai,
          default_api: :chat_completions,
          default_model: "gpt-4o-mini",
          default_temperature: 0.4
        }
      }

      allow(PromptTracker::LlmClientService)
        .to receive(:call_with_schema)
        .and_return(mock_response)
    end

    it "returns enhanced name and reasoning from the LLM response" do
      result = described_class.enhance(
        raw_name: "Support bot",
        description: "Helps with customer issues",
        system_prompt_concept: "Customer support triage assistant"
      )

      expect(result[:name]).to eq("Customer Support Triage Assistant")
      expect(result[:reasoning]).to eq("Clear, concise name for support triage prompt.")
    end

    it "falls back to the raw name when LLM does not return a name" do
      allow(PromptTracker::LlmClientService)
        .to receive(:call_with_schema)
        .and_return({ text: {}.to_json })

      result = described_class.enhance(
        raw_name: "My Raw Prompt Name",
        description: "",
        system_prompt_concept: ""
      )

      expect(result[:name]).to eq("My Raw Prompt Name")
    end

    it "calls LlmClientService.call_with_schema with prompt_generation context defaults" do
      described_class.enhance(
        raw_name: "Support bot",
        description: "Helps with customer issues",
        system_prompt_concept: "Customer support triage assistant"
      )

      expect(PromptTracker::LlmClientService).to have_received(:call_with_schema) do |args|
        expect(args[:provider]).to eq(:openai)
        expect(args[:api]).to eq(:chat_completions)
        expect(args[:model]).to eq("gpt-4o-mini")
        expect(args[:temperature]).to eq(0.4)
        expect(args[:schema]).to be < RubyLLM::Schema
        expect(args[:prompt]).to include("expert at naming LLM prompts")
      end
    end
  end
end
