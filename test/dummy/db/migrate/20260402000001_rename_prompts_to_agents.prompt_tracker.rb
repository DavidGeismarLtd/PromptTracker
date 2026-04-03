# frozen_string_literal: true

# Renames prompt_tracker_prompts to prompt_tracker_agents.
# Note: prompt_tracker_agent_versions table and foreign key columns (agent_id, agent_version_id)
# were already renamed in the initial schema migration.
class RenamePromptsToAgents < ActiveRecord::Migration[7.2]
  def change
    rename_table :prompt_tracker_prompts, :prompt_tracker_agents
  end
end
