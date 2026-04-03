# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::Router do
  describe ".assistant_for" do
    def route_for(message, context, conversation_history: [])
      described_class.assistant_for(message: message, context: context, conversation_history: conversation_history)
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

    it "routes 'run all tests' on prompt version page to the test runner wizard" do
      test_runner_response = double(
        "NormalizedLlmResponse",
        text: "test_runner_wizard",
        tool_calls: []
      )

      allow(PromptTracker::LlmClients::RubyLlmService)
        .to receive(:call)
        .and_return(test_runner_response)

      assistant = route_for("Run all tests", prompt_version_context)

      expect(assistant).to eq(:test_runner_wizard)
    end

    it "routes 'write tests for this prompt' on prompt version page to the test creator wizard" do
      test_creator_response = double(
        "NormalizedLlmResponse",
        text: "test_creator_wizard",
        tool_calls: []
      )

      allow(PromptTracker::LlmClients::RubyLlmService)
        .to receive(:call)
        .and_return(test_creator_response)

      assistant = route_for("Write tests for this prompt", prompt_version_context)

      expect(assistant).to eq(:test_creator_wizard)
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

      it "routes prompt creation requests on prompts list page to the agent creation wizard" do
        prompt_creation_response = double(
          "NormalizedLlmResponse",
          text: "agent_creation_wizard",
          tool_calls: []
        )

        allow(PromptTracker::LlmClients::RubyLlmService)
          .to receive(:call)
          .and_return(prompt_creation_response)

        assistant = route_for("Create a new prompt called Support Bot", { page_type: :prompts_list })

        expect(assistant).to eq(:agent_creation_wizard)
      end

      it "includes conversation history in the LLM prompt" do
        history = [
          { role: "user", content: "Create a new agent" },
          { role: "assistant", content: "What should we call it?" }
        ]

        allow(PromptTracker::LlmClients::RubyLlmService)
          .to receive(:call)
          .and_return(llm_default_response)

        route_for("Marty", prompt_version_context, conversation_history: history)

        expect(PromptTracker::LlmClients::RubyLlmService).to have_received(:call).with(
          hash_including(
            prompt: a_string_including("Create a new agent", "What should we call it?", "Marty")
          )
        )
      end
  end
end
