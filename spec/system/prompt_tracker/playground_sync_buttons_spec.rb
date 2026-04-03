# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Playground Sync Buttons Visibility", type: :system, js: true do
  let(:prompt) { create(:agent, name: "Test Prompt", slug: "test_prompt") }

  before do
    # Configure providers for testing
    PromptTracker.configuration.providers = {
      openai: { api_key: "sk-test-key" }
    }
  end

  describe "Sync buttons visibility based on API capabilities" do
    context "when starting with Chat Completions API" do
      let(:chat_version) do
        create(
          :agent_version,
          agent: prompt,
          system_prompt: "You are a helpful assistant.",
          user_prompt: "Hello {{ name }}!",
          model_config: {
            "provider" => "openai",
            "api" => "chat_completions",
            "model" => "gpt-4",
            "temperature" => 0.7
          }
        )
      end

      it "hides sync buttons initially" do
        visit prompt_tracker.testing_agent_agent_version_playground_path(prompt, chat_version)

        # Sync buttons should be hidden (display: none)
        sync_buttons = find('[data-playground-sync-visibility-target="syncButtons"]', visible: :all)
        expect(sync_buttons).not_to be_visible
      end

      it "shows sync buttons when switching to Assistants API" do
        visit prompt_tracker.testing_agent_agent_version_playground_path(prompt, chat_version)

        # Initially hidden
        expect(page).not_to have_button("Push", wait: 1)

        # Switch to Assistants API
        select "Assistants", from: "API"

        # Sync buttons should now be visible
        sync_buttons = find('[data-playground-sync-visibility-target="syncButtons"]', visible: :all)
        expect(page).to have_button("Push", wait: 2)
        expect(sync_buttons).to be_visible
      end

      it "hides sync buttons when switching back to Chat Completions" do
        visit prompt_tracker.testing_agent_agent_version_playground_path(prompt, chat_version)

        # Switch to Assistants
        select "Assistants", from: "API"
        sleep 0.5

        sync_buttons = find('[data-playground-sync-visibility-target="syncButtons"]', visible: :all)
        expect(sync_buttons).to be_visible

        # Switch back to Chat Completions
        select "Chat Completions", from: "API"
        sleep 0.5

        # Sync buttons should be hidden again
        expect(sync_buttons).not_to be_visible
      end
    end

    context "when starting with Assistants API" do
      let(:assistant_version) do
        create(
          :agent_version,
          agent: prompt,
          system_prompt: "You are a helpful assistant.",
          model_config: {
            "provider" => "openai",
            "api" => "assistants",
            "model" => "gpt-4",
            "temperature" => 0.7
          }
        )
      end

      it "shows sync buttons initially" do
        visit prompt_tracker.testing_agent_agent_version_playground_path(prompt, assistant_version)

        # The sync buttons should be visible for Assistants API
        expect(page).to have_button("Push")

        sync_buttons = find('[data-playground-sync-visibility-target="syncButtons"]')
        expect(sync_buttons).to be_visible
      end

      it "hides sync buttons when switching to Chat Completions API" do
        visit prompt_tracker.testing_agent_agent_version_playground_path(prompt, assistant_version)

        # Initially visible
        sync_buttons = find('[data-playground-sync-visibility-target="syncButtons"]', visible: :all)
        expect(sync_buttons).to be_visible

        # Switch to Chat Completions
        select "Chat Completions", from: "API"

        # Wait for visibility update
        sleep 0.5

        # Sync buttons should now be hidden
        expect(sync_buttons).not_to be_visible
      end
    end

    context "when assistant_id is present in metadata" do
      let(:synced_assistant_version) do
        create(
          :agent_version,
          agent: prompt,
          system_prompt: "You are a helpful assistant.",
          model_config: {
            "provider" => "openai",
            "api" => "assistants",
            "model" => "gpt-4",
            "temperature" => 0.7,
            "metadata" => {
              "assistant_id" => "asst_abc123",
              "sync_status" => "synced",
              "synced_at" => Time.current.iso8601
            }
          }
        )
      end

      it "shows both Push and Pull buttons" do
        visit prompt_tracker.testing_agent_agent_version_playground_path(prompt, synced_assistant_version)

        # Both buttons should be visible
        expect(page).to have_button("Push")
        expect(page).to have_button("Pull")
      end

      it "maintains Pull button visibility when switching APIs" do
        visit prompt_tracker.testing_agent_agent_version_playground_path(prompt, synced_assistant_version)

        # Initially both buttons visible
        expect(page).to have_button("Push")
        expect(page).to have_button("Pull")

        # Switch to Chat Completions
        select "Chat Completions", from: "API"
        sleep 0.5

        # Both buttons should be hidden
        sync_buttons = find('[data-playground-sync-visibility-target="syncButtons"]', visible: :all)
        expect(sync_buttons).not_to be_visible

        # Switch back to Assistants
        select "Assistants", from: "API"
        sleep 0.5

        # Both buttons should be visible again
        expect(page).to have_button("Push")
        expect(page).to have_button("Pull")
      end
    end
  end
end
