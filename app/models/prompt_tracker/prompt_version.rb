# frozen_string_literal: true

module PromptTracker
  # Represents a specific version of a prompt template.
  #
  # PromptVersions are immutable once they have LLM responses. This ensures
  # historical accuracy and reproducibility of results.
  #
  # @example Creating a new version
  #   version = prompt.prompt_versions.create!(
  #     template: "Hello {{name}}, how can I help?",
  #     version_number: 1,
  #     status: "active",
  #     source: "file",
  #     variables_schema: [
  #       { "name" => "name", "type" => "string", "required" => true }
  #     ]
  #   )
  #
  # @example Rendering a template
  #   rendered = version.render(name: "John")
  #   # => "Hello John, how can I help?"
  #
  # @example Activating a version
  #   version.activate!
  #   # Marks this version as active and deprecates others
  #
  class PromptVersion < ApplicationRecord
    # Constants
    STATUSES = %w[active deprecated draft].freeze
    SOURCES = %w[file web_ui api].freeze

    # Associations
    belongs_to :prompt,
               class_name: "PromptTracker::Prompt",
               inverse_of: :prompt_versions

    has_many :llm_responses,
             class_name: "PromptTracker::LlmResponse",
             dependent: :restrict_with_error,
             inverse_of: :prompt_version

    has_many :evaluations,
             through: :llm_responses,
             class_name: "PromptTracker::Evaluation"

    # Validations
    validates :template, presence: true
    validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :source, presence: true, inclusion: { in: SOURCES }

    validates :version_number,
              uniqueness: { scope: :prompt_id, message: "already exists for this prompt" }

    validate :template_immutable_if_responses_exist, on: :update
    validate :variables_schema_must_be_array
    validate :model_config_must_be_hash

    # Callbacks
    before_validation :set_next_version_number, on: :create, if: -> { version_number.nil? }

    # Scopes

    # Returns only active versions
    # @return [ActiveRecord::Relation<PromptVersion>]
    scope :active, -> { where(status: "active") }

    # Returns only deprecated versions
    # @return [ActiveRecord::Relation<PromptVersion>]
    scope :deprecated, -> { where(status: "deprecated") }

    # Returns only draft versions
    # @return [ActiveRecord::Relation<PromptVersion>]
    scope :draft, -> { where(status: "draft") }

    # Returns only file-sourced versions
    # @return [ActiveRecord::Relation<PromptVersion>]
    scope :from_files, -> { where(source: "file") }

    # Returns only web UI-sourced versions
    # @return [ActiveRecord::Relation<PromptVersion>]
    scope :from_web_ui, -> { where(source: "web_ui") }

    # Returns versions ordered by version number (newest first)
    # @return [ActiveRecord::Relation<PromptVersion>]
    scope :by_version, -> { order(version_number: :desc) }

    # Instance Methods

    # Renders the template with the provided variables.
    #
    # Uses simple Mustache-style {{variable}} substitution.
    #
    # @param variables [Hash] the variables to substitute
    # @return [String] the rendered template
    # @raise [ArgumentError] if required variables are missing
    #
    # @example
    #   version.render(name: "John", issue: "billing")
    #   # => "Hello John, how can I help with billing?"
    def render(variables = {})
      variables = variables.with_indifferent_access
      validate_required_variables!(variables)

      rendered = template.dup
      variables.each do |key, value|
        rendered.gsub!("{{#{key}}}", value.to_s)
      end

      rendered
    end

    # Activates this version and deprecates all other versions of the same prompt.
    #
    # @return [Boolean] true if successful
    # @raise [ActiveRecord::RecordInvalid] if validation fails
    def activate!
      transaction do
        # Deprecate all other versions
        prompt.prompt_versions.where.not(id: id).update_all(status: "deprecated")

        # Activate this version
        update!(status: "active")
      end
      true
    end

    # Marks this version as deprecated.
    #
    # @return [Boolean] true if successful
    def deprecate!
      update!(status: "deprecated")
    end

    # Checks if this version is active.
    #
    # @return [Boolean] true if status is "active"
    def active?
      status == "active"
    end

    # Checks if this version is deprecated.
    #
    # @return [Boolean] true if status is "deprecated"
    def deprecated?
      status == "deprecated"
    end

    # Checks if this version is a draft.
    #
    # @return [Boolean] true if status is "draft"
    def draft?
      status == "draft"
    end

    # Returns a display name for this version.
    #
    # @return [String] formatted version name
    #
    # @example
    #   version.display_name  # => "v1 (active)"
    def display_name
      name = "v#{version_number}"
      name += " (#{status})" if status != "active"
      name
    end

    # Checks if this version came from a file.
    #
    # @return [Boolean] true if source is "file"
    def from_file?
      source == "file"
    end

    # Checks if this version has any LLM responses.
    #
    # @return [Boolean] true if responses exist
    def has_responses?
      llm_responses.exists?
    end

    # Returns the average response time for this version.
    #
    # @return [Float, nil] average response time in milliseconds
    def average_response_time_ms
      llm_responses.average(:response_time_ms)&.to_f
    end

    # Returns the total cost for this version.
    #
    # @return [Float] total cost in USD
    def total_cost_usd
      llm_responses.sum(:cost_usd) || 0.0
    end

    # Returns the total number of LLM calls for this version.
    #
    # @return [Integer] total count
    def total_llm_calls
      llm_responses.count
    end

    # Exports this version to YAML format.
    #
    # @return [Hash] YAML-compatible hash
    def to_yaml_export
      {
        "name" => prompt.name,
        "description" => prompt.description,
        "category" => prompt.category,
        "template" => template,
        "variables" => variables_schema,
        "model_config" => model_config,
        "notes" => notes
      }
    end

    private

    # Sets the next version number based on existing versions
    def set_next_version_number
      max_version = prompt.prompt_versions.maximum(:version_number) || 0
      self.version_number = max_version + 1
    end

    # Validates that required variables are provided
    def validate_required_variables!(variables)
      return if variables_schema.blank?

      required_vars = variables_schema.select { |v| v["required"] == true }.map { |v| v["name"] }
      missing_vars = required_vars - variables.keys.map(&:to_s)

      return if missing_vars.empty?

      raise ArgumentError, "Missing required variables: #{missing_vars.join(', ')}"
    end

    # Prevents template changes if responses exist
    def template_immutable_if_responses_exist
      return unless template_changed? && has_responses?

      errors.add(:template, "cannot be changed after responses exist")
    end

    # Validates that variables_schema is an array
    def variables_schema_must_be_array
      return if variables_schema.nil? || variables_schema.is_a?(Array)

      errors.add(:variables_schema, "must be an array")
    end

    # Validates that model_config is a hash
    def model_config_must_be_hash
      return if model_config.nil? || model_config.is_a?(Hash)

      errors.add(:model_config, "must be a hash")
    end
  end
end
