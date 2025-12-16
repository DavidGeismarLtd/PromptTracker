class AddSlugToPromptTrackerPrompts < ActiveRecord::Migration[7.2]
  def up
    # Add slug column (nullable first)
    add_column :prompt_tracker_prompts, :slug, :string

    # Populate slug for existing records
    execute <<-SQL
      UPDATE prompt_tracker_prompts
      SET slug = LOWER(REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(name, '[^a-zA-Z0-9]+', '_', 'g'),
          '^_+|_+$', '', 'g'
        ),
        '_+', '_', 'g'
      ))
      WHERE slug IS NULL
    SQL

    # Make slug NOT NULL
    change_column_null :prompt_tracker_prompts, :slug, false

    # Add unique index
    add_index :prompt_tracker_prompts, :slug, unique: true
  end

  def down
    remove_index :prompt_tracker_prompts, :slug
    remove_column :prompt_tracker_prompts, :slug
  end
end
