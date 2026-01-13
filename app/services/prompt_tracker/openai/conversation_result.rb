# frozen_string_literal: true

module PromptTracker
  module Openai
    # Value object representing the result of a multi-turn conversation.
    #
    # This class provides a structured way to access conversation data
    # from both Assistants API and Response API conversations.
    #
    # @example Create from hash
    #   result = ConversationResult.new(
    #     messages: [{ role: "user", content: "Hello" }],
    #     total_turns: 1,
    #     status: "completed"
    #   )
    #
    # @example Access data
    #   result.messages        # => [{ role: "user", content: "Hello" }]
    #   result.total_turns     # => 1
    #   result.completed?      # => true
    #   result.to_h            # => { messages: [...], ... }
    #
    class ConversationResult
      attr_reader :messages, :total_turns, :status, :metadata, :run_steps,
                  :thread_id, :previous_response_id

      # Initialize a conversation result
      #
      # @param messages [Array<Hash>] array of message hashes with :role, :content, :turn
      # @param total_turns [Integer] number of completed turns
      # @param status [String] conversation status ("completed", "error", "max_turns_reached")
      # @param metadata [Hash] additional metadata
      # @param run_steps [Array<Hash>] run steps from Assistants API (optional)
      # @param thread_id [String] thread ID from Assistants API (optional)
      # @param previous_response_id [String] last response ID from Response API (optional)
      def initialize(
        messages:,
        total_turns:,
        status:,
        metadata: {},
        run_steps: [],
        thread_id: nil,
        previous_response_id: nil
      )
        @messages = messages.freeze
        @total_turns = total_turns
        @status = status
        @metadata = metadata.freeze
        @run_steps = run_steps.freeze
        @thread_id = thread_id
        @previous_response_id = previous_response_id
      end

      # Check if conversation completed successfully
      #
      # @return [Boolean]
      def completed?
        status == "completed"
      end

      # Check if conversation ended with an error
      #
      # @return [Boolean]
      def error?
        status == "error"
      end

      # Check if conversation reached max turns
      #
      # @return [Boolean]
      def max_turns_reached?
        status == "max_turns_reached"
      end

      # Get all user messages
      #
      # @return [Array<Hash>]
      def user_messages
        messages.select { |m| m[:role] == "user" }
      end

      # Get all assistant messages
      #
      # @return [Array<Hash>]
      def assistant_messages
        messages.select { |m| m[:role] == "assistant" }
      end

      # Get the last assistant message
      #
      # @return [Hash, nil]
      def last_assistant_message
        assistant_messages.last
      end

      # Get the last user message
      #
      # @return [Hash, nil]
      def last_user_message
        user_messages.last
      end

      # Get messages for a specific turn
      #
      # @param turn [Integer] the turn number
      # @return [Array<Hash>]
      def messages_for_turn(turn)
        messages.select { |m| m[:turn] == turn }
      end

      # Convert to hash (for storage in database)
      #
      # @return [Hash]
      def to_h
        {
          messages: messages,
          total_turns: total_turns,
          status: status,
          metadata: metadata,
          run_steps: run_steps,
          thread_id: thread_id,
          previous_response_id: previous_response_id
        }.compact
      end

      # Create from a hash (e.g., from database storage)
      #
      # @param hash [Hash] the hash to create from
      # @return [ConversationResult]
      def self.from_h(hash)
        hash = hash.with_indifferent_access
        new(
          messages: hash[:messages] || [],
          total_turns: hash[:total_turns] || 0,
          status: hash[:status] || "unknown",
          metadata: hash[:metadata] || {},
          run_steps: hash[:run_steps] || [],
          thread_id: hash[:thread_id],
          previous_response_id: hash[:previous_response_id]
        )
      end
    end
  end
end
