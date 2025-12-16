# frozen_string_literal: true

module PromptTracker
  # Convenience module for tracking LLM calls in controllers and services.
  #
  # This module provides a simple `track_llm_call` method that wraps
  # LlmCallService.track with a cleaner syntax.
  #
  # The block you provide should return either:
  # - A String (just the response text) - simplest option
  # - A Hash with :text (required), :tokens_prompt, :tokens_completion, :metadata (optional)
  #
  # Provider and model are optional - they default to the prompt version's model_config.
  # You can override them for testing or experimentation.
  #
  # @example Include in a controller (simplest - return string)
  #   class CustomerSupportController < ApplicationController
  #     include PromptTracker::Trackable
  #
  #     def generate_greeting
  #       result = track_llm_call(
  #         "customer_support_greeting",
  #         variables: { customer_name: params[:name] },
  #         user_id: current_user.id
  #       ) do |prompt|
  #         # Just return the text - provider/model from version's model_config
  #         "Hello #{params[:name]}! How can I help you today?"
  #       end
  #
  #       render json: { greeting: result[:response_text] }
  #     end
  #   end
  #
  # @example With structured response (includes token counts)
  #   class EmailGeneratorService
  #     include PromptTracker::Trackable
  #
  #     def generate_email(recipient_name, topic)
  #       result = track_llm_call(
  #         "email_generator",
  #         variables: { recipient_name: recipient_name, topic: topic }
  #       ) do |prompt|
  #         response = OpenAI::Client.new.chat(
  #           messages: [{ role: "user", content: prompt }]
  #         )
  #         # Return structured hash
  #         {
  #           text: response.dig("choices", 0, "message", "content"),
  #           tokens_prompt: response.dig("usage", "prompt_tokens"),
  #           tokens_completion: response.dig("usage", "completion_tokens")
  #         }
  #       end
  #
  #       result[:response_text]
  #     end
  #   end
  #
  # @example Override provider/model (for testing)
  #   result = track_llm_call(
  #     "greeting",
  #     variables: { name: "Alice" },
  #     provider: "anthropic",  # Override version's config
  #     model: "claude-3-opus"
  #   ) { |prompt| "Hello Alice!" }
  #
  module Trackable
    # Track an LLM call with simplified syntax
    #
    # @param prompt_slug [String] slug of the prompt to use
    # @param variables [Hash] variables to render in the template (default: {})
<<<<<<< HEAD
    # @param provider [String, nil] LLM provider (e.g., "openai", "anthropic") - defaults to version's model_config
    # @param model [String, nil] model name (e.g., "gpt-4", "claude-3-opus") - defaults to version's model_config
=======
    # @param provider [String, nil] LLM provider (e.g., "openai", "anthropic") - defaults to prompt version's model_config
    # @param model [String, nil] model name (e.g., "gpt-4", "claude-3-opus") - defaults to prompt version's model_config
>>>>>>> 9f13033 (WIP)
    # @param version [Integer, nil] specific version number (default: nil, uses active)
    # @param user_id [String, nil] user identifier for context (default: nil)
    # @param session_id [String, nil] session identifier for context (default: nil)
    # @param environment [String, nil] environment (default: Rails.env)
    # @param metadata [Hash, nil] additional metadata to store (default: nil)
    # @param trace [Trace, nil] trace to link this LLM call to (default: nil)
    # @param span [Span, nil] span to link this LLM call to (default: nil)
    # @yield [rendered_prompt] block that executes the LLM call
    # @yieldparam rendered_prompt [String] the rendered prompt template
    # @yieldreturn [String, Hash] LLM response - String (just text) or Hash with :text, :tokens_prompt, :tokens_completion, :metadata
    # @return [Hash] result hash with :llm_response, :response_text, :tracking_id
    # @raise [LlmCallService::PromptNotFoundError] if prompt not found
    # @raise [LlmCallService::VersionNotFoundError] if version not found
    # @raise [LlmCallService::NoBlockGivenError] if no block provided
    # @raise [ArgumentError] if provider/model not specified and not in version's model_config
    # @raise [LlmResponseContract::InvalidResponseError] if block returns invalid response format
    #
<<<<<<< HEAD
    # @example Basic usage (provider/model from version's model_config)
    #   result = track_llm_call(
    #     "commercial_agent",
    #     variables: { product_description: "Amazon Echo", message: "Can I order on amazon with this?" }
    #   ) do |prompt|
    #     # Just return the text string (simplest)
    #     "Yes, you can order the Amazon Echo on Amazon!"
    #   end
    #
    # @example With structured response (includes token counts)
=======
    # @example Basic usage with explicit provider/model
>>>>>>> 9f13033 (WIP)
    #   result = track_llm_call(
    #     "greeting",
    #     variables: { name: "Alice" }
    #   ) do |prompt|
    #     response = OpenAI::Client.new.chat(
    #       messages: [{ role: "user", content: prompt }]
    #     )
    #     # Return hash with token counts
    #     {
    #       text: response.dig("choices", 0, "message", "content"),
    #       tokens_prompt: response.dig("usage", "prompt_tokens"),
    #       tokens_completion: response.dig("usage", "completion_tokens")
    #     }
    #   end
    #
<<<<<<< HEAD
    # @example Override provider/model (for testing different models)
    #   result = track_llm_call(
    #     "greeting",
    #     variables: { name: "Bob" },
    #     provider: "anthropic",  # Override version's config
    #     model: "claude-3-opus",
    #     user_id: current_user.id,
    #     session_id: session.id
    #   ) { |prompt| "Hello Bob!" }
    #
    # @example Using LlmClientService (handles response format automatically)
    #   result = track_llm_call(
    #     "customer_success",
    #     variables: { product_description: "Amazon Echo", message: "Can I order on amazon with this?" }
    #   ) do |prompt|
    #     PromptTracker::LlmClientService.call(
    #       provider: "openai",
    #       model: "gpt-4",
    #       prompt: prompt,
    #       temperature: 0.7
    #     )  # Returns hash in correct format
    #   end
    def track_llm_call(prompt_slug, variables: {}, provider: nil, model: nil, version: nil,
                       user_id: nil, session_id: nil, environment: nil, metadata: nil, &block)
=======
    # @example Using defaults from prompt version's model_config
    #   result = track_llm_call(
    #     "greeting",
    #     variables: { name: "Alice" }
    #   ) { |prompt| call_llm(prompt) }
    #
    # @example With tracing
    #   with_trace("greeting_workflow", session_id: "chat_123") do |trace|
    #     track_llm_call(
    #       "greeting",
    #       variables: { name: "Bob" },
    #       trace: trace
    #     ) { |prompt| call_llm(prompt) }
    #   end
    #
    def track_llm_call(prompt_name, variables: {}, provider: nil, model: nil, version: nil,
                       user_id: nil, session_id: nil, environment: nil, metadata: nil,
                       trace: nil, span: nil, &block)
>>>>>>> 9f13033 (WIP)
      LlmCallService.track(
        prompt_slug: prompt_slug,
        variables: variables,
        provider: provider,
        model: model,
        version: version,
        user_id: user_id,
        session_id: session_id,
        environment: environment,
        metadata: metadata,
        trace: trace,
        span: span,
        &block
      )
    end

    # Execute a block within a trace context with automatic lifecycle management.
    #
    # Creates a trace, executes the block, and automatically completes or marks
    # the trace as error based on the block's execution.
    #
    # @param name [String] name of the trace
    # @param session_id [String, nil] session identifier
    # @param user_id [String, nil] user identifier
    # @param input [String, nil] input description
    # @param metadata [Hash] additional metadata
    # @yield [trace] block to execute within the trace context
    # @yieldparam trace [Trace] the created trace
    # @yieldreturn [Object] the result of the block (captured as trace output)
    # @return [Object] the result of the block
    #
    # @example Simple trace
    #   result = with_trace("greeting_workflow", session_id: "chat_123") do |trace|
    #     # Your code here
    #     "Hello!"
    #   end
    #
    # @example With LLM call
    #   with_trace("rag_qa", session_id: "chat_123", input: "What is Rails?") do |trace|
    #     track_llm_call("answer", variables: { q: "Rails" }, trace: trace) { |p| call_llm(p) }
    #   end
    #
    def with_trace(name, session_id: nil, user_id: nil, input: nil, metadata: {})
      trace = PromptTracker::Trace.create!(
        name: name,
        session_id: session_id,
        user_id: user_id,
        input: input,
        started_at: Time.current,
        status: "running",
        metadata: metadata
      )

      result = yield(trace)

      trace.complete!(output: result.is_a?(String) ? result : result.to_s)
      result
    rescue => e
      trace&.mark_error!(error_message: e.message)
      raise
    end

    # Execute a block within a span context with automatic lifecycle management.
    #
    # Creates a span under a trace, executes the block, and automatically completes
    # or marks the span as error based on the block's execution.
    #
    # @param trace [Trace] the parent trace
    # @param name [String] name of the span
    # @param type [String, Symbol, nil] span type (function, tool, retrieval, database, http)
    # @param input [String, nil] input description
    # @param metadata [Hash] additional metadata
    # @yield [span] block to execute within the span context
    # @yieldparam span [Span] the created span
    # @yieldreturn [Object] the result of the block (captured as span output)
    # @return [Object] the result of the block
    #
    # @example Simple span
    #   with_trace("workflow") do |trace|
    #     result = with_span(trace, "search", type: :retrieval) do |span|
    #       # Your search code
    #       search_results
    #     end
    #   end
    #
    # @example Span with LLM call
    #   with_trace("rag_qa") do |trace|
    #     docs = with_span(trace, "search", type: :retrieval) do
    #       VectorStore.search(query)
    #     end
    #
    #     with_span(trace, "generate", type: :function) do |span|
    #       track_llm_call("answer", variables: { docs: docs }, trace: trace, span: span) { |p| call_llm(p) }
    #     end
    #   end
    #
    def with_span(trace, name, type: nil, input: nil, metadata: {})
      span = trace.spans.create!(
        name: name,
        span_type: type&.to_s,
        input: input,
        started_at: Time.current,
        status: "running",
        metadata: metadata
      )

      result = yield(span)

      span.complete!(output: result.is_a?(String) ? result : result.to_s)
      result
    rescue => e
      span&.mark_error!(error_message: e.message)
      raise
    end
  end
end
