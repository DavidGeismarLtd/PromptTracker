# frozen_string_literal: true

module PromptTracker
  # Configuration for PromptTracker.
  #
  # @example Configure in an initializer
  #   PromptTracker.configure do |config|
  #     config.prompts_path = Rails.root.join("app", "prompts")
  #     config.auto_sync_in_development = true
  #     config.basic_auth_username = "admin"
  #     config.basic_auth_password = "secret"
  #   end
  #
  class Configuration
    # Path to the directory containing prompt YAML files.
    # @return [String] the prompts directory path
    attr_accessor :prompts_path

    # Whether to automatically sync prompts from files in development.
    # @return [Boolean] true to auto-sync in development
    attr_accessor :auto_sync_in_development

    # Whether to automatically sync prompts from files in production.
    # @return [Boolean] true to auto-sync in production
    attr_accessor :auto_sync_in_production

    # Basic authentication username for web UI access.
    # If nil, basic auth is disabled and URLs are public.
    # @return [String, nil] the username
    attr_accessor :basic_auth_username

    # Basic authentication password for web UI access.
    # If nil, basic auth is disabled and URLs are public.
    # @return [String, nil] the password
    attr_accessor :basic_auth_password

    # Base ActiveRecord class to inherit from.
    # Stored as a string constant name, e.g. "::ActiveRecord::Base".
    # @return [String] the base record class name
    attr_accessor :base_record_class

    # Initialize with default values.
    def initialize
      @prompts_path = default_prompts_path
      @auto_sync_in_development = true
      @auto_sync_in_production = false
      @basic_auth_username = nil
      @basic_auth_password = nil
      @base_record_class = "::ActiveRecord::Base"
    end

    # Check if auto-sync is enabled for the current environment.
    #
    # @return [Boolean] true if auto-sync is enabled
    def auto_sync_enabled?
      return false unless defined?(Rails) && Rails.respond_to?(:env)

      if Rails.env.development?
        auto_sync_in_development
      elsif Rails.env.production?
        auto_sync_in_production
      else
        false
      end
    end

    # Check if basic authentication is enabled.
    #
    # @return [Boolean] true if both username and password are set
    def basic_auth_enabled?
      basic_auth_username.present? && basic_auth_password.present?
    end

    private

    # Get the default prompts path.
    #
    # @return [String] default path
    def default_prompts_path
      if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        Rails.root.join("app", "prompts").to_s
      else
        File.join(Dir.pwd, "app", "prompts")
      end
    end
  end

  # Get the current configuration.
  #
  # @return [Configuration] the configuration instance
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configure PromptTracker.
  #
  # @yield [Configuration] the configuration instance
  # @example
  #   PromptTracker.configure do |config|
  #     config.prompts_path = "/custom/path"
  #   end
  def self.configure
    yield(configuration)
  end

  # Reset configuration to defaults.
  # Mainly used for testing.
  def self.reset_configuration!
    @configuration = Configuration.new
  end
end
