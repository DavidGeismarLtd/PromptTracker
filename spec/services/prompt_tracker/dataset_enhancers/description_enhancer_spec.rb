# frozen_string_literal: true

require "rails_helper"
require "ruby_llm/schema"

RSpec.describe PromptTracker::DatasetEnhancers::DescriptionEnhancer do
  describe ".enhance" do
    let(:mock_response) do
      {
        text: {
          description: "Dataset of customer support scenarios used to validate the prompt."
        }.to_json
      }
    end

    before do
      PromptTracker.configuration.contexts = {
        dataset_generation: {
          default_provider: :openai,
          default_api: :chat_completions,
          default_model: "gpt-4o",
          default_temperature: 0.5
        }
      }

      allow(PromptTracker::LlmClientService)
        .to receive(:call_with_schema)
        .and_return(mock_response)
    end

    it "returns the enhanced dataset description from the LLM response" do
      result = described_class.enhance(
        name: "support_edge_cases",
        raw_description: "Edge case scenarios",
        dataset_type: "single_turn",
        testable_name: "Support prompt"
      )

      expect(result[:description]).to include("customer support scenarios")
    end

    it "falls back to the raw description when LLM does not return a description" do
      allow(PromptTracker::LlmClientService)
        .to receive(:call_with_schema)
        .and_return({ text: {}.to_json })

      result = described_class.enhance(
        name: "support_edge_cases",
        raw_description: "Short description from user",
        dataset_type: "single_turn",
        testable_name: "Support prompt"
      )

      expect(result[:description]).to eq("Short description from user")
    end

    it "falls back to a generic description when no description is provided" do
      allow(PromptTracker::LlmClientService)
        .to receive(:call_with_schema)
        .and_return({ text: {}.to_json })

      result = described_class.enhance(
        name: "support_edge_cases",
        raw_description: nil,
        dataset_type: "single_turn",
        testable_name: "Support prompt"
      )

      expect(result[:description]).to eq("Dataset for testing Support prompt.")
    end

    it "calls LlmClientService.call_with_schema with dataset_generation context defaults" do
      described_class.enhance(
        name: "support_edge_cases",
        raw_description: "Edge case scenarios",
        dataset_type: "single_turn",
        testable_name: "Support prompt"
      )

      expect(PromptTracker::LlmClientService).to have_received(:call_with_schema) do |args|
        expect(args[:provider]).to eq(:openai)
        expect(args[:api]).to eq(:chat_completions)
        expect(args[:model]).to eq("gpt-4o")
        expect(args[:schema]).to be < RubyLLM::Schema
        expect(args[:prompt]).to include("documenting datasets for an LLM prompt testing tool")
      end
    end
  end
end
