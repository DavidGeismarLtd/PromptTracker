# frozen_string_literal: true

require "test_helper"
require "prompt_tracker/trackable"
require "ostruct"

module PromptTracker
  class TrackableTest < ActiveSupport::TestCase
    # Test class that includes Trackable
    class TestController
      include PromptTracker::Trackable

      attr_accessor :current_user, :session

      def initialize
        @current_user = OpenStruct.new(id: "user_123")
        @session = OpenStruct.new(id: "session_456")
      end
    end

    setup do
      @controller = TestController.new

      # Create a test prompt with a version
      @prompt = Prompt.create!(
        name: "test_prompt",
        description: "Test prompt",
        category: "test"
      )

      @version = @prompt.prompt_versions.create!(
        user_prompt: "Hello {{name}}!",
        variables_schema: [
          { "name" => "name", "type" => "string", "required" => true }
        ],
        status: "active",
        source: "api"
      )
    end

    # Basic Usage Tests

    test "should include track_llm_call method" do
      assert @controller.respond_to?(:track_llm_call)
    end

    test "should track LLM call using track_llm_call" do
      result = @controller.track_llm_call(
        "test_prompt",
        variables: { name: "John" },
        provider: "openai",
        model: "gpt-4"
      ) do |rendered_prompt|
        assert_equal "Hello John!", rendered_prompt
        "Hi there!"
      end

      assert result[:llm_response].present?
      assert_equal "Hi there!", result[:response_text]
      assert result[:tracking_id].present?
    end

    test "should pass all parameters to LlmCallService" do
      result = @controller.track_llm_call(
        "test_prompt",
        variables: { name: "Alice" },
        provider: "anthropic",
        model: "claude-3-opus",
        version: 1,
        user_id: "user_789",
        session_id: "session_abc",
        environment: "production",
        metadata: { custom: "data" }
      ) { |_prompt| "Response" }

      llm_response = result[:llm_response]
      assert_equal "anthropic", llm_response.provider
      assert_equal "claude-3-opus", llm_response.model
      assert_equal "user_789", llm_response.user_id
      assert_equal "session_abc", llm_response.session_id
      assert_equal "production", llm_response.environment
      assert_equal "data", llm_response.context["custom"]
    end

    # Convenience Tests

    test "should work with minimal parameters" do
      result = @controller.track_llm_call(
        "test_prompt",
        variables: { name: "Bob" },
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| "Response" }

      assert result[:llm_response].present?
      assert_equal "Response", result[:response_text]
    end

    test "should work with controller context" do
      result = @controller.track_llm_call(
        "test_prompt",
        variables: { name: "Charlie" },
        provider: "openai",
        model: "gpt-4",
        user_id: @controller.current_user.id,
        session_id: @controller.session.id
      ) { |_prompt| "Response" }

      llm_response = result[:llm_response]
      assert_equal "user_123", llm_response.user_id
      assert_equal "session_456", llm_response.session_id
    end

    # Error Handling Tests

    test "should raise error for nonexistent prompt" do
      error = assert_raises(LlmCallService::PromptNotFoundError) do
        @controller.track_llm_call(
          "nonexistent",
          variables: {},
          provider: "openai",
          model: "gpt-4"
        ) { |_prompt| "Response" }
      end

      assert_match /Prompt 'nonexistent' not found/, error.message
    end

    test "should raise error if no block given" do
      error = assert_raises(LlmCallService::NoBlockGivenError) do
        @controller.track_llm_call(
          "test_prompt",
          variables: { name: "Test" },
          provider: "openai",
          model: "gpt-4"
        )
      end

      assert_match /Block required/, error.message
    end

    test "should propagate LLM errors" do
      error_raised = false


      @controller.track_llm_call(
        "test_prompt",
        variables: { name: "Test" },
        provider: "openai",
        model: "gpt-4"
      ) do |_prompt|
        raise StandardError, "API error"
      end
      end

      assert error_raised
    end

    # Integration Tests

    test "should create LlmResponse record" do
      assert_difference "LlmResponse.count", 1 do
        @controller.track_llm_call(
          "test_prompt",
          variables: { name: "Test" },
          provider: "openai",
          model: "gpt-4"
        ) { |_prompt| "Response" }
      end
    end

    test "should track successful response" do
      result = @controller.track_llm_call(
        "test_prompt",
        variables: { name: "Test" },
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| "Success response" }

      llm_response = result[:llm_response]
      assert_equal "success", llm_response.status
      assert_equal "Success response", llm_response.response_text
    end

    test "should track failed response" do
      begin
        @controller.track_llm_call(
          "test_prompt",
          variables: { name: "Test" },
          provider: "openai",
          model: "gpt-4"
        ) do |_prompt|
          raise "Failure"
        end
      rescue StandardError
        # Expected
      end

      llm_response = LlmResponse.last
      assert_equal "error", llm_response.status
      assert_equal "RuntimeError", llm_response.error_type
      assert_equal "Failure", llm_response.error_message
    end

    # Multiple Calls Tests

    test "should handle multiple sequential calls" do
      result1 = @controller.track_llm_call(
        "test_prompt",
        variables: { name: "First" },
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| "Response 1" }

      result2 = @controller.track_llm_call(
        "test_prompt",
        variables: { name: "Second" },
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| "Response 2" }

      assert_equal "Response 1", result1[:response_text]
      assert_equal "Response 2", result2[:response_text]
      assert_not_equal result1[:tracking_id], result2[:tracking_id]
    end

    # Default Values Tests

    test "should use empty hash for variables by default" do
      # Create a prompt with no required variables
      prompt = Prompt.create!(name: "no_vars", description: "Test")
      prompt.prompt_versions.create!(
        user_prompt: "Hello!",
        variables_schema: [],
        status: "active",
        source: "api"
      )

      result = @controller.track_llm_call(
        "no_vars",
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| "Response" }

      assert result[:llm_response].present?
    end

    test "should use nil for optional parameters by default" do
      result = @controller.track_llm_call(
        "test_prompt",
        variables: { name: "Test" },
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| "Response" }

      llm_response = result[:llm_response]
      assert_nil llm_response.user_id
      assert_nil llm_response.session_id
    end
  end
end
