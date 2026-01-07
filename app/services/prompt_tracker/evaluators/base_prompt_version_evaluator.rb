# frozen_string_literal: true

module PromptTracker
  module Evaluators
    # @deprecated Use BaseChatCompletionEvaluator instead.
    #   This class is kept for backward compatibility only.
    #
    # Base class for evaluators that work with PromptVersion responses.
    # Now an alias for BaseChatCompletionEvaluator.
    #
    # @see BaseChatCompletionEvaluator
    class BasePromptVersionEvaluator < BaseChatCompletionEvaluator
      # Maintain backward compatibility with old compatible_with method
      def self.compatible_with
        [ PromptTracker::PromptVersion ]
      end
    end
  end
end
