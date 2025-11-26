# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_evaluator_configs
#
#  config            :jsonb            not null
#  configurable_id   :bigint           not null
#  configurable_type :string           not null
#  created_at        :datetime         not null
#  enabled           :boolean          default(TRUE), not null
#  evaluation_mode   :string           default("scored"), not null
#  evaluator_key     :string           not null
#  id                :bigint           not null, primary key
#  threshold         :integer
#  updated_at        :datetime         not null
#
module PromptTracker
  # Represents configuration for an evaluator that should run automatically for a prompt.
  #
  # EvaluatorConfigs define which evaluators run when a response is created,
  # along with their parameters and evaluation mode.
  #
  # @example Creating a basic evaluator config
  #   prompt.evaluator_configs.create!(
  #     evaluator_key: :length,
  #     enabled: true,
  #     config: { min_length: 50, max_length: 500 }
  #   )
  #
  # @example Creating a binary evaluator config
  #   prompt.evaluator_configs.create!(
  #     evaluator_key: :exact_match,
  #     enabled: true,
  #     evaluation_mode: "binary",
  #     config: { expected_output: "Hello, world!" }
  #   )
  #
  # @example Finding enabled configs for a prompt
  #   configs = prompt.evaluator_configs.enabled
  #   configs.each { |config| puts "#{config.evaluator_key}: #{config.evaluation_mode}" }
  #
  class EvaluatorConfig < ApplicationRecord
    # Associations
    belongs_to :configurable, polymorphic: true

    # Validations
    validates :evaluator_key,
              presence: true,
              uniqueness: { scope: [ :configurable_type, :configurable_id ] }

    validates :evaluation_mode,
              presence: true,
              inclusion: { in: %w[scored binary] }

    validates :threshold,
              numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
              allow_nil: true,
              if: :scored?

    # Scopes

    # Returns only enabled evaluator configs
    # @return [ActiveRecord::Relation<EvaluatorConfig>]
    scope :enabled, -> { where(enabled: true) }

    # Returns configs using scored evaluation mode
    # @return [ActiveRecord::Relation<EvaluatorConfig>]
    scope :scored, -> { where(evaluation_mode: "scored") }

    # Returns configs using binary evaluation mode
    # @return [ActiveRecord::Relation<EvaluatorConfig>]
    scope :binary, -> { where(evaluation_mode: "binary") }

    # Instance Methods

    # Returns metadata about this evaluator from the registry
    # @return [Hash, nil] evaluator metadata or nil if not found
    def evaluator_metadata
      EvaluatorRegistry.get(evaluator_key)
    end

    # Builds an instance of the evaluator for a specific response
    # @param llm_response [LlmResponse] the response to evaluate
    # @return [BaseEvaluator] an instance of the evaluator
    def build_evaluator(llm_response)
      EvaluatorRegistry.build(evaluator_key, llm_response, config)
    end

    # Checks if this config uses scored evaluation mode
    # @return [Boolean] true if evaluation_mode is "scored"
    def scored?
      evaluation_mode == "scored"
    end

    # Checks if this config uses binary evaluation mode
    # @return [Boolean] true if evaluation_mode is "binary"
    def binary?
      evaluation_mode == "binary"
    end

    # Returns a human-readable name for this evaluator
    # @return [String] evaluator name from metadata or key
    def name
      evaluator_metadata&.dig(:name) || evaluator_key.to_s.titleize
    end

    # Returns a description of this evaluator
    # @return [String, nil] evaluator description from metadata
    def description
      evaluator_metadata&.dig(:description)
    end
  end
end
