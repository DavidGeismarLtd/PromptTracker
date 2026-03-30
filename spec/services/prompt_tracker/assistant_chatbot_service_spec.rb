# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbotService do
  let(:session_id) { "test_session_123" }
  let(:message) { "Create a new prompt" }
  let(:context) { { page_type: :prompts_list } }

  # Mock LLM service
  let(:mock_llm_response) do
    double(
      "NormalizedLlmResponse",
      text: "I'll help you create a prompt. What should we call it?",
      tool_calls: []
    )
  end

  let(:mock_llm_service) do
    service = double("LlmClients::RubyLlmService")
    allow(service).to receive(:call).and_return(mock_llm_response)
    service
  end

  before do
    # Clear cache before each test
    Rails.cache.clear

    # Mock LLM service
    allow(PromptTracker::LlmClients::RubyLlmService).to receive(:new).and_return(mock_llm_service)
  end

  describe ".call" do
    context "with a simple text response" do
      it "returns a successful result" do
        result = described_class.call(
          message: message,
          session_id: session_id,
          context: context
        )

        expect(result.success?).to be true
        expect(result.response).to eq("I'll help you create a prompt. What should we call it?")
        expect(result.error).to be_nil
      end

      it "saves the conversation to cache" do
        described_class.call(
          message: message,
          session_id: session_id,
          context: context
        )

        cached = Rails.cache.read("assistant_chatbot_conversation:#{session_id}")
        expect(cached).to be_an(Array)
        expect(cached.length).to eq(2) # user + assistant
        expect(cached[0][:role]).to eq("user")
        expect(cached[0][:content]).to eq(message)
        expect(cached[1][:role]).to eq("assistant")
      end
    end

    context "with conversation history" do
      before do
        # Pre-populate cache with history
        Rails.cache.write(
          "assistant_chatbot_conversation:#{session_id}",
          [
            { role: "user", content: "Hello" },
            { role: "assistant", content: "Hi! How can I help?" }
          ]
        )
      end

      it "includes previous conversation in LLM call" do
        expect(mock_llm_service).to receive(:call) do |args|
          # Verify history is passed correctly
          expect(args[:prompt]).to include("Hello")
          expect(args[:prompt]).to include("Hi! How can I help?")
          mock_llm_response
        end

        described_class.call(
          message: "Create a prompt",
          session_id: session_id,
          context: context
        )
      end

      it "appends new messages to existing history" do
        described_class.call(
          message: "Create a prompt",
          session_id: session_id,
          context: context
        )

        cached = Rails.cache.read("assistant_chatbot_conversation:#{session_id}")
        expect(cached.length).to eq(4) # 2 previous + 2 new
      end
    end

    context "with function call response" do
      let(:mock_llm_with_tool_call) do
        double(
          "NormalizedLlmResponse",
          text: "I'll create that prompt for you.",
          tool_calls: [
            {
              function_name: "create_prompt",
              arguments: {
                name: "Test Prompt",
                  system_prompt_concept: "You are a helpful assistant",
                model: "gpt-4o",
                temperature: 0.7
              }
            }
          ]
        )
      end

      context "with create_dataset function call" do
        let(:mock_llm_with_dataset_call) do
          double(
            "NormalizedLlmResponse",
            text: "I'll create that dataset for you.",
            tool_calls: [
              {
                function_name: "create_dataset",
                arguments: {
                  prompt_version_id: 123,
                  name: "User provided dataset name"
                }
              }
            ]
          )
        end

        before do
          allow(mock_llm_service).to receive(:call).and_return(mock_llm_with_dataset_call)
        end

        it "treats create_dataset as an action that requires confirmation" do
          result = described_class.call(
            message: "Create a dataset",
            session_id: session_id,
            context: context
          )

          expect(result.success?).to be true
          expect(result.pending_action).to be_present
          expect(result.pending_action[:function_name]).to eq("create_dataset")
          expect(result.pending_action[:arguments][:prompt_version_id]).to eq(123)
        end
      end

      before do
        allow(mock_llm_service).to receive(:call).and_return(mock_llm_with_tool_call)
      end

      it "returns a pending_action when function requires confirmation" do
        result = described_class.call(
          message: "Create a prompt called Test",
          session_id: session_id,
          context: context
        )

        expect(result.success?).to be true
        expect(result.pending_action).to be_present
        expect(result.pending_action[:function_name]).to eq("create_prompt")
        expect(result.pending_action[:arguments][:name]).to eq("Test Prompt")
      end

      it "saves the confirmation message to history" do
        described_class.call(
          message: "Create a prompt called Test",
          session_id: session_id,
          context: context
        )

        cached = Rails.cache.read("assistant_chatbot_conversation:#{session_id}")
        expect(cached.last[:role]).to eq("assistant")
        expect(cached.last[:content]).to include("Test Prompt") # Check for actual prompt name
        expect(cached.last[:content]).to include("proceed") # Check for confirmation text
      end
    end

    context "with read-only function call (no confirmation required)" do
      let(:mock_llm_with_query_call) do
        double(
          "NormalizedLlmResponse",
          text: "Here's the prompt info.",
          tool_calls: [
            {
              function_name: "get_prompt_version_info",
              arguments: { prompt_version_id: 123 }
            }
          ]
        )
      end

      let(:mock_function_result) do
        PromptTracker::AssistantChatbot::FunctionExecutor::Result.new(
          success?: true,
          message: "Prompt version details: ...",
          links: [],
          entities_created: {},
          error: nil
        )
      end

      before do
        allow(mock_llm_service).to receive(:call).and_return(mock_llm_with_query_call)
        allow_any_instance_of(PromptTracker::AssistantChatbot::FunctionExecutor)
          .to receive(:call)
          .and_return(mock_function_result)
      end

      it "executes immediately without confirmation" do
        result = described_class.call(
          message: "What's in prompt version 123?",
          session_id: session_id,
          context: context
        )

        expect(result.success?).to be true
        expect(result.pending_action).to be_nil
        expect(result.response).to include("Prompt version details")
      end
    end

    context "conversation history limits" do
      before do
        # Create a long conversation history
        long_history = 100.times.map do |i|
          [
            { role: "user", content: "Message #{i}" },
            { role: "assistant", content: "Response #{i}" }
          ]
        end.flatten

        Rails.cache.write(
          "assistant_chatbot_conversation:#{session_id}",
          long_history
        )
      end

      it "limits history to configured max messages" do
        described_class.call(
          message: "New message",
          session_id: session_id,
          context: context
        )

        cached = Rails.cache.read("assistant_chatbot_conversation:#{session_id}")
        # Should be limited to 50 (or configured max) plus the 2 new messages
        expect(cached.length).to be <= 52
      end
    end
  end

  describe ".execute_function" do
    let(:function_name) { "create_prompt" }
    let(:arguments) do
      {
        name: "Test Prompt",
          system_prompt_concept: "You are helpful",
        model: "gpt-4o",
        temperature: 0.7
      }
    end

    let(:mock_function_result) do
      PromptTracker::AssistantChatbot::FunctionExecutor::Result.new(
        success?: true,
        message: "Prompt created successfully!",
        links: [ { text: "View prompt", url: "/prompts/1" } ],
        entities_created: { prompt_id: 1 },
        error: nil
      )
    end

    before do
      allow_any_instance_of(PromptTracker::AssistantChatbot::FunctionExecutor)
        .to receive(:call)
        .and_return(mock_function_result)
    end

    it "executes the function and returns result" do
      result = described_class.execute_function(
        session_id: session_id,
        function_name: function_name,
        arguments: arguments
      )

      expect(result.success?).to be true
      expect(result.response).to eq("Prompt created successfully!")
      expect(result.links.length).to eq(1)
    end

    it "saves the execution result to history" do
      described_class.execute_function(
        session_id: session_id,
        function_name: function_name,
        arguments: arguments
      )

      cached = Rails.cache.read("assistant_chatbot_conversation:#{session_id}")
      expect(cached).to be_present
      expect(cached.last[:role]).to eq("assistant")
      expect(cached.last[:content]).to include("Prompt created successfully")
    end

    context "when function execution fails" do
      let(:mock_error_result) do
        PromptTracker::AssistantChatbot::FunctionExecutor::Result.new(
          success?: false,
          message: nil,
          links: [],
          entities_created: {},
          error: "Failed to create prompt: Name can't be blank"
        )
      end

      before do
        allow_any_instance_of(PromptTracker::AssistantChatbot::FunctionExecutor)
          .to receive(:call)
          .and_return(mock_error_result)
      end

      it "returns error result" do
        result = described_class.execute_function(
          session_id: session_id,
          function_name: function_name,
          arguments: arguments
        )

        expect(result.success?).to be false
        expect(result.error).to include("Failed to create prompt")
      end
    end
  end

  describe ".generate_suggestions" do
    it "returns context-aware suggestions" do
      suggestions = described_class.generate_suggestions({ page_type: :prompts_list })

      expect(suggestions).to be_an(Array)
      # Actual suggestions depend on ContextDetector implementation
    end
  end
end
