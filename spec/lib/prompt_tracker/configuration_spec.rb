# frozen_string_literal: true

require "rails_helper"

module PromptTracker
  RSpec.describe Configuration do
    let(:config) { Configuration.new }

    describe "#initialize" do
      it "sets default prompts_path" do
        expect(config.prompts_path).to be_present
      end

      it "sets basic_auth_username to nil" do
        expect(config.basic_auth_username).to be_nil
      end

      it "sets basic_auth_password to nil" do
        expect(config.basic_auth_password).to be_nil
      end

      it "sets available_models to empty hash" do
        expect(config.available_models).to eq({})
      end

      it "sets provider_api_key_env_vars to empty hash" do
        expect(config.provider_api_key_env_vars).to eq({})
      end

      it "sets prompt_generator_model to nil" do
        expect(config.prompt_generator_model).to be_nil
      end

      it "sets dataset_generator_model to nil" do
        expect(config.dataset_generator_model).to be_nil
      end

      it "sets llm_judge_model to nil" do
        expect(config.llm_judge_model).to be_nil
      end
    end

    describe "#available_models" do
      it "can be set to custom providers and models" do
        config.available_models = {
          openai: [
            { id: "gpt-4o", name: "GPT-4o", category: "Latest" }
          ],
          custom_provider: [
            { id: "custom-model", name: "Custom Model", category: "Custom" }
          ]
        }

        expect(config.available_models.keys).to contain_exactly(:openai, :custom_provider)
        expect(config.available_models[:openai].first[:id]).to eq("gpt-4o")
        expect(config.available_models[:custom_provider].first[:id]).to eq("custom-model")
      end
    end

    describe "#provider_api_key_env_vars" do
      it "can be set to custom environment variable mappings" do
        config.provider_api_key_env_vars = {
          openai: "OPENAI_API_KEY",
          custom_provider: "CUSTOM_PROVIDER_API_KEY"
        }

        expect(config.provider_api_key_env_vars[:openai]).to eq("OPENAI_API_KEY")
        expect(config.provider_api_key_env_vars[:custom_provider]).to eq("CUSTOM_PROVIDER_API_KEY")
      end
    end

    describe "#basic_auth_enabled?" do
      it "returns false when both username and password are nil" do
        config.basic_auth_username = nil
        config.basic_auth_password = nil
        expect(config.basic_auth_enabled?).to be false
      end

      it "returns false when only username is set" do
        config.basic_auth_username = "admin"
        config.basic_auth_password = nil
        expect(config.basic_auth_enabled?).to be false
      end

      it "returns false when only password is set" do
        config.basic_auth_username = nil
        config.basic_auth_password = "secret"
        expect(config.basic_auth_enabled?).to be false
      end

      it "returns true when both username and password are set" do
        config.basic_auth_username = "admin"
        config.basic_auth_password = "secret"
        expect(config.basic_auth_enabled?).to be true
      end
    end
  end
end
