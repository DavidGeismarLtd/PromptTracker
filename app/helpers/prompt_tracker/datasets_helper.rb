# frozen_string_literal: true

module PromptTracker
  # Helper methods for datasets views
  #
  # This helper uses shallow routing for datasets:
  # - Dataset-specific paths (show, edit, destroy, rows) use /testing/datasets/:id
  # - Testable-specific paths (index, new) delegate to the testable model
  #
  # This eliminates case/when statements and makes adding new testable types easy.
  #
  module DatasetsHelper
    # ========================================
    # DATASET PATHS (shallow routes - no case/when needed!)
    # ========================================

    # Generate path for a dataset (show, edit, or destroy)
    # @param dataset [PromptTracker::Dataset] The dataset
    # @param action [Symbol] The action (:show, :edit, :destroy) - defaults to :show
    # @return [String] The path to the dataset
    def dataset_path(dataset, action: :show)
      case action
      when :show, :destroy
        testing_dataset_path(dataset)
      when :edit
        edit_testing_dataset_path(dataset)
      else
        testing_dataset_path(dataset)
      end
    end

    # Generate path for a dataset row
    # @param dataset [PromptTracker::Dataset] The dataset
    # @param row [PromptTracker::DatasetRow] The row
    # @return [String] The path to the dataset row
    def dataset_row_path(dataset, row)
      testing_dataset_dataset_row_path(dataset, row)
    end

    # Generate path for creating dataset rows
    # @param dataset [PromptTracker::Dataset] The dataset
    # @return [String] The path to create dataset rows
    def dataset_rows_path(dataset)
      testing_dataset_dataset_rows_path(dataset)
    end

    # Generate path for batch destroying dataset rows
    # @param dataset [PromptTracker::Dataset] The dataset
    # @return [String] The path to batch destroy dataset rows
    def batch_destroy_dataset_rows_path(dataset)
      batch_destroy_testing_dataset_dataset_rows_path(dataset)
    end

    # Generate path for generate_rows action
    # @param dataset [PromptTracker::Dataset] The dataset
    # @return [String] The path to generate rows
    def generate_rows_dataset_path(dataset)
      generate_rows_testing_dataset_path(dataset)
    end

    # ========================================
    # TESTABLE PATHS (delegate to model - polymorphic)
    # ========================================

    # Generate index path for datasets based on testable type
    # Delegates to the testable model's routing method
    # @param testable [Object] The testable (PromptVersion, Assistant, etc.)
    # @return [String] The path to the datasets index
    def datasets_index_path(testable)
      testable.datasets_index_path
    end

    # Generate new dataset path based on testable type
    # Delegates to the testable model's routing method
    # @param testable [Object] The testable (PromptVersion, Assistant, etc.)
    # @return [String] The path to create a new dataset
    def new_dataset_path(testable)
      testable.new_dataset_path
    end

    # Generate path to the testable's show page
    # Delegates to the testable model's routing method
    # @param testable [Object] The testable (PromptVersion, Assistant, etc.)
    # @return [String] The path to the testable
    def testable_show_path(testable)
      testable.show_path
    end

    # Generate path to create datasets for a testable (POST target)
    # Delegates to the testable model's routing method
    # @param testable [Object] The testable (PromptVersion, Assistant, etc.)
    # @return [String] The path to create datasets
    def testable_datasets_path(testable)
      testable.datasets_path
    end

    # ========================================
    # DISPLAY HELPERS (still need case/when for now, but could move to models)
    # ========================================

    # Get display name for a testable
    # @param testable [Object] The testable
    # @return [String] The display name
    def testable_name(testable)
      case testable
      when PromptTracker::PromptVersion
        testable.prompt.name
      when PromptTracker::Openai::Assistant
        testable.name
      else
        testable.respond_to?(:display_name) ? testable.display_name : testable.name
      end
    end

    # Generate badge HTML for a testable (e.g., version number)
    # @param testable [Object] The testable
    # @return [String] HTML badge or empty string
    def testable_badge(testable)
      case testable
      when PromptTracker::PromptVersion
        content_tag(:span, "v#{testable.version_number}", class: "badge bg-primary")
      else
        "" # Other testables don't have version badges by default
      end
    end
  end
end
