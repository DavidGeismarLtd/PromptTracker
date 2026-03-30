require "ruby_llm/schema"

module PromptTracker
  # Service for generating a system prompt from scratch based on a user
  # description. Uses a multi-step approach:
  # 1. Understand and expand the brief description
  # 2. Propose dynamic variables
  # 3. Generate a structured system prompt with those variables and an
  #    explanation of the design
  #
  # Configuration:
  # Uses the :prompt_generation context from PromptTracker.configuration.
  # Supports dynamic_configuration for multi-tenant applications.
  #
  # @example Configure in initializer
  #   config.contexts = {
  #     prompt_generation: {
  #       default_provider: :openai,
  #       default_model: "gpt-4o-mini",
  #       default_temperature: 0.7
  #     }
  #   }
  #
  class PromptGeneratorService
    FALLBACK_MODEL = "gpt-4o-mini"
    FALLBACK_TEMPERATURE = 0.7

    def self.generate(description:)
      new(description: description).generate
    end

    def initialize(description:)
      @description = description
    end

    def generate
      log_configuration
      expanded_requirements = understand_and_expand
      variables = propose_variables(expanded_requirements)
      generate_prompts(expanded_requirements, variables)
    end

    private

    attr_reader :description

    # Log the configuration being used for debugging
    def log_configuration
      config = PromptTracker.configuration
      configured_model = config.default_model_for(:prompt_generation)
      configured_temp = config.default_temperature_for(:prompt_generation)

      Rails.logger.info "[PromptTracker::PromptGeneratorService] Configuration loaded"
      Rails.logger.info "  - dynamic_configuration: #{config.dynamic_configuration?}"
      Rails.logger.info "  - configured model: #{configured_model.inspect}"
      Rails.logger.info "  - configured temperature: #{configured_temp.inspect}"
      Rails.logger.info "  - using model: #{model}"
      Rails.logger.info "  - using temperature: #{temperature}"

      if configured_model.nil?
        Rails.logger.warn "[PromptTracker::PromptGeneratorService] No model configured for :prompt_generation context, using fallback: #{FALLBACK_MODEL}"
      end

      if configured_temp.nil?
        Rails.logger.warn "[PromptTracker::PromptGeneratorService] No temperature configured for :prompt_generation context, using fallback: #{FALLBACK_TEMPERATURE}"
      end
    end

    # Get the model from configuration, respecting dynamic_configuration
    # @return [String] model ID
    def model
      PromptTracker.configuration.default_model_for(:prompt_generation) || FALLBACK_MODEL
    end

    # Get the temperature from configuration, respecting dynamic_configuration
    # @return [Float] temperature value
    def temperature
      PromptTracker.configuration.default_temperature_for(:prompt_generation) || FALLBACK_TEMPERATURE
    end

    def understand_and_expand
      prompt = <<~PROMPT
        You are an expert prompt engineer. A user has provided a brief description of what they want their prompt to do.

        User's description:
        #{description}

        Analyze this description and expand it into detailed requirements. Consider:
        - What is the main purpose and goal?
        - Who is the audience or user?
        - What tone and style would be appropriate?
        - What key capabilities or features are needed?
        - What constraints or guidelines should be followed?

        Provide a comprehensive expansion of the requirements in 2-3 paragraphs.
      PROMPT

      LlmClients::RubyLlmService.with_dynamic_config do |llm|
        chat = llm.chat(model: model).with_temperature(temperature)
        response = chat.ask(prompt)
        response.content
      end
    end

    def propose_variables(requirements)
      prompt = <<~PROMPT
        Based on these prompt requirements, identify dynamic variables that should be included.

        Requirements:
        #{requirements}

        Think about what information would need to change between different uses of this prompt.
        Examples: customer_name, issue_type, product_name, date, context, etc.

        List 3-5 variable names that would make this prompt flexible and reusable.
        Use snake_case for variable names.
        Return ONLY the variable names, one per line, nothing else.
      PROMPT

      LlmClients::RubyLlmService.with_dynamic_config do |llm|
        chat = llm.chat(model: model).with_temperature(temperature)
        response = chat.ask(prompt)

        # Parse variable names from response
        response.content.split("\n").map(&:strip).reject(&:empty?).map { |v| v.gsub(/^-\s*/, "") }
      end
    end

    def generate_prompts(requirements, variables)
      schema = build_generation_schema
      prompt = build_generation_prompt(requirements, variables)

      LlmClients::RubyLlmService.with_dynamic_config do |llm|
        chat = llm.chat(model: model)
          .with_temperature(temperature)
          .with_schema(schema)

          response = chat.ask(prompt)

          Rails.logger.debug "[PromptTracker::PromptGeneratorService] Generation response content keys: #{response.content.respond_to?(:keys) ? response.content.keys.inspect : 'n/a'}"

          # Response.content is a hash with the structured data
          parse_generation_response(response.content, variables)
      end
    end

    def build_generation_prompt(requirements, variables)
      variables_section = if variables.any?
        "Include these Liquid variables in the system prompt where appropriate: #{variables.map { |v| "{{ #{v} }}" }.join(', ')}"
      else
        "If helpful, include Liquid variables using {{ variable_name }} syntax in the system prompt."
      end

      <<~PROMPT
        You are an expert prompt engineer following industry best practices. Create an effective system prompt based on these requirements.

        Requirements:
        #{requirements}

        #{variables_section}

        IMPORTANT - Use structured sections in your system prompt (use the ones that are relevant):
        - #role - Define the AI persona, expertise, and capabilities
        - #goal - Specify the main objective or task
        - #context - Provide background information
        - #format - Specify output format and structure
        - #example - Show what good output looks like
        - #audience - Describe who will read the output
        - #tone and style - Suggest appropriate tone
        - #what to prioritise - Highlight key aspects to focus on
        - #out of scope - Define limits and boundaries
        - #resources - Mention any resources that could be used

        Guidelines:
        - Focus only on the system prompt; do NOT generate a separate user prompt.
        - Include Liquid variables using {{ variable_name }} syntax where dynamic content is needed.
        - Make the prompt clear, specific, and well-structured.
        - Each section should start on a new line with the # prefix.

        Alongside the system prompt, provide a brief explanation of your design decisions.
      PROMPT
    end

    def build_generation_schema
      Class.new(RubyLLM::Schema) do
        string :system_prompt, description: "The system prompt that defines the AI's role and behavior"
        string :explanation, description: "Brief explanation of the prompt design and how to use it"
      end
    end

      def parse_generation_response(content, variables)
        data = content.respond_to?(:with_indifferent_access) ? content.with_indifferent_access : content

        system_prompt = data[:system_prompt]
        explanation = data[:explanation]

        Rails.logger.info "[PromptTracker::PromptGeneratorService] Parsed system_prompt length: #{system_prompt.to_s.length} characters"

        {
          system_prompt: system_prompt,
          variables: variables,
          explanation: explanation.presence || "Prompt generated successfully"
        }
      end
  end
end
