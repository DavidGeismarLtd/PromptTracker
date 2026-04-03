# frozen_string_literal: true

module PromptTracker
  module Testing
    # Controller for managing dataset rows for AgentVersions
    #
    # Handles CRUD operations for individual rows within a dataset.
    # Inherits shared logic from DatasetRowsControllerBase.
    #
    class DatasetRowsController < DatasetRowsControllerBase
      private

      def set_dataset
        @version = AgentVersion.find(params[:agent_version_id])
        @prompt = @version.agent
        @dataset = @version.datasets.find(params[:dataset_id])
      end

      def redirect_path
        testing_agent_agent_version_dataset_path(@prompt, @version, @dataset)
      end
    end
  end
end
