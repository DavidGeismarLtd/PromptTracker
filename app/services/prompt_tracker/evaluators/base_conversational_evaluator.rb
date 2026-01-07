# frozen_string_literal: true

module PromptTracker
  module Evaluators
    # Base class for evaluators that work with conversational data.
    #
    # Works with both Response API and Assistants API conversations.
    # These evaluators receive conversation_data (Hash) and evaluate multi-turn conversations.
    #
    # Used for: conversational test mode (Response API or Assistants API)
    #
    # Subclasses should implement:
    # - #evaluate_score: Calculate the numeric score (0-100)
    # - .metadata: Class method providing evaluator metadata
    #
    # @example Creating a conversation-based evaluator
    #   class MyConversationEvaluator < BaseConversationalEvaluator
    #     def evaluate_score
    #       assistant_messages.length > 2 ? 100 : 50
    #     end
    #   end
    #
    class BaseConversationalEvaluator < BaseEvaluator
      attr_reader :conversation_data

      # Returns the API type this evaluator works with
      #
      # @return [Symbol] :conversational
      def self.api_type
        :conversational
      end

      # Initialize the evaluator with conversation data
      #
      # @param conversation_data [Hash] the conversation data with messages array
      # @param config [Hash] configuration for the evaluator
      def initialize(conversation_data, config = {})
        @conversation_data = conversation_data || {}
        super(config)
      end

      # Helper: Get messages from conversation
      #
      # @return [Array<Hash>] array of message hashes
      def messages
        @messages ||= conversation_data["messages"] || conversation_data[:messages] || []
      end

      # Helper: Get assistant messages only
      #
      # @return [Array<Hash>] array of assistant message hashes
      def assistant_messages
        @assistant_messages ||= messages.select do |msg|
          role = msg["role"] || msg[:role]
          role == "assistant"
        end
      end

      # Helper: Get user messages only
      #
      # @return [Array<Hash>] array of user message hashes
      def user_messages
        @user_messages ||= messages.select do |msg|
          role = msg["role"] || msg[:role]
          role == "user"
        end
      end

      # Evaluate and create an Evaluation record
      # All scores are 0-100
      #
      # @return [Evaluation] the created evaluation
      def evaluate
        score = evaluate_score
        feedback_text = generate_feedback

        Evaluation.create!(
          test_run: config[:test_run],
          evaluator_type: self.class.name,
          evaluator_config_id: config[:evaluator_config_id],
          score: score,
          score_min: 0,
          score_max: 100,
          passed: passed?,
          feedback: feedback_text,
          metadata: metadata,
          evaluation_context: config[:evaluation_context] || "tracked_call"
        )
      end
    end
  end
end
