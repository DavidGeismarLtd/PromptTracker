# frozen_string_literal: true

require "rails_helper"

RSpec.describe "File Search Evaluator Availability", type: :system, js: true do
  describe "for PromptVersions with Responses API" do
    let(:prompt) { create(:prompt) }

    context "when no vector store is attached" do
      let(:version) do
        create(:prompt_version,
               prompt: prompt,
               status: "active",
               model_config: {
                 "provider" => "openai",
                 "api" => "responses",
                 "model" => "gpt-4o"
               })
      end

      it "disables the file search evaluator checkbox" do
        visit "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}"
        click_button "New Test"

        expect(page).to have_css("#new-test-modal", visible: true)

        # Checkbox should be disabled
        checkbox = find('input#evaluator_file_search', visible: :all)
        expect(checkbox).to be_disabled
      end
    end

    context "when vector store is attached" do
      let(:version) do
        create(:prompt_version,
               prompt: prompt,
               status: "active",
               model_config: {
                 "provider" => "openai",
                 "api" => "responses",
                 "model" => "gpt-4o",
                 "tool_config" => {
                   "file_search" => {
                     "vector_store_ids" => [ "vs_test123" ]
                   }
                 }
               })
      end

      before do
        # Mock the VectorStoreService to return files
        allow(PromptTracker::VectorStoreService)
          .to receive(:list_vector_store_files)
          .with(provider: :openai, vector_store_id: "vs_test123")
          .and_return([
            { id: "file_1", filename: "document1.pdf", bytes: 1024 },
            { id: "file_2", filename: "document2.txt", bytes: 2048 }
          ])
      end

      it "enables the file search evaluator" do
        visit "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}"
        click_button "New Test"

        expect(page).to have_css("#new-test-modal", visible: true)

        # Checkbox should be enabled
        checkbox = find('input#evaluator_file_search', visible: :all)
        expect(checkbox).not_to be_disabled
      end

      it "shows files from the vector store when evaluator is selected" do
        visit "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}"
        click_button "New Test"

        expect(page).to have_css("#new-test-modal", visible: true)

        # Check the file_search evaluator
        checkbox = find('input#evaluator_file_search')
        checkbox.check

        # Wait for config section to expand
        config_section = find("#config_file_search")
        expect(config_section).to be_visible

        # Should show the files from the vector store
        within config_section do
          expect(page).to have_content("document1.pdf")
          expect(page).to have_content("document2.txt")
          expect(page).to have_content("1 KB")
          expect(page).to have_content("2 KB")
        end
      end
    end
  end

  describe "for PromptVersions with Assistants API" do
    let(:prompt) { create(:prompt) }

    context "when no vector store is attached" do
      let(:version) do
        create(:prompt_version,
               prompt: prompt,
               status: "active",
               model_config: {
                 "provider" => "openai",
                 "api" => "assistants",
                 "model" => "gpt-4o",
                 "assistant_id" => "asst_test123"
               })
      end

      it "disables the file search evaluator checkbox" do
        visit "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}"
        click_button "New Test"

        expect(page).to have_css("#new-test-modal", visible: true)

        # Checkbox should be disabled
        checkbox = find('input#evaluator_file_search', visible: :all)
        expect(checkbox).to be_disabled
      end
    end

    context "when vector store is attached" do
      let(:version) do
        create(:prompt_version,
               prompt: prompt,
               status: "active",
               model_config: {
                 "provider" => "openai",
                 "api" => "assistants",
                 "model" => "gpt-4o",
                 "assistant_id" => "asst_test456",
                 "tool_config" => {
                   "file_search" => {
                     "vector_store_ids" => [ "vs_assistant123" ]
                   }
                 }
               })
      end

      before do
        # Mock the VectorStoreService to return files
        allow(PromptTracker::VectorStoreService)
          .to receive(:list_vector_store_files)
          .with(provider: :openai, vector_store_id: "vs_assistant123")
          .and_return([
            { id: "file_a", filename: "manual.pdf", bytes: 5120 },
            { id: "file_b", filename: "guide.docx", bytes: 3072 }
          ])
      end

      it "enables the file search evaluator" do
        visit "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}"
        click_button "New Test"

        expect(page).to have_css("#new-test-modal", visible: true)

        # Checkbox should be enabled
        checkbox = find('input#evaluator_file_search', visible: :all)
        expect(checkbox).not_to be_disabled
      end

      it "shows files from the vector store when evaluator is selected" do
        visit "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}"
        click_button "New Test"

        expect(page).to have_css("#new-test-modal", visible: true)

        # Check the file_search evaluator
        checkbox = find('input#evaluator_file_search')
        checkbox.check

        # Wait for config section to expand
        config_section = find("#config_file_search")
        expect(config_section).to be_visible

        # Should show the files from the vector store
        within config_section do
          expect(page).to have_content("manual.pdf")
          expect(page).to have_content("guide.docx")
          expect(page).to have_content("5 KB")
          expect(page).to have_content("3 KB")
        end
      end
    end
  end
end
