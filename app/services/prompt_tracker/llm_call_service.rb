# frozen_string_literal: true

module PromptTracker
  # Main service for tracking LLM API calls.
  #
  # This service orchestrates the entire tracking flow:
  # 1. Find prompt and version (with A/B test support)
  # 2. Render template with variables
  # 3. Create LlmResponse record (status: pending, with A/B test tracking)
  # 4. Execute LLM call (via block)
  # 5. Measure performance
  # 6. Extract response data
  # 7. Calculate cost
  # 8. Update LlmResponse record (status: success/error)
  #
  # A/B Testing:
  # When no specific version is requested, the service automatically checks
  # for running A/B tests and selects a variant based on traffic split.
  # The A/B test and variant are transparently tracked in the LlmResponse.
  #
  # @example Basic usage
  #   result = LlmCallService.track(
  #     prompt_name: "customer_support_greeting",
  #     variables: { customer_name: "John", issue_category: "billing" },
  #     provider: "openai",
  #     model: "gpt-4"
  #   ) do |rendered_prompt|
  #     OpenAI::Client.new.chat(
  #       messages: [{ role: "user", content: rendered_prompt }],
  #       model: "gpt-4"
  #     )
  #   end
  #
  #   result[:response_text]  # => "Hello John! I can help with billing..."
  #   result[:llm_response]   # => <LlmResponse record>
  #   result[:tracking_id]    # => "uuid"
  #
  # @example With specific version
  #   result = LlmCallService.track(
  #     prompt_name: "greeting",
  #     version: 2,  # Use version 2 instead of active
  #     variables: { name: "Alice" },
  #     provider: "anthropic",
  #     model: "claude-3-opus"
  #   ) { |prompt| AnthropicClient.chat(prompt) }
  #
  # @example With user context
  #   result = LlmCallService.track(
  #     prompt_name: "greeting",
  #     variables: { name: "Bob" },
  #     provider: "openai",
  #     model: "gpt-4",
  #     user_id: current_user.id,
  #     session_id: session.id,
  #     environment: Rails.env,
  #     metadata: { ip_address: request.ip }
  #   ) { |prompt| call_llm(prompt) }
  #
  class LlmCallService
    # Custom error classes
    class PromptNotFoundError < StandardError; end
    class VersionNotFoundError < StandardError; end
    class NoBlockGivenError < StandardError; end

    attr_reader :prompt_name, :version_number, :variables, :provider, :model,
                :user_id, :session_id, :environment, :metadata, :ab_test, :ab_variant

    # Track an LLM call
    #
    # @param prompt_name [String] name of the prompt to use
    # @param variables [Hash] variables to render in the template
    # @param provider [String] LLM provider (e.g., "openai", "anthropic")
    # @param model [String] model name (e.g., "gpt-4", "claude-3-opus")
    # @param version [Integer, nil] specific version number (defaults to active version)
    # @param user_id [String, nil] user identifier for context
    # @param session_id [String, nil] session identifier for context
    # @param environment [String, nil] environment (defaults to Rails.env)
    # @param metadata [Hash, nil] additional metadata to store
    # @yield [rendered_prompt] block that executes the LLM call
    # @yieldparam rendered_prompt [String] the rendered prompt template
    # @yieldreturn [Object] the LLM response object
    # @return [Hash] result hash with :llm_response, :response_text, :tracking_id
    # @raise [PromptNotFoundError] if prompt not found
    # @raise [VersionNotFoundError] if version not found
    # @raise [NoBlockGivenError] if no block provided
    def self.track(prompt_name:, variables: {}, provider:, model:, version: nil,
                   user_id: nil, session_id: nil, environment: nil, metadata: nil, &block)
      new(
        prompt_name: prompt_name,
        variables: variables,
        provider: provider,
        model: model,
        version: version,
        user_id: user_id,
        session_id: session_id,
        environment: environment,
        metadata: metadata
      ).track(&block)
    end

    # Initialize a new LLM call tracker
    #
    # @param prompt_name [String] name of the prompt
    # @param variables [Hash] variables for template rendering
    # @param provider [String] LLM provider
    # @param model [String] model name
    # @param version [Integer, nil] specific version number
    # @param user_id [String, nil] user identifier
    # @param session_id [String, nil] session identifier
    # @param environment [String, nil] environment
    # @param metadata [Hash, nil] additional metadata
    def initialize(prompt_name:, variables: {}, provider:, model:, version: nil,
                   user_id: nil, session_id: nil, environment: nil, metadata: nil)
      @prompt_name = prompt_name
      @version_number = version
      @variables = variables || {}
      @provider = provider
      @model = model
      @user_id = user_id
      @session_id = session_id
      @environment = environment || default_environment
      @metadata = metadata || {}
      @ab_test = nil
      @ab_variant = nil
    end

    # Execute the tracking flow
    #
    # @yield [rendered_prompt] block that executes the LLM call
    # @yieldparam rendered_prompt [String] the rendered prompt template
    # @yieldreturn [Object] the LLM response object
    # @return [Hash] result hash with :llm_response, :response_text, :tracking_id
    # @raise [NoBlockGivenError] if no block provided
    def track
      raise NoBlockGivenError, "Block required to execute LLM call" unless block_given?

      # Step 1: Find prompt and version
      prompt = find_prompt
      prompt_version = find_version(prompt)

      # Step 2: Render template
      rendered_prompt = render_template(prompt_version)

      # Step 3: Create pending LlmResponse record
      llm_response = create_pending_response(prompt_version, rendered_prompt)

      # Step 4: Execute LLM call with timing
      start_time = Time.current
      begin
        llm_result = yield(rendered_prompt)
        response_time_ms = ((Time.current - start_time) * 1000).round

        # Step 5: Extract response data
        extracted = extract_response_data(llm_result)

        # Step 6: Calculate cost
        cost = calculate_cost(extracted[:tokens_prompt], extracted[:tokens_completion])

        # Step 7: Update LlmResponse with success
        llm_response.mark_success!(
          response_text: extracted[:text],
          response_time_ms: response_time_ms,
          tokens_prompt: extracted[:tokens_prompt],
          tokens_completion: extracted[:tokens_completion],
          tokens_total: extracted[:tokens_total],
          cost_usd: cost,
          response_metadata: extracted[:metadata]
        )

        # Step 8: Return result
        {
          llm_response: llm_response,
          response_text: extracted[:text],
          tracking_id: llm_response.id
        }
      rescue StandardError => e
        # Handle errors gracefully
        response_time_ms = ((Time.current - start_time) * 1000).round
        handle_error(llm_response, e, response_time_ms)
        raise
      end
    end

    private

    # Find the prompt by name
    #
    # @return [Prompt] the prompt
    # @raise [PromptNotFoundError] if not found
    def find_prompt
      prompt = Prompt.find_by(name: prompt_name)
      raise PromptNotFoundError, "Prompt '#{prompt_name}' not found" if prompt.nil?

      prompt
    end

    # Find the version (specific or active)
    #
    # If a specific version is requested, use that.
    # Otherwise, check for A/B test and select variant, or use active version.
    #
    # @param prompt [Prompt] the prompt
    # @return [PromptVersion] the version
    # @raise [VersionNotFoundError] if not found
    def find_version(prompt)
      # If specific version requested, use it (no A/B testing)
      if version_number
        version = prompt.prompt_versions.find_by(version_number: version_number)
        if version.nil?
          raise VersionNotFoundError, "version #{version_number} not found for prompt '#{prompt_name}'"
        end
        return version
      end

      # No specific version - check for A/B test
      selection = AbTestCoordinator.select_version_for(prompt)

      if selection.nil?
        raise VersionNotFoundError, "active version not found for prompt '#{prompt_name}'"
      end

      # Store A/B test info for later use
      @ab_test = selection[:ab_test]
      @ab_variant = selection[:variant]

      version = selection[:version]
      if version.nil?
        raise VersionNotFoundError, "active version not found for prompt '#{prompt_name}'"
      end

      version
    end

    # Render the template with variables
    #
    # @param prompt_version [PromptVersion] the version
    # @return [String] rendered template
    def render_template(prompt_version)
      prompt_version.render(variables)
    end

    # Create a pending LlmResponse record
    #
    # @param prompt_version [PromptVersion] the version
    # @param rendered_prompt [String] the rendered template
    # @return [LlmResponse] the created record
    def create_pending_response(prompt_version, rendered_prompt)
      prompt_version.llm_responses.create!(
        rendered_prompt: rendered_prompt,
        variables_used: variables,
        provider: provider,
        model: model,
        status: "pending",
        user_id: user_id,
        session_id: session_id,
        environment: environment,
        context: metadata,
        ab_test: ab_test,
        ab_variant: ab_variant
      )
    end

    # Extract response data using ResponseExtractor
    #
    # @param llm_result [Object] the LLM response
    # @return [Hash] extracted data
    def extract_response_data(llm_result)
      ResponseExtractor.new(llm_result).extract_all
    end

    # Calculate cost using CostCalculator
    #
    # @param tokens_prompt [Integer, nil] prompt tokens
    # @param tokens_completion [Integer, nil] completion tokens
    # @return [Float, nil] cost in USD
    def calculate_cost(tokens_prompt, tokens_completion)
      return nil if tokens_prompt.nil? && tokens_completion.nil?

      CostCalculator.calculate(
        provider: provider,
        model: model,
        tokens_prompt: tokens_prompt || 0,
        tokens_completion: tokens_completion || 0
      )
    end

    # Handle errors by updating the LlmResponse record
    #
    # @param llm_response [LlmResponse] the response record
    # @param error [StandardError] the error
    # @param response_time_ms [Integer] time elapsed
    def handle_error(llm_response, error, response_time_ms)
      llm_response.mark_error!(
        error_type: error.class.name,
        error_message: error.message,
        response_time_ms: response_time_ms
      )
    end

    # Get default environment
    #
    # @return [String] environment name
    def default_environment
      if defined?(Rails) && Rails.respond_to?(:env)
        Rails.env.to_s
      else
        "unknown"
      end
    end
  end
end
