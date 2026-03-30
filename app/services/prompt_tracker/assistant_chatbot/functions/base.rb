# frozen_string_literal: true

module PromptTracker
  module AssistantChatbot
    module Functions
      # Base class for all assistant chatbot functions.
      #
      # All function classes should:
      # 1. Inherit from this class
      # 2. Implement the #execute method
      # 3. Return a Result struct with success, message, links, entities_created, error
      #
      # @example Creating a function
      #   class MyFunction < Base
      #     def execute
      #       # Do work
      #       success("Task completed!", links: [{ text: "View", url: "/path" }])
      #     end
      #   end
      #
      class Base
        Result = Struct.new(:success?, :message, :links, :entities_created, :error, keyword_init: true)

        def initialize(arguments, context)
          @arguments = arguments
          @context = context
        end

        # Main entry point - calls #execute and handles errors
        def call
          validate_arguments!
          execute
        rescue ArgumentError => e
          failure("Invalid arguments: #{e.message}")
        rescue => e
          Rails.logger.error("[#{self.class.name}] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
          failure("An error occurred: #{e.message}")
        end

        protected

        # Implement this method in subclasses
        def execute
          raise NotImplementedError, "#{self.class.name} must implement #execute"
        end

        # Validate function arguments
        # Override in subclasses to add validation
        def validate_arguments!
          # Base validation - override in subclasses
        end

        # Return a success result
        # @param message [String] success message to show user
        # @param links [Array<Hash>] array of link hashes with :text and :url
        # @param entities [Hash] hash of created entity IDs (e.g., prompt_id: 123)
        def success(message, links: [], entities: {})
          Result.new(
            success?: true,
            message: message,
            links: links,
            entities_created: entities,
            error: nil
          )
        end

        # Return a failure result
        # @param error_message [String] error message to show user
        def failure(error_message)
          Result.new(
            success?: false,
            message: nil,
            links: [],
            entities_created: {},
            error: error_message
          )
        end

        # Build a link hash
        # @param text [String] link text
        # @param url [String] link URL
        # @param icon [String] optional Bootstrap icon class
        def link(text, url, icon: nil)
          { text: text, url: url, icon: icon }
        end

        # Get argument value with symbol or string key
        def arg(key)
          @arguments[key.to_sym] || @arguments[key.to_s]
        end

        # Get context value
        def context_value(key)
          @context[key.to_sym] || @context[key.to_s]
        end
      end
    end
  end
end
