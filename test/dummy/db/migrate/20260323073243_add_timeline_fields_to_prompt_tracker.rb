class AddTimelineFieldsToPromptTracker < ActiveRecord::Migration[7.2]
  def change
    # Add tool_calls to llm_responses to store LLM's intent to call tools
    add_column :prompt_tracker_llm_responses, :tool_calls, :jsonb, default: []

    # Add planning_step_id to function_executions to link executions to planning steps
    add_column :prompt_tracker_function_executions, :planning_step_id, :string
    add_index :prompt_tracker_function_executions, :planning_step_id
  end
end
