# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::EvaluatorConfigsHelper, type: :helper do
  let(:prompt) { create(:prompt) }

  describe "#evaluator_disabled_state" do
    context "with file_search evaluator" do
      context "when vector store is attached" do
        let(:prompt_version) do
          create(:prompt_version, prompt: prompt, model_config: {
            "provider" => "openai",
            "api" => "responses",
            "model" => "gpt-4o",
            "tools" => [ "file_search" ],
            "tool_config" => {
              "file_search" => {
                "vector_store_ids" => [ "vs_123" ]
              }
            }
          })
        end

        it "returns not disabled" do
          is_disabled, reason = helper.evaluator_disabled_state(:file_search, prompt_version)

          expect(is_disabled).to be false
          expect(reason).to be_nil
        end
      end

      context "when vector store is not attached" do
        let(:prompt_version) do
          create(:prompt_version, prompt: prompt, model_config: {
            "provider" => "openai",
            "api" => "responses",
            "model" => "gpt-4o",
            "tools" => [ "file_search" ],
            "tool_config" => {}
          })
        end

        it "returns disabled with reason" do
          is_disabled, reason = helper.evaluator_disabled_state(:file_search, prompt_version)

          expect(is_disabled).to be true
          expect(reason).to eq("Attach a vector store to the assistant first")
        end
      end
    end

    context "with function_call evaluator" do
      context "when functions are enabled and defined" do
        let(:prompt_version) do
          create(:prompt_version, prompt: prompt, model_config: {
            "provider" => "openai",
            "api" => "responses",
            "model" => "gpt-4o",
            "tools" => [ "functions" ],
            "tool_config" => {
              "functions" => [
                { "name" => "get_weather", "parameters" => {} }
              ]
            }
          })
        end

        it "returns not disabled" do
          is_disabled, reason = helper.evaluator_disabled_state(:function_call, prompt_version)

          expect(is_disabled).to be false
          expect(reason).to be_nil
        end
      end

      context "when functions tool is enabled but no functions defined" do
        let(:prompt_version) do
          create(:prompt_version, prompt: prompt, model_config: {
            "provider" => "openai",
            "api" => "responses",
            "model" => "gpt-4o",
            "tools" => [ "functions" ],
            "tool_config" => {}
          })
        end

        it "returns disabled with reason" do
          is_disabled, reason = helper.evaluator_disabled_state(:function_call, prompt_version)

          expect(is_disabled).to be true
          expect(reason).to eq("Enable functions and define at least one function first")
        end
      end

      context "when functions tool is not enabled" do
        let(:prompt_version) do
          create(:prompt_version, prompt: prompt, model_config: {
            "provider" => "openai",
            "api" => "responses",
            "model" => "gpt-4o",
            "tools" => []
          })
        end

        it "returns disabled with reason" do
          is_disabled, reason = helper.evaluator_disabled_state(:function_call, prompt_version)

          expect(is_disabled).to be true
          expect(reason).to eq("Enable functions and define at least one function first")
        end
      end
    end

    context "with web_search evaluator" do
      context "when web_search is enabled" do
        let(:prompt_version) do
          create(:prompt_version, prompt: prompt, model_config: {
            "provider" => "openai",
            "api" => "responses",
            "model" => "gpt-4o",
            "tools" => [ "web_search" ]
          })
        end

        it "returns not disabled" do
          is_disabled, reason = helper.evaluator_disabled_state(:web_search, prompt_version)

          expect(is_disabled).to be false
          expect(reason).to be_nil
        end
      end

      context "when web_search is not enabled" do
        let(:prompt_version) do
          create(:prompt_version, prompt: prompt, model_config: {
            "provider" => "openai",
            "api" => "responses",
            "model" => "gpt-4o",
            "tools" => []
          })
        end

        it "returns disabled with reason" do
          is_disabled, reason = helper.evaluator_disabled_state(:web_search, prompt_version)

          expect(is_disabled).to be true
          expect(reason).to eq("Enable web search in the prompt version first")
        end
      end
    end

    context "with code_interpreter evaluator" do
      context "when code_interpreter is enabled" do
        let(:prompt_version) do
          create(:prompt_version, prompt: prompt, model_config: {
            "provider" => "openai",
            "api" => "responses",
            "model" => "gpt-4o",
            "tools" => [ "code_interpreter" ]
          })
        end

        it "returns not disabled" do
          is_disabled, reason = helper.evaluator_disabled_state(:code_interpreter, prompt_version)

          expect(is_disabled).to be false
          expect(reason).to be_nil
        end
      end

      context "when code_interpreter is not enabled" do
        let(:prompt_version) do
          create(:prompt_version, prompt: prompt, model_config: {
            "provider" => "openai",
            "api" => "responses",
            "model" => "gpt-4o",
            "tools" => []
          })
        end

        it "returns disabled with reason" do
          is_disabled, reason = helper.evaluator_disabled_state(:code_interpreter, prompt_version)

          expect(is_disabled).to be true
          expect(reason).to eq("Enable code interpreter in the prompt version first")
        end
      end
    end

    context "with evaluator that has no requirements" do
      let(:prompt_version) do
        create(:prompt_version, prompt: prompt, model_config: {
          "provider" => "openai",
          "api" => "chat_completions",
          "model" => "gpt-4o"
        })
      end

      it "returns not disabled for length evaluator" do
        is_disabled, reason = helper.evaluator_disabled_state(:length, prompt_version)

        expect(is_disabled).to be false
        expect(reason).to be_nil
      end

      it "returns not disabled for llm_judge evaluator" do
        is_disabled, reason = helper.evaluator_disabled_state(:llm_judge, prompt_version)

        expect(is_disabled).to be false
        expect(reason).to be_nil
      end
    end
  end
end
