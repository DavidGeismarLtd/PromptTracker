# frozen_string_literal: true

require "test_helper"
require "fileutils"

module PromptTracker
  class FileSyncServiceTest < ActiveSupport::TestCase
    def setup
      # Create a temporary directory for test files
      @temp_dir = Dir.mktmpdir("prompt_tracker_test")

      # Configure PromptTracker to use temp directory
      PromptTracker.configure do |config|
        config.prompts_path = @temp_dir
      end

      # Clean up database
      Evaluation.delete_all
      LlmResponse.delete_all
      PromptVersion.delete_all
      Prompt.delete_all

      # Create a valid test file
      @test_file_path = File.join(@temp_dir, "test_prompt.yml")
      File.write(@test_file_path, <<~YAML)
        name: test_prompt
        description: A test prompt
        category: testing
        tags:
          - test
        user_prompt: "Hello {{name}}"
        variables:
          - name: name
            type: string
            required: true
        model_config:
          temperature: 0.7
      YAML
    end

    def teardown
      # Clean up temp directory
      FileUtils.rm_rf(@temp_dir) if @temp_dir
      PromptTracker.reset_configuration!
    end

    # find_prompt_files Tests

    test "find_prompt_files should find YAML files" do
      service = FileSyncService.new
      files = service.find_prompt_files

      assert_includes files, @test_file_path
    end

    test "find_prompt_files should find files in subdirectories" do
      subdir = File.join(@temp_dir, "support")
      FileUtils.mkdir_p(subdir)
      subfile = File.join(subdir, "greeting.yml")
      File.write(subfile, "name: greeting\nuser_prompt: 'Hi'")

      service = FileSyncService.new
      files = service.find_prompt_files

      assert_includes files, subfile
    end

    test "find_prompt_files should return empty array if directory does not exist" do
      PromptTracker.configure do |config|
        config.prompts_path = "/nonexistent/directory"
      end

      service = FileSyncService.new
      files = service.find_prompt_files

      assert_equal [], files
    end

    # validate_all Tests

    test "validate_all should validate all files" do
      result = FileSyncService.validate_all

      assert result[:valid]
      assert_equal 1, result[:total]
      assert_equal 1, result[:files].length
      assert_equal 0, result[:errors].length
    end

    test "validate_all should detect invalid files" do
      invalid_file = File.join(@temp_dir, "invalid.yml")
      File.write(invalid_file, "name: Invalid Name\nuser_prompt: 'Hi'")

      result = FileSyncService.validate_all

      assert_not result[:valid]
      assert_equal 2, result[:total]
      assert_equal 1, result[:errors].length
    end

    # sync_file Tests

    test "sync_file should create new prompt and version" do
      result = FileSyncService.sync_file(@test_file_path)

      assert result[:success]
      assert_equal "created", result[:action]
      assert_instance_of Prompt, result[:prompt]
      assert_instance_of PromptVersion, result[:version]

      prompt = result[:prompt]
      assert_equal "test_prompt", prompt.name
      assert_equal "A test prompt", prompt.description

      version = result[:version]
      assert_equal "Hello {{name}}", version.user_prompt
      assert_equal "active", version.status
      assert_equal "file", version.source
      assert_equal 1, version.version_number
    end

    test "sync_file should skip if no changes" do
      # First sync
      FileSyncService.sync_file(@test_file_path)

      # Second sync without changes
      result = FileSyncService.sync_file(@test_file_path)

      assert result[:success]
      assert result[:skipped]
    end

    test "sync_file should create new version if user_prompt changes" do
      # First sync
      FileSyncService.sync_file(@test_file_path)

      # Modify user_prompt
      File.write(@test_file_path, <<~YAML)
        name: test_prompt
        description: A test prompt
        user_prompt: "Hi {{name}}"
        variables:
          - name: name
            type: string
      YAML

      # Second sync
      result = FileSyncService.sync_file(@test_file_path)

      assert result[:success]
      assert_equal "updated", result[:action]
      assert_equal 2, result[:version].version_number
      assert_equal "Hi {{name}}", result[:version].user_prompt
    end

    test "sync_file should create new version if variables change" do
      # First sync
      FileSyncService.sync_file(@test_file_path)

      # Modify variables
      File.write(@test_file_path, <<~YAML)
        name: test_prompt
        user_prompt: "Hello {{name}}"
        variables:
          - name: name
            type: string
          - name: age
            type: integer
      YAML

      # Second sync
      result = FileSyncService.sync_file(@test_file_path)

      assert result[:success]
      assert_equal 2, result[:version].version_number
      assert_equal 2, result[:version].variables_schema.length
    end

    test "sync_file should create new version if model_config changes" do
      # First sync
      FileSyncService.sync_file(@test_file_path)

      # Modify model_config
      File.write(@test_file_path, <<~YAML)
        name: test_prompt
        user_prompt: "Hello {{name}}"
        model_config:
          temperature: 0.9
      YAML

      # Second sync
      result = FileSyncService.sync_file(@test_file_path)

      assert result[:success]
      assert_equal 2, result[:version].version_number
      assert_equal 0.9, result[:version].model_config["temperature"]
    end

    test "sync_file should force update even if no changes" do
      # First sync
      FileSyncService.sync_file(@test_file_path)

      # Force sync without changes
      result = FileSyncService.sync_file(@test_file_path, force: true)

      assert result[:success]
      assert_equal "updated", result[:action]
      assert_equal 2, result[:version].version_number
    end

    test "sync_file should deprecate old version when creating new one" do
      # First sync
      first_result = FileSyncService.sync_file(@test_file_path)
      first_version = first_result[:version]

      # Modify and sync again
      File.write(@test_file_path, <<~YAML)
        name: test_prompt
        user_prompt: "Hi {{name}}"
      YAML

      FileSyncService.sync_file(@test_file_path)

      # Check that first version is deprecated
      first_version.reload
      assert_equal "deprecated", first_version.status
    end

    test "sync_file should return error for invalid file" do
      invalid_file = File.join(@temp_dir, "invalid.yml")
      File.write(invalid_file, "name: Invalid Name\nuser_prompt: 'Hi'")

      result = FileSyncService.sync_file(invalid_file)

      assert_not result[:success]
      assert_includes result[:error], "lowercase"
    end

    test "sync_file should update prompt metadata without creating new version" do
      # First sync
      FileSyncService.sync_file(@test_file_path)

      # Modify only description (not user_prompt/variables/config)
      File.write(@test_file_path, <<~YAML)
        name: test_prompt
        description: Updated description
        category: testing
        tags:
          - test
        user_prompt: "Hello {{name}}"
        variables:
          - name: name
            type: string
            required: true
        model_config:
          temperature: 0.7
      YAML

      # Second sync
      result = FileSyncService.sync_file(@test_file_path)

      # Should skip creating new version but update prompt
      assert result[:success]
      assert result[:skipped]

      # But prompt description should be updated
      prompt = Prompt.find_by(name: "test_prompt")
      assert_equal "Updated description", prompt.description
    end

    # sync_all Tests

    test "sync_all should sync all files" do
      # Create multiple files
      File.write(File.join(@temp_dir, "prompt1.yml"), <<~YAML)
        name: prompt1
        user_prompt: "Test 1"
      YAML

      File.write(File.join(@temp_dir, "prompt2.yml"), <<~YAML)
        name: prompt2
        user_prompt: "Test 2"
      YAML

      result = FileSyncService.sync_all

      assert_equal 3, result[:synced] # Including the setup file
      assert_equal 0, result[:errors]
      assert_equal 3, result[:details].length
    end

    test "sync_all should report errors for invalid files" do
      # Create an invalid file
      File.write(File.join(@temp_dir, "invalid.yml"), <<~YAML)
        name: Invalid Name
        user_prompt: "Test"
      YAML

      result = FileSyncService.sync_all

      assert_equal 1, result[:synced] # Only the valid setup file
      assert_equal 1, result[:errors]
    end

    test "sync_all should skip unchanged files" do
      # First sync
      FileSyncService.sync_all

      # Second sync without changes
      result = FileSyncService.sync_all

      assert_equal 0, result[:synced]
      assert_equal 1, result[:skipped]
    end

    test "sync_all with force should update all files" do
      # First sync
      FileSyncService.sync_all

      # Force sync
      result = FileSyncService.sync_all(force: true)

      assert_equal 1, result[:synced]
      assert_equal 0, result[:skipped]
    end
  end
end
