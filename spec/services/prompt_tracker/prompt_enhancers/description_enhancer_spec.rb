# frozen_string_literal: true

require "rails_helper"
require "ruby_llm/schema"

RSpec.describe PromptTracker::PromptEnhancers::DescriptionEnhancer do
  describe ".enhance" do
    let(:mock_response) do
      {
        text: {
          description: "Generates high-quality support replies based on customer issues."
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

    it "returns enhanced description from the LLM response" do
      result = described_class.enhance(
        name: "Support assistant",
        raw_description: "Helps with issues",
        system_prompt_concept: "Customer support triage"
      )

      expect(result[:description]).to include("high-quality support replies")
    end

    it "falls back to the raw description when LLM does not return a description" do
      allow(PromptTracker::LlmClientService)
        .to receive(:call_with_schema)
        .and_return({ text: {}.to_json })

      result = described_class.enhance(
        name: "Support assistant",
        raw_description: "Short description from user",
        system_prompt_concept: ""
      )

      expect(result[:description]).to eq("Short description from user")
    end

    it "calls LlmClientService.call_with_schema with prompt_generation context defaults" do
      described_class.enhance(
        name: "Support assistant",
        raw_description: "Helps with issues",
        system_prompt_concept: "Customer support triage"
      )

      expect(PromptTracker::LlmClientService).to have_received(:call_with_schema) do |args|
        expect(args[:provider]).to eq(:openai)
        expect(args[:api]).to eq(:chat_completions)
        expect(args[:model]).to eq("gpt-4o-mini")
        expect(args[:schema]).to be < RubyLLM::Schema
        expect(args[:prompt]).to include("technical writer")
      end
    end
  end
end
