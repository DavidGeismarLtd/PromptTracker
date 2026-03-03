# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::UrlHelper, type: :helper do
  # Include the helper module
  include PromptTracker::UrlHelper

  describe "#engine_path" do
    context "without url_options_provider configured" do
      before do
        PromptTracker.configuration.url_options_provider = nil
      end

      it "generates a path without additional options" do
        path = engine_path(:testing_root_path)
        expect(path).to eq("/prompt_tracker/testing")
      end
    end

    context "with url_options_provider configured" do
      before do
        PromptTracker.configuration.url_options_provider = -> {
          { org_slug: "test-org" }
        }
      end

      after do
        PromptTracker.configuration.url_options_provider = nil
      end

      it "merges url_options_provider options into the path" do
        path = engine_path(:testing_root_path)
        expect(path).to include("org_slug=test-org").or include("/test-org/")
      end
    end

    context "with additional options passed" do
      before do
        PromptTracker.configuration.url_options_provider = -> {
          { org_slug: "test-org" }
        }
      end

      after do
        PromptTracker.configuration.url_options_provider = nil
      end

      it "merges both provider and passed options" do
        path = engine_path(:testing_root_path, { format: :json })
        expect(path).to include(".json")
      end
    end
  end

  describe "#url_options_from_provider" do
    context "when provider returns nil" do
      before do
        PromptTracker.configuration.url_options_provider = -> { nil }
      end

      after do
        PromptTracker.configuration.url_options_provider = nil
      end

      it "returns an empty hash" do
        expect(send(:url_options_from_provider)).to eq({})
      end
    end

    context "when no provider configured" do
      before do
        PromptTracker.configuration.url_options_provider = nil
      end

      it "returns an empty hash" do
        expect(send(:url_options_from_provider)).to eq({})
      end
    end

    context "when provider returns options" do
      before do
        PromptTracker.configuration.url_options_provider = -> {
          { org_slug: "my-org", locale: "en" }
        }
      end

      after do
        PromptTracker.configuration.url_options_provider = nil
      end

      it "returns the options from the provider" do
        expect(send(:url_options_from_provider)).to eq({ org_slug: "my-org", locale: "en" })
      end
    end
  end
end
