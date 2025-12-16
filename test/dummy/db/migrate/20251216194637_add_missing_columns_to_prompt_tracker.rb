class AddMissingColumnsToPromptTracker < ActiveRecord::Migration[7.2]
  def up
    # Add polymorphic association columns to evaluator_configs
    # This allows evaluator configs to belong to either Prompt or PromptVersion
    add_column :prompt_tracker_evaluator_configs, :configurable_type, :string
    add_column :prompt_tracker_evaluator_configs, :configurable_id, :bigint

    # Migrate existing data: prompt_id -> configurable (Prompt)
    execute <<-SQL
      UPDATE prompt_tracker_evaluator_configs
      SET configurable_type = 'PromptTracker::Prompt',
          configurable_id = prompt_id
      WHERE prompt_id IS NOT NULL
    SQL

    # Make polymorphic columns NOT NULL
    change_column_null :prompt_tracker_evaluator_configs, :configurable_type, false
    change_column_null :prompt_tracker_evaluator_configs, :configurable_id, false

    # Add index for polymorphic association
    add_index :prompt_tracker_evaluator_configs, [ :configurable_type, :configurable_id ],
              name: "index_evaluator_configs_on_configurable"

    # Remove old prompt_id column and its indexes
    remove_index :prompt_tracker_evaluator_configs, :prompt_id if index_exists?(:prompt_tracker_evaluator_configs, :prompt_id)
    remove_index :prompt_tracker_evaluator_configs, [ :prompt_id, :evaluator_key ],
                 name: "index_evaluator_configs_on_prompt_and_key" if index_exists?(:prompt_tracker_evaluator_configs, [ :prompt_id, :evaluator_key ], name: "index_evaluator_configs_on_prompt_and_key")
    remove_index :prompt_tracker_evaluator_configs, [ :prompt_id, :priority ],
                 name: "index_evaluator_configs_on_prompt_and_priority" if index_exists?(:prompt_tracker_evaluator_configs, [ :prompt_id, :priority ], name: "index_evaluator_configs_on_prompt_and_priority")
    remove_column :prompt_tracker_evaluator_configs, :prompt_id

    # Add is_test_run column to llm_responses
    # This distinguishes between test runs and tracked production calls
    add_column :prompt_tracker_llm_responses, :is_test_run, :boolean, default: false, null: false

    # Add index for filtering tracked calls vs test runs
    add_index :prompt_tracker_llm_responses, :is_test_run
  end

  def down
    # Remove is_test_run column
    remove_index :prompt_tracker_llm_responses, :is_test_run
    remove_column :prompt_tracker_llm_responses, :is_test_run

    # Restore prompt_id column
    add_column :prompt_tracker_evaluator_configs, :prompt_id, :bigint

    # Migrate data back: configurable (Prompt) -> prompt_id
    execute <<-SQL
      UPDATE prompt_tracker_evaluator_configs
      SET prompt_id = configurable_id
      WHERE configurable_type = 'PromptTracker::Prompt'
    SQL

    # Restore old indexes
    add_index :prompt_tracker_evaluator_configs, :prompt_id
    add_index :prompt_tracker_evaluator_configs, [ :prompt_id, :evaluator_key ],
              unique: true, name: "index_evaluator_configs_on_prompt_and_key"
    add_index :prompt_tracker_evaluator_configs, [ :prompt_id, :priority ],
              name: "index_evaluator_configs_on_prompt_and_priority"

    # Remove polymorphic columns
    remove_index :prompt_tracker_evaluator_configs, name: "index_evaluator_configs_on_configurable"
    remove_column :prompt_tracker_evaluator_configs, :configurable_id
    remove_column :prompt_tracker_evaluator_configs, :configurable_type
  end
end
