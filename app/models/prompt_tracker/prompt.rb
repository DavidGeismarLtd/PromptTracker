# frozen_string_literal: true

module PromptTracker
  # Represents a prompt template container.
  #
  # A Prompt is a named container that groups all versions of a prompt template together.
  # Think of it like a Git repository - the Prompt is the repo, and PromptVersions are commits.
  #
  # @example Creating a new prompt
  #   prompt = Prompt.create!(
  #     name: "customer_support_greeting",
  #     description: "Initial greeting for customer support chats",
  #     category: "support",
  #     tags: ["customer-facing", "high-priority"],
  #     created_by: "john@example.com"
  #   )
  #
  # @example Finding a prompt by name
  #   prompt = Prompt.find_by!(name: "customer_support_greeting")
  #   active_version = prompt.active_version
  #
  # @example Getting all prompts in a category
  #   support_prompts = Prompt.in_category("support")
  #
  class Prompt < ApplicationRecord
    # Associations
    has_many :prompt_versions,
             class_name: "PromptTracker::PromptVersion",
             dependent: :destroy,
             inverse_of: :prompt

    has_many :ab_tests,
             class_name: "PromptTracker::AbTest",
             dependent: :destroy,
             inverse_of: :prompt

    has_many :llm_responses,
             through: :prompt_versions,
             class_name: "PromptTracker::LlmResponse"

    has_many :evaluations,
             through: :llm_responses,
             class_name: "PromptTracker::Evaluation"

    # Validations
    validates :name,
              presence: true,
              uniqueness: { case_sensitive: false },
              format: {
                with: /\A[a-z0-9_]+\z/,
                message: "must contain only lowercase letters, numbers, and underscores"
              }

    validates :category,
              format: {
                with: /\A[a-z0-9_]+\z/,
                message: "must contain only lowercase letters, numbers, and underscores"
              },
              allow_blank: true

    validate :tags_must_be_array

    # Scopes

    # Returns only active (non-archived) prompts
    # @return [ActiveRecord::Relation<Prompt>]
    scope :active, -> { where(archived_at: nil) }

    # Returns only archived prompts
    # @return [ActiveRecord::Relation<Prompt>]
    scope :archived, -> { where.not(archived_at: nil) }

    # Returns prompts in a specific category
    # @param category [String] the category name
    # @return [ActiveRecord::Relation<Prompt>]
    scope :in_category, ->(category) { where(category: category) }

    # Returns prompts with a specific tag
    # @param tag [String] the tag to search for
    # @return [ActiveRecord::Relation<Prompt>]
    scope :with_tag, lambda { |tag|
      where("tags @> ?", [tag].to_json)
    }

    # Instance Methods

    # Returns the currently active version of this prompt
    # @return [PromptVersion, nil] the active version or nil if none exists
    def active_version
      prompt_versions.active.first
    end

    # Returns the most recently created version (regardless of status)
    # @return [PromptVersion, nil] the latest version or nil if none exists
    def latest_version
      prompt_versions.order(created_at: :desc).first
    end

    # Archives this prompt (soft delete)
    # Also deprecates all versions
    # @return [Boolean] true if successful
    def archive!
      transaction do
        update!(archived_at: Time.current)
        prompt_versions.each(&:deprecate!)
      end
      true
    end

    # Unarchives this prompt
    # @return [Boolean] true if successful
    def unarchive!
      update!(archived_at: nil)
    end

    # Checks if this prompt is archived
    # @return [Boolean] true if archived
    def archived?
      archived_at.present?
    end

    # Returns total number of LLM calls across all versions
    # @return [Integer] total count of LLM responses
    def total_llm_calls
      llm_responses.count
    end

    # Returns total cost across all versions
    # @return [Float] total cost in USD
    def total_cost_usd
      llm_responses.sum(:cost_usd) || 0.0
    end

    # Returns average response time across all versions
    # @return [Float, nil] average response time in milliseconds
    def average_response_time_ms
      llm_responses.average(:response_time_ms)&.to_f
    end

    private

    # Validates that tags is an array
    def tags_must_be_array
      return if tags.nil? || tags.is_a?(Array)

      errors.add(:tags, "must be an array")
    end
  end
end
