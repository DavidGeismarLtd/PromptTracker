# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  RSpec.describe ApplicationHelper, type: :helper do
    describe "#provider_api_key_present?" do
      before do
        PromptTracker.configuration.provider_api_key_env_vars = {
          openai: "OPENAI_API_KEY",
          anthropic: "ANTHROPIC_API_KEY",
          custom_provider: "CUSTOM_PROVIDER_API_KEY"
        }
      end

      context "when API key is present" do
        before do
          allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("sk-test")
        end

        it "returns true for string provider" do
          expect(helper.provider_api_key_present?("openai")).to be true
        end

        it "returns true for symbol provider" do
          expect(helper.provider_api_key_present?(:openai)).to be true
        end
      end

      context "when API key is missing" do
        before do
          allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)
        end

        it "returns false" do
          expect(helper.provider_api_key_present?("openai")).to be false
        end
      end

      context "when API key is empty string" do
        before do
          allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("")
        end

        it "returns false" do
          expect(helper.provider_api_key_present?("openai")).to be false
        end
      end

      context "when provider is not configured" do
        it "returns false" do
          expect(helper.provider_api_key_present?("unknown_provider")).to be false
        end
      end
    end

    describe "#available_providers" do
      before do
        PromptTracker.configuration.available_models = {
          openai: [ { id: "gpt-4o", name: "GPT-4o", category: "Latest" } ],
          anthropic: [ { id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", category: "Latest" } ],
          google: [ { id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", category: "Latest" } ]
        }
        PromptTracker.configuration.provider_api_key_env_vars = {
          openai: "OPENAI_API_KEY",
          anthropic: "ANTHROPIC_API_KEY",
          google: "GOOGLE_API_KEY"
        }
      end

      context "when no API keys are configured" do
        before do
          allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)
          allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)
          allow(ENV).to receive(:[]).with("GOOGLE_API_KEY").and_return(nil)
        end

        it "returns empty array" do
          expect(helper.available_providers).to be_empty
        end
      end

      context "when multiple API keys are configured" do
        before do
          allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("sk-test")
          allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("sk-ant-test")
          allow(ENV).to receive(:[]).with("GOOGLE_API_KEY").and_return(nil)
        end

        it "returns all configured providers" do
          expect(helper.available_providers).to contain_exactly(:openai, :anthropic)
        end
      end

      context "when all API keys are configured" do
        before do
          allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("sk-test")
          allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("sk-ant-test")
          allow(ENV).to receive(:[]).with("GOOGLE_API_KEY").and_return("google-test")
        end

        it "returns all providers" do
          expect(helper.available_providers).to contain_exactly(:openai, :anthropic, :google)
        end
      end
    end
  end
end
