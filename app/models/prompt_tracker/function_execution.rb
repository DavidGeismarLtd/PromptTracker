# frozen_string_literal: true

# == Schema Information
#
# Table name: prompt_tracker_function_executions
#
#  arguments              :jsonb            not null
#  created_at             :datetime         not null
#  error_message          :text
#  executed_at            :datetime         not null
#  execution_time_ms      :integer
#  function_definition_id :bigint           not null
#  id                     :bigint           not null, primary key
#  result                 :jsonb
#  success                :boolean          default(TRUE), not null
#  updated_at             :datetime         not null
#
module PromptTracker
  # Tracks individual function executions for analytics and debugging.
  #
  # FunctionExecutions record every time a function is executed, including:
  # - Input arguments
  # - Output result
  # - Success/failure status
  # - Error messages
  # - Execution time
  #
  # This data is used for:
  # - Performance monitoring
  # - Debugging failed executions
  # - Usage analytics
  # - Cost tracking
  #
  # @example Creating an execution record
  #   execution = FunctionExecution.create!(
  #     function_definition: function,
  #     arguments: { city: "Berlin", units: "celsius" },
  #     result: { temperature: 15, conditions: "cloudy" },
  #     success: true,
  #     execution_time_ms: 234,
  #     executed_at: Time.current
  #   )
  #
  # @example Finding failed executions
  #   failed = FunctionExecution.failed.recent
  #   failed.each { |exec| puts exec.error_message }
  #
  class FunctionExecution < ApplicationRecord
    # Associations
    belongs_to :function_definition,
               class_name: "PromptTracker::FunctionDefinition",
               optional: true,  # Optional for virtual/planning functions
               inverse_of: :function_executions

    belongs_to :deployed_agent,
               class_name: "PromptTracker::DeployedAgent",
               optional: true,
               inverse_of: :function_executions

    belongs_to :agent_conversation,
               class_name: "PromptTracker::AgentConversation",
               optional: true,
               inverse_of: :function_executions

    belongs_to :task_run,
               class_name: "PromptTracker::TaskRun",
               optional: true,
               inverse_of: :function_executions

    # Validations
    # Note: arguments can be an empty hash {} for functions with no parameters
    # We only validate that it's not nil (which is handled by the database default)
    validates :executed_at, presence: true
    validates :success, inclusion: { in: [ true, false ] }

    validate :arguments_must_be_hash
    validate :result_must_be_serializable

    # Scopes
    scope :successful, -> { where(success: true) }
    scope :failed, -> { where(success: false) }
    scope :recent, -> { where("executed_at > ?", 24.hours.ago).order(executed_at: :desc) }
    scope :slow, ->(threshold_ms = 1000) { where("execution_time_ms > ?", threshold_ms) }
    scope :for_function, ->(function_id) { where(function_definition_id: function_id) }

    # Returns the success rate as a percentage
    #
    # @return [Float] success rate (0-100)
    def self.success_rate
      return 0.0 if count.zero?

      (successful.count.to_f / count * 100).round(2)
    end

    # Returns the average execution time in milliseconds
    #
    # @return [Float] average execution time
    def self.average_execution_time
      return 0.0 if count.zero?

      average(:execution_time_ms).to_f.round(2)
    end

    # Get the function name for display
    # For regular functions, use the function_definition name
    # For planning functions (no function_definition), infer from result
    #
    # @return [String] function name
    def display_name
      return function_definition.name if function_definition.present?

      # For planning functions, try to infer from result
      # Planning functions typically return { success: true, plan: {...} } or similar
      if result.is_a?(Hash)
        # Check if result has a "plan" key (create_plan, get_plan)
        return "create_plan" if result.key?("plan") && result["plan"].is_a?(Hash) && result["plan"].key?("goal")
        return "get_plan" if result.key?("plan") && result["plan"].is_a?(Hash)
        # Check if result has a "step_id" key (update_step)
        return "update_step" if result.key?("step_id")
        # Check if result has a "summary" key (mark_task_complete)
        return "mark_task_complete" if result.key?("summary")
      end

      # Fallback
      "planning_function"
    end

    private

    def arguments_must_be_hash
      # Arguments cannot be nil (database has NOT NULL constraint with default {})
      # But it can be an empty hash {} for functions with no parameters
      if arguments.nil?
        errors.add(:arguments, "cannot be nil")
        return
      end

      unless arguments.is_a?(Hash)
        errors.add(:arguments, "must be a Hash")
      end
    end

    def result_must_be_serializable
      return if result.blank?

      # Ensure result can be serialized to JSON
      result.to_json
    rescue StandardError => e
      errors.add(:result, "must be JSON-serializable: #{e.message}")
    end
  end
end
