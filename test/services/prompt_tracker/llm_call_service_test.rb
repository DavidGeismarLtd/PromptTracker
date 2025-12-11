# frozen_string_literal: true

require "test_helper"

module PromptTracker
  class LlmCallServiceTest < ActiveSupport::TestCase
    setup do
      # Create a test prompt with a version
      @prompt = Prompt.create!(
        name: "test_greeting",
        description: "Test greeting prompt"
      )

      @version = @prompt.prompt_versions.create!(
        user_prompt: "Hello {{name}}, welcome to {{service}}!",
        variables_schema: [
          { "name" => "name", "type" => "string", "required" => true },
          { "name" => "service", "type" => "string", "required" => true }
        ],
        status: "active",
        source: "api"
      )

      @variables = { name: "John", service: "PromptTracker" }
    end

    # Basic Tracking Tests

    test "should track successful LLM call" do
      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "openai",
        model: "gpt-4"
      ) do |rendered_prompt|
        assert_equal "Hello John, welcome to PromptTracker!", rendered_prompt
        "Hi there! How can I help you?"
      end

      assert result[:llm_response].present?
      assert_equal "Hi there! How can I help you?", result[:response_text]
      assert result[:tracking_id].present?

      # Check database record
      llm_response = result[:llm_response]
      assert_equal "success", llm_response.status
      assert_equal "Hello John, welcome to PromptTracker!", llm_response.rendered_prompt
      assert_equal "Hi there! How can I help you?", llm_response.response_text
      assert_equal "openai", llm_response.provider
      assert_equal "gpt-4", llm_response.model
      assert llm_response.response_time_ms.present?
    end

    test "should track LLM call with OpenAI response format" do
      openai_response = {
        "choices" => [
          { "message" => { "content" => "Hello from GPT-4!" } }
        ],
        "usage" => {
          "prompt_tokens" => 10,
          "completion_tokens" => 5,
          "total_tokens" => 15
        },
        "model" => "gpt-4",
        "id" => "chatcmpl-123"
      }

      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| openai_response }

      llm_response = result[:llm_response]
      assert_equal "Hello from GPT-4!", llm_response.response_text
      assert_equal 10, llm_response.tokens_prompt
      assert_equal 5, llm_response.tokens_completion
      assert_equal 15, llm_response.tokens_total
      assert llm_response.cost_usd.present?
      assert llm_response.cost_usd > 0
    end

    test "should track LLM call with Anthropic response format" do
      anthropic_response = {
        "content" => [
          { "text" => "Hello from Claude!" }
        ],
        "usage" => {
          "input_tokens" => 20,
          "output_tokens" => 10
        }
      }

      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "anthropic",
        model: "claude-3-opus"
      ) { |_prompt| anthropic_response }

      llm_response = result[:llm_response]
      assert_equal "Hello from Claude!", llm_response.response_text
      assert_equal 20, llm_response.tokens_prompt
      assert_equal 10, llm_response.tokens_completion
      assert_equal 30, llm_response.tokens_total
    end

    # Version Selection Tests

    test "should use active version by default" do
      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| "Response" }

      assert_equal @version.id, result[:llm_response].prompt_version_id
    end

    test "should use specific version when provided" do
      # Create version 2
      version2 = @prompt.prompt_versions.create!(
        user_prompt: "Hi {{name}}!",
        variables_schema: [{ "name" => "name", "type" => "string", "required" => true }],
        status: "deprecated",
        source: "api"
      )

      result = LlmCallService.track(
        prompt_name: "test_greeting",
        version: 2,
        variables: { name: "Alice" },
        provider: "openai",
        model: "gpt-4"
      ) do |rendered_prompt|
        assert_equal "Hi Alice!", rendered_prompt
        "Response"
      end

      assert_equal version2.id, result[:llm_response].prompt_version_id
    end

    # Error Handling Tests

    test "should raise error if prompt not found" do
      error = assert_raises(LlmCallService::PromptNotFoundError) do
        LlmCallService.track(
          prompt_name: "nonexistent_prompt",
          variables: {},
          provider: "openai",
          model: "gpt-4"
        ) { |_prompt| "Response" }
      end

      assert_match /Prompt 'nonexistent_prompt' not found/, error.message
    end

    test "should raise error if version not found" do
      error = assert_raises(LlmCallService::VersionNotFoundError) do
        LlmCallService.track(
          prompt_name: "test_greeting",
          version: 999,
          variables: @variables,
          provider: "openai",
          model: "gpt-4"
        ) { |_prompt| "Response" }
      end

      assert_match /version 999 not found/, error.message
    end

    test "should raise error if no active version exists" do
      @version.update!(status: "deprecated")

      error = assert_raises(LlmCallService::VersionNotFoundError) do
        LlmCallService.track(
          prompt_name: "test_greeting",
          variables: @variables,
          provider: "openai",
          model: "gpt-4"
        ) { |_prompt| "Response" }
      end

      assert_match /active version not found/, error.message
    end

    test "should raise error if no block given" do
      error = assert_raises(LlmCallService::NoBlockGivenError) do
        LlmCallService.track(
          prompt_name: "test_greeting",
          variables: @variables,
          provider: "openai",
          model: "gpt-4"
        )
      end

      assert_match /Block required/, error.message
    end

    test "should track error when LLM call fails" do
      error_raised = false

      begin
        LlmCallService.track(
          prompt_name: "test_greeting",
          variables: @variables,
          provider: "openai",
          model: "gpt-4"
        ) do |_prompt|
          raise StandardError, "API timeout"
        end
      end

      assert error_raised, "Error should have been raised"

      # Check that error was tracked
      llm_response = LlmResponse.last
      assert_equal "error", llm_response.status
      assert_equal "StandardError", llm_response.error_type
      assert_equal "API timeout", llm_response.error_message
      assert llm_response.response_time_ms.present?
    end

    # Context and Metadata Tests

    test "should store user context" do
      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "openai",
        model: "gpt-4",
        user_id: "user_123",
        session_id: "session_456",
        environment: "test"
      ) { |_prompt| "Response" }

      llm_response = result[:llm_response]
      assert_equal "user_123", llm_response.user_id
      assert_equal "session_456", llm_response.session_id
      assert_equal "test", llm_response.environment
    end

    test "should store custom metadata" do
      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "openai",
        model: "gpt-4",
        metadata: { ip_address: "192.168.1.1", user_agent: "Mozilla/5.0" }
      ) { |_prompt| "Response" }

      llm_response = result[:llm_response]
      assert_equal "192.168.1.1", llm_response.context["ip_address"]
      assert_equal "Mozilla/5.0", llm_response.context["user_agent"]
    end

    test "should use Rails.env as default environment" do
      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| "Response" }

      llm_response = result[:llm_response]
      assert_equal "test", llm_response.environment
    end

    # Variable Rendering Tests

    test "should render template with variables" do
      rendered = nil
      LlmCallService.track(
        prompt_name: "test_greeting",
        variables: { name: "Alice", service: "TestApp" },
        provider: "openai",
        model: "gpt-4"
      ) do |prompt|
        rendered = prompt
        "Response"
      end

      assert_equal "Hello Alice, welcome to TestApp!", rendered
    end

    test "should store variables_used in response" do
      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| "Response" }

      llm_response = result[:llm_response]
      assert_equal "John", llm_response.variables_used["name"]
      assert_equal "PromptTracker", llm_response.variables_used["service"]
    end

    # Cost Calculation Tests

    test "should calculate cost for tracked call" do
      openai_response = {
        "choices" => [{ "message" => { "content" => "Hi!" } }],
        "usage" => {
          "prompt_tokens" => 100,
          "completion_tokens" => 50,
          "total_tokens" => 150
        }
      }

      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| openai_response }

      llm_response = result[:llm_response]
      # (100/1000)*0.03 + (50/1000)*0.06 = 0.003 + 0.003 = 0.006
      assert_equal 0.006, llm_response.cost_usd
    end

    test "should handle missing token counts gracefully" do
      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "openai",
        model: "gpt-4"
      ) { |_prompt| "Simple string response" }

      llm_response = result[:llm_response]
      assert_nil llm_response.tokens_prompt
      assert_nil llm_response.tokens_completion
      assert_nil llm_response.cost_usd
    end

    # Response Time Tests

    test "should measure response time" do
      result = LlmCallService.track(
        prompt_name: "test_greeting",
        variables: @variables,
        provider: "openai",
        model: "gpt-4"
      ) do |_prompt|
        sleep 0.01  # Sleep for 10ms
        "Response"
      end

      llm_response = result[:llm_response]
      assert llm_response.response_time_ms >= 10
      assert llm_response.response_time_ms < 1000  # Should be less than 1 second
    end
  end
end
