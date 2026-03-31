# frozen_string_literal: true

require "rails_helper"
require "ruby_llm/schema"

RSpec.describe PromptTracker::DatasetEnhancers::NameEnhancer do
  describe ".enhance" do
    let(:mock_response) do
      {
        text: {
          name: "customer_support_edge_cases"
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

    it "returns the enhanced dataset name from the LLM response" do
      result = described_class.enhance(
        raw_name: "Edge cases",
        testable_name: "Support prompt",
        dataset_type: "single_turn",
        purpose: "Cover edge cases"
      )

      expect(result[:name]).to eq("customer_support_edge_cases")
    end

    it "falls back to a slug based on raw_name when LLM does not return a name" do
      allow(PromptTracker::LlmClientService)
        .to receive(:call_with_schema)
        .and_return({ text: {}.to_json })

      result = described_class.enhance(
        raw_name: "Billing edge cases",
        testable_name: "",
        dataset_type: "",
        purpose: ""
      )

      expect(result[:name]).to eq("billing_edge_cases")
    end

    it "calls LlmClientService.call_with_schema with dataset_generation context defaults" do
      described_class.enhance(
        raw_name: "Edge cases",
        testable_name: "Support prompt",
        dataset_type: "single_turn",
        purpose: "Cover edge cases"
      )

      expect(PromptTracker::LlmClientService).to have_received(:call_with_schema) do |args|
        expect(args[:provider]).to eq(:openai)
        expect(args[:api]).to eq(:chat_completions)
        expect(args[:model]).to eq("gpt-4o")
        expect(args[:temperature]).to eq(0.5)
        expect(args[:schema]).to be < RubyLLM::Schema
        expect(args[:prompt]).to include("naming datasets for LLM prompt testing")
      end
    end
  end
end
