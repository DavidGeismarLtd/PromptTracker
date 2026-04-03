# This migration comes from prompt_tracker (originally 20260326160312)
class MakeUserPromptOptionalInAgentVersions < ActiveRecord::Migration[7.2]
  def change
    change_column_null :prompt_tracker_agent_versions, :user_prompt, true
  end
end
