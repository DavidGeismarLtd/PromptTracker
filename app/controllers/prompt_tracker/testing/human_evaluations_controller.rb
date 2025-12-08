# frozen_string_literal: true

module PromptTracker
  module Testing
    # Controller for managing human evaluations in testing context
    class HumanEvaluationsController < ApplicationController
      before_action :set_prompt_test_run, only: [:create]

      # POST /testing/runs/:run_id/human_evaluations
      # Create a new human evaluation for a test run
      def create
        @human_evaluation = @prompt_test_run.human_evaluations.build(human_evaluation_params)

        if @human_evaluation.save
          redirect_to testing_prompt_prompt_version_prompt_test_path(
                        @prompt_test_run.prompt_version.prompt,
                        @prompt_test_run.prompt_version,
                        @prompt_test_run.prompt_test
                      ),
                      notice: "Human evaluation added successfully! Score: #{@human_evaluation.score}"
        else
          redirect_to testing_prompt_prompt_version_prompt_test_path(
                        @prompt_test_run.prompt_version.prompt,
                        @prompt_test_run.prompt_version,
                        @prompt_test_run.prompt_test
                      ),
                      alert: "Error creating human evaluation: #{@human_evaluation.errors.full_messages.join(', ')}"
        end
      end

      private

      def set_prompt_test_run
        @prompt_test_run = PromptTestRun.find(params[:run_id])
      end

      def human_evaluation_params
        params.require(:human_evaluation).permit(:score, :feedback)
      end
    end
  end
end
