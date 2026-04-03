# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PromptTracker::AbTestsController", type: :request do
  let(:prompt) { create(:agent, :with_active_version) }
  let(:version_a) { prompt.active_version }
  let(:version_b) { create(:agent_version, agent: prompt) }
  let(:ab_test) do
    create(:ab_test,
           agent: prompt,
           version_a: version_a,
           version_b: version_b,
           status: "draft")
  end

  describe "GET /ab-tests" do
    it "returns success" do
      get "/prompt_tracker/ab-tests"
      expect(response).to have_http_status(:success)
    end

    it "filters by status" do
      draft_test = create(:ab_test, :draft, agent: prompt, version_a: version_a, version_b: version_b)
      running_test = create(:ab_test, :running, agent: prompt, version_a: version_a, version_b: version_b)

      get "/prompt_tracker/ab-tests", params: { status: "draft" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(draft_test.name)
      expect(response.body).not_to include(running_test.name)
    end

    it "filters by prompt" do
      ab_test # create the main test
      other_prompt = create(:agent, :with_active_version)
      other_version = other_prompt.active_version
      other_test = create(:ab_test, agent: other_prompt, version_a: other_version, version_b: other_version)

      get "/prompt_tracker/ab-tests", params: { agent_id: prompt.id }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(ab_test.name)
      expect(response.body).not_to include(other_test.name)
    end

    it "searches by name" do
      ab_test # create it
      get "/prompt_tracker/ab-tests", params: { q: ab_test.name }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(ab_test.name)
    end

    it "paginates ab_tests" do
      create_list(:ab_test, 25, agent: prompt, version_a: version_a, version_b: version_b)

      get "/prompt_tracker/ab-tests"
      expect(response).to have_http_status(:success)

      get "/prompt_tracker/ab-tests", params: { page: 2 }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /ab-tests/:id" do
    it "shows ab_test details" do
      get "/prompt_tracker/ab-tests/#{ab_test.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(ab_test.name)
      expect(response.body).to include(ab_test.description)
    end

    it "shows analysis for running test with responses" do
      ab_test.update!(status: "running", started_at: Time.current)

      # Create responses for both variants
      create_list(:llm_response, 10, agent_version: version_a, ab_test: ab_test, ab_variant: "A")
      create_list(:llm_response, 10, agent_version: version_b, ab_test: ab_test, ab_variant: "B")

      get "/prompt_tracker/ab-tests/#{ab_test.id}"
      expect(response).to have_http_status(:success)
    end

    it "returns 404 for non-existent ab_test" do
      get "/prompt_tracker/ab-tests/999999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /agents/:agent_id/ab-tests/new" do
    it "shows new ab_test form" do
      get "/prompt_tracker/agents/#{prompt.id}/ab-tests/new"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("New A/B Test")
    end

    it "sets default values" do
      get "/prompt_tracker/agents/#{prompt.id}/ab-tests/new"
      expect(response).to have_http_status(:success)
      # Default traffic split should be 50/50
      expect(response.body).to include("50")
    end
  end

  describe "POST /agents/:agent_id/ab-tests" do
    it "creates ab_test" do
      expect {
        post "/prompt_tracker/agents/#{prompt.id}/ab-tests", params: {
          ab_test: {
            name: "New Test",
            description: "Testing",
            metric_to_optimize: "cost",
            optimization_direction: "minimize",
            confidence_level: 0.95,
            minimum_sample_size: 100,
            traffic_split: { "A" => 60, "B" => 40 },
            variants: [
              { name: "A", version_id: version_a.id },
              { name: "B", version_id: version_b.id }
            ]
          }
        }
      }.to change(PromptTracker::AbTest, :count).by(1)

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{PromptTracker::AbTest.last.id}")
      follow_redirect!
      expect(response.body).to include("A/B test created successfully")
    end

    it "handles invalid ab_test" do
      expect {
        post "/prompt_tracker/agents/#{prompt.id}/ab-tests", params: {
          ab_test: {
            name: "", # Invalid - blank
            metric_to_optimize: "cost",
            optimization_direction: "minimize"
          }
        }
      }.not_to change(PromptTracker::AbTest, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /ab-tests/:id/edit" do
    it "shows edit form for draft test" do
      get "/prompt_tracker/ab-tests/#{ab_test.id}/edit"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit A/B Test")
    end

    it "redirects for running test" do
      ab_test.update!(status: "running", started_at: Time.current)

      get "/prompt_tracker/ab-tests/#{ab_test.id}/edit"
      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("Cannot edit a running or completed test")
    end

    it "redirects for completed test" do
      ab_test.update!(status: "completed", started_at: 1.day.ago, completed_at: Time.current, results: { "winner" => "A" })

      get "/prompt_tracker/ab-tests/#{ab_test.id}/edit"
      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("Cannot edit a running or completed test")
    end
  end

  describe "PATCH /ab-tests/:id" do
    it "updates draft ab_test" do
      patch "/prompt_tracker/ab-tests/#{ab_test.id}", params: {
        ab_test: {
          name: "Updated Test",
          description: "Updated description"
        }
      }

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("A/B test updated successfully")

      ab_test.reload
      expect(ab_test.name).to eq("Updated Test")
      expect(ab_test.description).to eq("Updated description")
    end

    it "does not update running ab_test" do
      ab_test.update!(status: "running", started_at: Time.current)

      patch "/prompt_tracker/ab-tests/#{ab_test.id}", params: {
        ab_test: { name: "Updated" }
      }

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("Cannot update a running or completed test")
    end

    it "handles invalid update" do
      patch "/prompt_tracker/ab-tests/#{ab_test.id}", params: {
        ab_test: { name: "" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /ab-tests/:id" do
    it "destroys draft ab_test" do
      ab_test # create it first

      expect {
        delete "/prompt_tracker/ab-tests/#{ab_test.id}"
      }.to change(PromptTracker::AbTest, :count).by(-1)

      expect(response).to redirect_to("/prompt_tracker/ab-tests")
      follow_redirect!
      expect(response.body).to include("A/B test deleted successfully")
    end

    it "does not destroy running ab_test" do
      ab_test.update!(status: "running", started_at: Time.current)

      expect {
        delete "/prompt_tracker/ab-tests/#{ab_test.id}"
      }.not_to change(PromptTracker::AbTest, :count)

      expect(response).to redirect_to("/prompt_tracker/ab-tests")
      follow_redirect!
      expect(response.body).to include("Cannot delete a running or completed test")
    end

    it "does not destroy completed ab_test" do
      ab_test.update!(status: "completed", started_at: 1.day.ago, completed_at: Time.current, results: { "winner" => "A" })

      expect {
        delete "/prompt_tracker/ab-tests/#{ab_test.id}"
      }.not_to change(PromptTracker::AbTest, :count)

      expect(response).to redirect_to("/prompt_tracker/ab-tests")
      follow_redirect!
      expect(response.body).to include("Cannot delete a running or completed test")
    end
  end

  describe "POST /ab-tests/:id/start" do
    it "starts draft ab_test" do
      post "/prompt_tracker/ab-tests/#{ab_test.id}/start"

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("A/B test started successfully")

      ab_test.reload
      expect(ab_test.status).to eq("running")
      expect(ab_test.started_at).not_to be_nil
    end

    it "does not start already running ab_test" do
      ab_test.update!(status: "running", started_at: Time.current)

      post "/prompt_tracker/ab-tests/#{ab_test.id}/start"

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("Test is already running or completed")
    end
  end

  describe "POST /ab-tests/:id/pause" do
    it "pauses running ab_test" do
      ab_test.update!(status: "running", started_at: Time.current)

      post "/prompt_tracker/ab-tests/#{ab_test.id}/pause"

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("A/B test paused successfully")

      ab_test.reload
      expect(ab_test.status).to eq("paused")
    end

    it "does not pause non-running ab_test" do
      post "/prompt_tracker/ab-tests/#{ab_test.id}/pause"

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("Test is not running")
    end
  end

  describe "POST /ab-tests/:id/resume" do
    it "resumes paused ab_test" do
      ab_test.update!(status: "paused", started_at: 1.hour.ago)

      post "/prompt_tracker/ab-tests/#{ab_test.id}/resume"

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("A/B test resumed successfully")

      ab_test.reload
      expect(ab_test.status).to eq("running")
    end

    it "does not resume non-paused ab_test" do
      post "/prompt_tracker/ab-tests/#{ab_test.id}/resume"

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("Test is not paused")
    end
  end

  describe "POST /ab-tests/:id/complete" do
    it "completes running ab_test with winner" do
      ab_test.update!(status: "running", started_at: 1.hour.ago)

      post "/prompt_tracker/ab-tests/#{ab_test.id}/complete", params: { winner: "A" }

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("A/B test completed successfully")

      ab_test.reload
      expect(ab_test.status).to eq("completed")
      expect(ab_test.results["winner"]).to eq("A")
      expect(ab_test.completed_at).not_to be_nil
    end

    it "completes and promotes winner" do
      ab_test.update!(status: "running", started_at: 1.hour.ago)

      post "/prompt_tracker/ab-tests/#{ab_test.id}/complete", params: { winner: "A", promote_winner: "true" }

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("A/B test completed and winner promoted successfully")

      ab_test.reload
      expect(ab_test.status).to eq("completed")
      expect(ab_test.results["winner"]).to eq("A")

      # Check that winner was promoted to active
      version_a.reload
      expect(version_a.status).to eq("active")
    end

    it "does not complete non-running ab_test" do
      post "/prompt_tracker/ab-tests/#{ab_test.id}/complete", params: { winner: "A" }

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("Test is not running")
    end

    it "does not complete without winner" do
      ab_test.update!(status: "running", started_at: 1.hour.ago)

      post "/prompt_tracker/ab-tests/#{ab_test.id}/complete"

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("Invalid winner variant")
    end

    it "does not complete with invalid winner" do
      ab_test.update!(status: "running", started_at: 1.hour.ago)

      post "/prompt_tracker/ab-tests/#{ab_test.id}/complete", params: { winner: "Z" }

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("Invalid winner variant")
    end
  end

  describe "POST /ab-tests/:id/cancel" do
    it "cancels running ab_test" do
      ab_test.update!(status: "running", started_at: 1.hour.ago)

      post "/prompt_tracker/ab-tests/#{ab_test.id}/cancel"

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("A/B test cancelled successfully")

      ab_test.reload
      expect(ab_test.status).to eq("cancelled")
    end

    it "cancels paused ab_test" do
      ab_test.update!(status: "paused", started_at: 1.hour.ago)

      post "/prompt_tracker/ab-tests/#{ab_test.id}/cancel"

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("A/B test cancelled successfully")

      ab_test.reload
      expect(ab_test.status).to eq("cancelled")
    end

    it "does not cancel completed ab_test" do
      ab_test.update!(status: "completed", started_at: 1.hour.ago, completed_at: Time.current, results: { "winner" => "A" })

      post "/prompt_tracker/ab-tests/#{ab_test.id}/cancel"

      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
      follow_redirect!
      expect(response.body).to include("Cannot cancel a completed test")
    end
  end

  describe "GET /ab-tests/:id/analyze" do
    it "returns analysis as JSON" do
      ab_test.update!(status: "running", started_at: 1.hour.ago)

      # Create responses for analysis
      create_list(:llm_response, 10, agent_version: version_a, ab_test: ab_test, ab_variant: "A")
      create_list(:llm_response, 10, agent_version: version_b, ab_test: ab_test, ab_variant: "B")

      get "/prompt_tracker/ab-tests/#{ab_test.id}/analyze", headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json).not_to be_nil
    end

    it "redirects to show for HTML request" do
      ab_test.update!(status: "running", started_at: 1.hour.ago)

      get "/prompt_tracker/ab-tests/#{ab_test.id}/analyze"
      expect(response).to redirect_to("/prompt_tracker/ab-tests/#{ab_test.id}")
    end
  end
end
