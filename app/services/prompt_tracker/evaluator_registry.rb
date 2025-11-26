# frozen_string_literal: true

module PromptTracker
  # Central registry for discovering and managing evaluators.
  #
  # The EvaluatorRegistry provides a single source of truth for all available
  # evaluators in the system. It allows:
  # - Discovering what evaluators are available
  # - Getting metadata about evaluators (name, description, config schema)
  # - Building evaluator instances
  # - Registering custom evaluators
  #
  # @example Getting all available evaluators
  #   EvaluatorRegistry.all
  #   # => {
  #   #   length: { name: "Length Validator", class: LengthEvaluator, ... },
  #   #   keyword: { name: "Keyword Checker", class: KeywordEvaluator, ... }
  #   # }
  #
  # @example Building an evaluator instance
  #   evaluator = EvaluatorRegistry.build(:length, llm_response, { min_length: 50 })
  #   result = evaluator.evaluate
  #
  # @example Registering a custom evaluator
  #   EvaluatorRegistry.register(
  #     key: :sentiment_check,
  #     name: "Sentiment Analyzer",
  #     description: "Analyzes response sentiment",
  #     evaluator_class: MySentimentEvaluator,
  #     category: :content,
  #     config_schema: {
  #       positive_keywords: { type: :array, default: [] },
  #       negative_keywords: { type: :array, default: [] }
  #     }
  #   )
  #
  class EvaluatorRegistry
    class << self
      # Returns all registered evaluators
      #
      # @return [Hash] hash of evaluator_key => metadata
      def all
        registry
      end

      # Returns evaluators in a specific category
      #
      # @param category [Symbol] the category (:format, :content, :quality, :custom)
      # @return [Hash] hash of evaluator_key => metadata
      def by_category(category)
        registry.select { |_key, metadata| metadata[:category] == category }
      end

      # Gets metadata for a specific evaluator
      #
      # @param key [Symbol, String] the evaluator key
      # @return [Hash, nil] evaluator metadata or nil if not found
      def get(key)
        registry[key.to_sym]
      end

      # Checks if an evaluator is registered
      #
      # @param key [Symbol, String] the evaluator key
      # @return [Boolean] true if evaluator exists
      def exists?(key)
        registry.key?(key.to_sym)
      end

      # Builds an instance of an evaluator
      #
      # @param key [Symbol, String] the evaluator key
      # @param llm_response [LlmResponse] the response to evaluate
      # @param config [Hash] configuration for the evaluator
      # @return [BaseEvaluator] an instance of the evaluator
      # @raise [ArgumentError] if evaluator not found
      def build(key, llm_response, config = {})
        metadata = get(key)
        raise ArgumentError, "Evaluator '#{key}' not found in registry" unless metadata

        evaluator_class = metadata[:evaluator_class]
        evaluator_class.new(llm_response, config)
      end

      # Registers a new evaluator
      #
      # @param key [Symbol] unique key for the evaluator
      # @param name [String] human-readable name
      # @param description [String] description of what it evaluates
      # @param evaluator_class [Class] the evaluator class
      # @param category [Symbol] category (:format, :content, :quality, :custom)
      # @param icon [String] Bootstrap icon name (without 'bi-' prefix)
      # @param config_schema [Hash] schema defining configuration options
      # @param default_config [Hash] default configuration values
      # @param form_template [String] path to the form partial for manual evaluation (optional)
      # @param evaluator_type [String] type of evaluator (human, automated, llm_judge)
      # @return [void]
      def register(key:, name:, description:, evaluator_class:, category: :custom, icon: nil, config_schema: {}, default_config: {}, form_template: nil, evaluator_type: 'automated')
        registry[key.to_sym] = {
          key: key.to_sym,
          name: name,
          description: description,
          evaluator_class: evaluator_class,
          category: category,
          icon: icon || 'gear',
          config_schema: config_schema,
          default_config: default_config,
          form_template: form_template,
          evaluator_type: evaluator_type
        }
      end

      # Unregisters an evaluator (useful for testing)
      #
      # @param key [Symbol, String] the evaluator key
      # @return [void]
      def unregister(key)
        registry.delete(key.to_sym)
      end

      # Resets the registry (useful for testing)
      #
      # @return [void]
      def reset!
        @registry = nil
        initialize_registry
      end

      private

      # Returns the registry hash (initializes if needed)
      #
      # @return [Hash] the registry
      def registry
        @registry ||= initialize_registry
      end

      # Initializes the registry with built-in evaluators
      #
      # @return [Hash] the initialized registry
      def initialize_registry
        @registry = {}

        # Register built-in evaluators
        register_human_evaluator
        register_length_evaluator
        register_keyword_evaluator
        register_format_evaluator
        register_pattern_match_evaluator
        register_exact_match_evaluator
        register_llm_judge_evaluator

        @registry
      end

      # Registers the human evaluator
      def register_human_evaluator
        register(
          key: :human,
          name: "Human Review",
          description: "Manual evaluation by a human reviewer",
          evaluator_class: Evaluators::BaseEvaluator, # Human doesn't use a specific evaluator class
          category: :quality,
          icon: "person-circle",
          evaluator_type: "human",
          form_template: "prompt_tracker/evaluators/forms/human",
          config_schema: {},
          default_config: {}
        )
      end

      # Registers the length evaluator
      def register_length_evaluator
        register(
          key: :length,
          name: "Length Validator",
          description: "Validates response length against min/max ranges",
          evaluator_class: Evaluators::LengthEvaluator,
          category: :format,
          icon: "rulers",
          config_schema: {
            min_length: { type: :integer, default: 10, description: "Minimum acceptable length" },
            max_length: { type: :integer, default: 2000, description: "Maximum acceptable length" }
          },
          default_config: {
            min_length: 10,
            max_length: 2000
          }
        )
      end

      # Registers the keyword evaluator
      def register_keyword_evaluator
        register(
          key: :keyword,
          name: "Keyword Checker",
          description: "Checks for required and forbidden keywords in the response",
          evaluator_class: Evaluators::KeywordEvaluator,
          category: :content,
          icon: "search",
          config_schema: {
            required_keywords: { type: :array, default: [], description: "Keywords that must be present" },
            forbidden_keywords: { type: :array, default: [], description: "Keywords that must not be present" },
            case_sensitive: { type: :boolean, default: false, description: "Whether matching is case-sensitive" }
          },
          default_config: {
            required_keywords: [],
            forbidden_keywords: [],
            case_sensitive: false
          }
        )
      end

      # Registers the format evaluator
      def register_format_evaluator
        register(
          key: :format,
          name: "Format Validator",
          description: "Validates response format (JSON, Markdown, etc.)",
          evaluator_class: Evaluators::FormatEvaluator,
          category: :format,
          icon: "file-code",
          config_schema: {
            expected_format: { type: :string, default: "json", description: "Expected format (json, markdown, plain)" },
            strict: { type: :boolean, default: false, description: "Whether to use strict validation" }
          },
          default_config: {
            expected_format: "json",
            strict: false
          }
        )
      end

      # Registers the pattern match evaluator
      def register_pattern_match_evaluator
        register(
          key: :pattern_match,
          name: "Pattern Match",
          description: "Checks if response matches regex patterns (typically used in binary mode)",
          evaluator_class: Evaluators::PatternMatchEvaluator,
          category: :content,
          icon: "regex",
          config_schema: {
            patterns: { type: :array, default: [], description: "Array of regex patterns (e.g., '/Hello/', '/world/i')" },
            match_all: { type: :boolean, default: true, description: "Whether all patterns must match (true) or any pattern (false)" }
          },
          default_config: {
            patterns: [],
            match_all: true
          }
        )
      end

      # Registers the exact match evaluator
      def register_exact_match_evaluator
        register(
          key: :exact_match,
          name: "Exact Match",
          description: "Checks if response exactly matches expected text (typically used in binary mode)",
          evaluator_class: Evaluators::ExactMatchEvaluator,
          category: :content,
          icon: "check-circle",
          config_schema: {
            expected_text: { type: :string, default: "", description: "The exact text to match" },
            case_sensitive: { type: :boolean, default: false, description: "Whether matching is case-sensitive" },
            trim_whitespace: { type: :boolean, default: true, description: "Whether to trim whitespace before comparing" }
          },
          default_config: {
            expected_text: "",
            case_sensitive: false,
            trim_whitespace: true
          }
        )
      end

      # Registers the LLM judge evaluator
      def register_llm_judge_evaluator
        register(
          key: :llm_judge,
          name: "LLM Judge",
          description: "Uses an LLM to evaluate response quality",
          evaluator_class: Evaluators::LlmJudgeEvaluator,
          category: :quality,
          icon: "robot",
          evaluator_type: "llm_judge",
          form_template: "prompt_tracker/evaluators/forms/llm_judge",
          config_schema: {
            judge_model: { type: :string, default: "gpt-4o", description: "LLM model to use as judge" },
            custom_instructions: { type: :string, default: "", description: "Instructions for the judge" },
            threshold_score: { type: :integer, default: 70, description: "Minimum score to pass (0-100)" },
            score_min: { type: :integer, default: 0, description: "Minimum score" },
            score_max: { type: :integer, default: 100, description: "Maximum score" }
          },
          default_config: {
            judge_model: "gpt-4o",
            custom_instructions: "",
            threshold_score: 70,
            score_min: 0,
            score_max: 100
          }
        )
      end
    end
  end
end
