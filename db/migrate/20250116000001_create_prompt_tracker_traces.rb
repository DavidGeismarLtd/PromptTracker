# frozen_string_literal: true

class CreatePromptTrackerTraces < ActiveRecord::Migration[7.2]
  def change
    create_table :prompt_tracker_traces do |t|
      t.string :name, null: false
      t.text :input
      t.text :output
      t.string :status, null: false, default: "running"
      t.string :session_id
      t.string :user_id
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_ms
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :prompt_tracker_traces, :session_id
    add_index :prompt_tracker_traces, :user_id
    add_index :prompt_tracker_traces, [ :status, :created_at ]
    add_index :prompt_tracker_traces, :started_at
  end
end
