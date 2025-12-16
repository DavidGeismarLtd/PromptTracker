class AddMissingColumnsToEvaluations < ActiveRecord::Migration[7.2]
  def change
    # Add evaluation_context column for enum
    add_column :prompt_tracker_evaluations, :evaluation_context, :string, default: "tracked_call"

    # Add evaluator_config_id to link evaluations to their config
    add_column :prompt_tracker_evaluations, :evaluator_config_id, :bigint

    # Add index for evaluator_config_id
    add_index :prompt_tracker_evaluations, :evaluator_config_id
  end
end
