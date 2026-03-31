# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Router do
  describe ".assistant_for" do
    def route_for(message, context)
      described_class.assistant_for(message: message, context: context)
    end

    let(:prompt_version_context) do
      { page_type: :prompt_version_detail, prompt_version_id: 42 }
    end

    let(:llm_default_response) do
      double(
        "NormalizedLlmResponse",
        text: "default",
        tool_calls: []
      )
    end

    before do
      allow(PromptTracker::LlmClients::RubyLlmService)
        .to receive(:call)
        .and_return(llm_default_response)
    end

    it "routes 'run all tests' on prompt version page to the test wizard" do
      test_wizard_response = double(
        "NormalizedLlmResponse",
        text: "test_wizard",
        tool_calls: []
      )

      allow(PromptTracker::LlmClients::RubyLlmService)
        .to receive(:call)
        .and_return(test_wizard_response)

      assistant = route_for("Run all tests", prompt_version_context)

      expect(assistant).to eq(:test_wizard)
    end

    it "routes generic messages on prompt version page to the default assistant" do
      assistant = route_for("Help me improve this prompt", prompt_version_context)

      expect(assistant).to eq(:default)
    end

      it "routes test-related messages outside prompt version pages to the default assistant" do
        context = { page_type: :prompts_list }

        expect(PromptTracker::LlmClients::RubyLlmService)
          .to receive(:call)
          .and_return(llm_default_response)

        assistant = route_for("Run all tests", context)

        expect(assistant).to eq(:default)
      end

      it "routes prompt creation requests on prompts list page to the prompt creation wizard" do
        prompt_creation_response = double(
          "NormalizedLlmResponse",
          text: "prompt_creation_wizard",
          tool_calls: []
        )

        allow(PromptTracker::LlmClients::RubyLlmService)
          .to receive(:call)
          .and_return(prompt_creation_response)

        assistant = route_for("Create a new prompt called Support Bot", { page_type: :prompts_list })

        expect(assistant).to eq(:prompt_creation_wizard)
      end
  end
end
