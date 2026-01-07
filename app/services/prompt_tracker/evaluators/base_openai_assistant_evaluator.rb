# frozen_string_literal: true

module PromptTracker
  module Evaluators
    # @deprecated Use BaseAssistantsApiEvaluator instead.
    #   This class is kept for backward compatibility only.
    #
    # Base class for evaluators that work with OpenAI Assistant conversations.
    # Now an alias for BaseAssistantsApiEvaluator.
    #
    # @see BaseAssistantsApiEvaluator
    class BaseOpenaiAssistantEvaluator < BaseAssistantsApiEvaluator
      # Maintain backward compatibility with old compatible_with method
      def self.compatible_with
        [ PromptTracker::Openai::Assistant ]
      end
    end
  end
end
