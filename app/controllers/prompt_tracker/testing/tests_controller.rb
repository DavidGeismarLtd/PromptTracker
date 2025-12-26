# frozen_string_literal: true

module PromptTracker
  module Testing
    # Controller for managing tests for PromptVersions in the Testing section
    #
    # This controller inherits all CRUD logic from TestsControllerBase.
    #
    class TestsController < TestsControllerBase
      private

      # Set the testable (PromptVersion) and related instance variables
      def set_testable
        @version = PromptVersion.find(params[:prompt_version_id])
        @prompt = @version.prompt
        @testable = @version
      end

      # Returns the path to the prompt version's show page
      def testable_path
        testing_prompt_prompt_version_path(@prompt, @version)
      end

      # Returns the path to a specific test's show page
      def test_path(test)
        testing_prompt_prompt_version_test_path(@prompt, @version, test)
      end

      # Returns the path to the tests index page
      def tests_index_path
        testing_prompt_prompt_version_tests_path(@prompt, @version)
      end
    end
  end
end
