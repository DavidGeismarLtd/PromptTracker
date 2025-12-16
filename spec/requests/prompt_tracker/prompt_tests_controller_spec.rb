# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PromptTracker::PromptTestsController", type: :request do
  let(:prompt) { create(:prompt) }
  let(:version) { create(:prompt_version, prompt: prompt, status: "active") }
  let(:test) { create(:prompt_test, prompt_version: version) }

  describe "GET /prompts/:prompt_id/versions/:version_id/tests" do
    it "returns success" do
      get "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}/tests"
      expect(response).to have_http_status(:success)
    end

    it "lists all tests for the version" do
      create(:prompt_test, prompt_version: version, name: "Test 1")
      create(:prompt_test, prompt_version: version, name: "Test 2")

      get "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}/tests"

      expect(response.body).to include("Test 1")
      expect(response.body).to include("Test 2")
    end
  end

  describe "GET /prompts/:prompt_id/versions/:version_id/tests/:id" do
    it "shows test details" do
      get "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}/tests/#{test.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(test.name)
    end
  end

  describe "POST /prompts/:prompt_id/versions/:version_id/tests/:id/run" do
    it "starts a single test in the background" do
      expect {
        post "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}/tests/#{test.id}/run",
             params: { run_mode: "single", custom_variables: { name: "Test" } }
      }.to change(PromptTracker::PromptTestRun, :count).by(1)

      expect(response).to redirect_to("/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}/tests/#{test.id}")
      follow_redirect!
      expect(response.body).to match(/Test started in the background/)
<<<<<<< HEAD

      # Verify test run was created with "running" status
      test_run = PromptTracker::PromptTestRun.last
      expect(test_run.status).to eq("running")
      expect(test_run.prompt_test).to eq(test)
=======
>>>>>>> 615a897 (fix tests)
    end
  end

  describe "POST /prompts/:prompt_id/versions/:version_id/tests/run_all" do
    it "runs all enabled tests" do
      create(:prompt_test, prompt_version: version, enabled: true, name: "Test 1")
      create(:prompt_test, prompt_version: version, enabled: true, name: "Test 2")
      create(:prompt_test, prompt_version: version, enabled: false, name: "Test 3")

      expect {
        post "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all",
             params: { dataset_id: dataset.id }
      }.to change(PromptTracker::PromptTestRun, :count).by(2) # Only enabled tests (2 tests × 1 row)

      expect(response).to redirect_to("/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}")
      follow_redirect!
      expect(response.body).to match(/Started 2 tests in the background/)
    end

    it "enqueues background jobs for each enabled test" do
      create(:prompt_test, prompt_version: version, enabled: true)
      create(:prompt_test, prompt_version: version, enabled: true)

      post "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all",
           params: { dataset_id: dataset.id }

      expect(response).to redirect_to("/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}")
      follow_redirect!
      # Tests are started in background, so we see the "started" message
      expect(response.body).to match(/Started 2 tests in the background/)
    end

    it "shows alert when no enabled tests exist" do
      create(:prompt_test, prompt_version: version, enabled: false)

      post "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all",
           params: { dataset_id: dataset.id }

      expect(response).to redirect_to("/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}")
      follow_redirect!
      expect(response.body).to include("No enabled tests to run")
    end

    it "handles test failures gracefully" do
      # Create a test that will fail (no expected patterns will match mock response)
      create(:prompt_test,
        prompt_version: version,
        enabled: true,
        expected_patterns: [ "IMPOSSIBLE_PATTERN_THAT_WONT_MATCH" ]
      )

      expect {
        post "/prompt_tracker/testing/prompts/#{prompt.id}/versions/#{version.id}/tests/run_all",
             params: { dataset_id: dataset.id }
      }.to change(PromptTracker::PromptTestRun, :count).by(2)

      expect(response).to redirect_to("/prompt_tracker/prompts/#{prompt.id}/versions/#{version.id}/tests")
      follow_redirect!
      expect(response.body).to match(/Started 1 test in the background/)
    end
  end
end
