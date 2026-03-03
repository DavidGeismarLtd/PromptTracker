# frozen_string_literal: true

module PromptTracker
  # Helper module for generating engine URLs with proper options.
  #
  # This module provides URL generation methods that work in both controller
  # and background job contexts by automatically merging URL options from
  # the configured url_options_provider.
  #
  # This is essential for multi-tenant applications where the engine is mounted
  # under a scoped route like:
  #   scope "/orgs/:org_slug" do
  #     mount PromptTracker::Engine, at: "/app"
  #   end
  #
  # @example In a view or helper
  #   engine_path(:testing_prompt_version_tests_path, version)
  #   engine_url(:testing_root_url)
  #
  # @example In a background job
  #   include PromptTracker::UrlHelper
  #   engine_path(:run_testing_prompt_version_test_path, version, test)
  module UrlHelper
    extend ActiveSupport::Concern

    # Generate an engine path with proper URL options for multi-tenant support.
    #
    # @param route_name [Symbol] The name of the route helper method
    # @param args [Array] Arguments to pass to the route helper
    # @return [String] The generated path
    # @example
    #   engine_path(:testing_prompt_version_tests_path, version)
    #   engine_path(:testing_prompt_version_test_path, version, test)
    def engine_path(route_name, *args)
      generate_engine_url(route_name, *args)
    end

    # Generate an engine URL with proper URL options for multi-tenant support.
    # Alias for engine_path - useful for semantic clarity when full URLs are expected.
    #
    # @param route_name [Symbol] The name of the route helper method
    # @param args [Array] Arguments to pass to the route helper
    # @return [String] The generated URL/path
    def engine_url(route_name, *args)
      generate_engine_url(route_name, *args)
    end

    private

    # Generate an engine URL, merging configured URL options.
    #
    # @param route_name [Symbol] The name of the route helper method
    # @param args [Array] Arguments to pass to the route helper
    # @return [String] The generated URL/path
    def generate_engine_url(route_name, *args)
      # Extract options hash if last argument is a hash
      options = args.last.is_a?(Hash) ? args.pop : {}

      # Merge with configured URL options
      merged_options = url_options_from_provider.merge(options)

      # Call the route helper with merged options
      if merged_options.empty?
        PromptTracker::Engine.routes.url_helpers.public_send(route_name, *args)
      else
        PromptTracker::Engine.routes.url_helpers.public_send(route_name, *args, merged_options)
      end
    end

    # Get URL options from the configured provider.
    #
    # @return [Hash] URL options hash, empty if no provider configured
    def url_options_from_provider
      provider = PromptTracker.configuration.url_options_provider
      return {} unless provider

      provider.call || {}
    end
  end
end
