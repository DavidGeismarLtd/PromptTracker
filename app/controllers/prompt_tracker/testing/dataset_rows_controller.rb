# frozen_string_literal: true

module PromptTracker
  module Testing
    # Unified controller for managing dataset rows across all testable types
    #
    # Uses shallow routing - dataset_rows are nested under /testing/datasets/:id
    # which means we only need the dataset_id to find the dataset, regardless
    # of the testable type.
    #
    # This eliminates the need for separate controllers per testable type.
    #
    class DatasetRowsController < ApplicationController
      include DatasetsHelper

      before_action :set_dataset
      before_action :set_row, only: [ :update, :destroy ]

      # POST /testing/datasets/:dataset_id/rows
      def create
        @row = @dataset.dataset_rows.build(row_params)

        if @row.save
          respond_to do |format|
            format.html { redirect_to redirect_path, notice: "Row added successfully." }
            format.turbo_stream { flash.now[:notice] = "Row added successfully." }
          end
        else
          respond_to do |format|
            format.html { redirect_to redirect_path, alert: "Failed to add row: #{@row.errors.full_messages.join(', ')}" }
            format.turbo_stream { render_error_turbo_stream("Failed to add row: #{@row.errors.full_messages.join(', ')}") }
          end
        end
      end

      # PATCH/PUT /testing/datasets/:dataset_id/rows/:id
      def update
        if @row.update(row_params)
          respond_to do |format|
            format.html { redirect_to redirect_path, notice: "Row updated successfully." }
            format.turbo_stream { flash.now[:notice] = "Row updated successfully." }
          end
        else
          respond_to do |format|
            format.html { redirect_to redirect_path, alert: "Failed to update row: #{@row.errors.full_messages.join(', ')}" }
            format.turbo_stream { render_error_turbo_stream("Failed to update row: #{@row.errors.full_messages.join(', ')}") }
          end
        end
      end

      # DELETE /testing/datasets/:dataset_id/rows/:id
      def destroy
        @row.destroy
        respond_to do |format|
          format.html { redirect_to redirect_path, notice: "Row deleted successfully." }
          format.turbo_stream { flash.now[:notice] = "Row deleted successfully." }
        end
      end

      # DELETE /testing/datasets/:dataset_id/rows/batch_destroy
      def batch_destroy
        row_ids = params[:row_ids]

        if row_ids.blank?
          respond_to do |format|
            format.html { redirect_to redirect_path, alert: "No rows selected for deletion." }
            format.turbo_stream { render_error_turbo_stream("No rows selected for deletion.") }
          end
          return
        end

        deleted_count = @dataset.dataset_rows.where(id: row_ids).destroy_all.count

        respond_to do |format|
          format.html { redirect_to redirect_path, notice: "#{deleted_count} row(s) deleted successfully." }
          format.turbo_stream { flash.now[:notice] = "#{deleted_count} row(s) deleted successfully." }
        end
      end

      private

      # Find dataset by ID (shallow route - no testable context needed)
      def set_dataset
        @dataset = Dataset.find(params[:dataset_id])
        @testable = @dataset.testable
      end

      def set_row
        @row = @dataset.dataset_rows.find(params[:id])
      end

      # Redirect to the shallow dataset show path
      def redirect_path
        testing_dataset_path(@dataset)
      end

      def row_params
        params.require(:dataset_row).permit(:source, row_data: {}, metadata: {})
      end

      def render_error_turbo_stream(message)
        render turbo_stream: turbo_stream.update(
          "generation-status",
          partial: "prompt_tracker/shared/alert",
          locals: { type: "danger", message: message }
        )
      end
    end
  end
end
