require "ruby_llm/schema"

module PromptTracker
  # Service for generating OpenAI Assistant instructions from a natural language description.
  # Uses a two-step approach:
  # 1. Understand and expand the brief description
  # 2. Generate instructions, name, and description
  class AssistantInstructionsGeneratorService
    DEFAULT_MODEL = ENV.fetch("PROMPT_GENERATOR_MODEL", "gpt-4o-mini")
    DEFAULT_TEMPERATURE = 0.7

    def self.generate(description:)
      new(description: description).generate
    end

    def initialize(description:)
      @description = description
    end

    def generate
      expanded_requirements = understand_and_expand
      generate_assistant_config(expanded_requirements)
    end

    private

    attr_reader :description

    def understand_and_expand
      prompt = <<~PROMPT
        You are an expert at designing OpenAI Assistants. A user has provided a brief description of what they want their assistant to do.

        User's description:
        #{description}

        Analyze this description and expand it into detailed requirements. Consider:
        - What is the main purpose and goal of this assistant?
        - Who is the target audience?
        - What tone and personality should the assistant have?
        - What key capabilities or knowledge are needed?
        - What constraints or guidelines should be followed?
        - What makes this assistant different or specialized?

        Provide a comprehensive expansion of the requirements in 2-3 paragraphs.
      PROMPT

      chat = RubyLLM.chat(model: DEFAULT_MODEL).with_temperature(DEFAULT_TEMPERATURE)
      response = chat.ask(prompt)
      response.content
    end

    def generate_assistant_config(requirements)
      schema = build_generation_schema
      prompt = build_generation_prompt(requirements)

      chat = RubyLLM.chat(model: DEFAULT_MODEL)
        .with_temperature(DEFAULT_TEMPERATURE)
        .with_schema(schema)

      response = chat.ask(prompt)
      parse_generation_response(response.content)
    end

    def build_generation_prompt(requirements)
      <<~PROMPT
        You are an expert at designing OpenAI Assistants. Create a complete assistant configuration based on these requirements.

        Requirements:
        #{requirements}

        Guidelines for instructions:
        - Write clear, comprehensive system instructions that define the assistant's behavior
        - Use sections like #role, #goal, #tone, #guidelines, #boundaries to structure the instructions
        - Be specific about what the assistant should and shouldn't do
        - Include examples of expected behavior if helpful
        - Keep instructions focused and actionable (aim for 500-2000 characters)

        Guidelines for name:
        - Create a concise, descriptive name (2-4 words)
        - Make it memorable and professional

        Guidelines for description:
        - Write a brief description (1-2 sentences)
        - Explain what the assistant does and who it's for

        Generate the complete assistant configuration now.
      PROMPT
    end

    def build_generation_schema
      Class.new(RubyLLM::Schema) do
        string :instructions, description: "The system instructions that define the assistant's behavior and capabilities"
        string :name, description: "A concise, descriptive name for the assistant (2-4 words)"
        string :description, description: "A brief description of what the assistant does (1-2 sentences)"
        string :explanation, description: "Brief explanation of the design choices and how to use the assistant"
      end
    end

    def parse_generation_response(content)
      content = content.with_indifferent_access if content.respond_to?(:with_indifferent_access)

      {
        instructions: content[:instructions] || content["instructions"] || "",
        name: content[:name] || content["name"] || "",
        description: content[:description] || content["description"] || "",
        explanation: content[:explanation] || content["explanation"] || "Assistant configuration generated successfully"
      }
    end
  end
end
