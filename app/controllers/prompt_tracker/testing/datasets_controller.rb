# frozen_string_literal: true

module PromptTracker
  module Testing
    # Unified controller for managing datasets across all testable types
    #
    # This controller uses shallow routing:
    # - index/new/create: nested under testable (need testable context)
    # - show/edit/update/destroy: shallow routes using dataset ID only
    #
    # Supported testable types:
    # - PromptTracker::PromptVersion (via prompt_version_id param)
    # - PromptTracker::Openai::Assistant (via assistant_id param)
    #
    # Adding a new testable type:
    # 1. Include Testable concern in the model
    # 2. Implement routing methods (show_path, datasets_index_path, etc.)
    # 3. Add parameter detection in find_testable_from_params
    # 4. Add nested routes for index/new/create
    #
    class DatasetsController < ApplicationController
      include DatasetsHelper

      # Nested routes (index/new/create): need to find testable from params
      before_action :set_testable_from_params, only: [ :index, :new, :create ]

      # Shallow routes (show/edit/update/destroy): find dataset first, then get testable from it
      before_action :set_dataset, only: [ :show, :edit, :update, :destroy, :generate_rows ]
      before_action :set_testable_from_dataset, only: [ :show, :edit, :update, :destroy, :generate_rows ]

      # GET /testing/prompts/:prompt_id/versions/:prompt_version_id/datasets
      # GET /testing/openai/assistants/:assistant_id/datasets
      def index
        @datasets = @testable.datasets.includes(:dataset_rows).recent
      end

      # GET /testing/prompts/:prompt_id/versions/:prompt_version_id/datasets/new
      # GET /testing/openai/assistants/:assistant_id/datasets/new
      def new
        @dataset = @testable.datasets.build
      end

      # POST /testing/prompts/:prompt_id/versions/:prompt_version_id/datasets
      # POST /testing/openai/assistants/:assistant_id/datasets
      def create
        @dataset = @testable.datasets.build(dataset_params)
        @dataset.created_by = "web_ui" # TODO: Replace with current_user when auth is added

        # Parse schema if it's a JSON string
        if @dataset.schema.is_a?(String)
          @dataset.schema = JSON.parse(@dataset.schema)
        end

        if @dataset.save
          redirect_to testing_dataset_path(@dataset),
                      notice: "Dataset created successfully."
        else
          render :new, status: :unprocessable_entity
        end
      end

      # GET /testing/datasets/:id (shallow route)
      def show
        @rows = @dataset.dataset_rows.recent.page(params[:page]).per(50)
      end

      # GET /testing/datasets/:id/edit (shallow route)
      def edit
      end

      # PATCH/PUT /testing/datasets/:id (shallow route)
      def update
        params_to_update = dataset_params

        # Parse schema if it's a JSON string
        if params_to_update[:schema].is_a?(String)
          params_to_update[:schema] = JSON.parse(params_to_update[:schema])
        end

        if @dataset.update(params_to_update)
          redirect_to testing_dataset_path(@dataset),
                      notice: "Dataset updated successfully."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /testing/datasets/:id (shallow route)
      def destroy
        testable = @testable
        @dataset.destroy
        redirect_to testable.datasets_index_path,
                    notice: "Dataset deleted successfully."
      end

      # POST /testing/datasets/:id/generate_rows (shallow route)
      def generate_rows
        count = params[:count].to_i
        instructions = params[:instructions].presence
        model = params[:model].presence

        # Enqueue background job
        GenerateDatasetRowsJob.perform_later(
          @dataset.id,
          count: count,
          instructions: instructions,
          model: model
        )

        redirect_to testing_dataset_path(@dataset),
                    notice: "Generating #{count} rows in the background. Rows will appear shortly."
      end

      private

      # Find dataset by ID (for shallow routes)
      def set_dataset
        @dataset = Dataset.find(params[:id])
      end

      # Get testable from the dataset (for shallow routes)
      def set_testable_from_dataset
        @testable = @dataset.testable
        set_testable_instance_variables
      end

      # Find testable from URL params (for nested routes)
      def set_testable_from_params
        @testable = find_testable_from_params
        set_testable_instance_variables
      end

      # Set convenience instance variables based on testable type
      # This allows views to access @version, @prompt, @assistant directly
      def set_testable_instance_variables
        case @testable
        when PromptVersion
          @version = @testable
          @prompt = @version.prompt
        when PromptTracker::Openai::Assistant
          @assistant = @testable
        end
      end

      # Polymorphic lookup: find testable based on which param is present
      # Add new testable types here
      def find_testable_from_params
        if params[:prompt_version_id]
          PromptTracker::PromptVersion.find(params[:prompt_version_id])
        elsif params[:assistant_id]
          PromptTracker::Openai::Assistant.find(params[:assistant_id])
        else
          raise ActiveRecord::RecordNotFound, "No testable found in params"
        end
      end

      def dataset_params
        params.require(:dataset).permit(:name, :description, :schema, metadata: {})
      end
    end
  end
end
