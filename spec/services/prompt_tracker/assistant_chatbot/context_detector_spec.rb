# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::AssistantChatbot::ContextDetector do
  describe ".suggestions_for" do
    it "includes Deploy Agent on prompt version detail pages" do
      suggestions = described_class.suggestions_for(page_type: :prompt_version_detail)

      expect(suggestions).to include("Deploy Agent")
    end

    it "keeps general prompt-version test suggestions" do
      suggestions = described_class.suggestions_for(page_type: :prompt_version_detail)

      expect(suggestions).to include("Write tests for this prompt", "Run all tests")
    end
  end
end
