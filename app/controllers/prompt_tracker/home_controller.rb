# frozen_string_literal: true

module PromptTracker
  # Home controller for the main landing page
  class HomeController < ApplicationController
    # GET /
    # Main landing page explaining Testing and Monitoring sections
    def index
      # Get some quick stats for the dashboard
      @total_prompts = Prompt.count
      @active_prompts = Prompt.active.count
      @total_test_runs = PromptTestRun.count
      @total_tracked_calls = LlmResponse.tracked_calls.count
      @total_evaluations = Evaluation.tracked.count
    end
  end
end

