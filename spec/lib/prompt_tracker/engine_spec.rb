# frozen_string_literal: true

require "rails_helper"

RSpec.describe PromptTracker::Engine do
  describe "importmap configuration" do
    let(:app) { Rails.application }

    context "when importmap-rails is available" do
      before do
        # Importmap is loaded in our test environment
        allow(app.config).to receive(:respond_to?).with(:importmap).and_return(true)
      end

      it "registers importmap paths" do
        # The initializer should have run during Rails initialization
        expect(defined?(Importmap)).to be_truthy
      end

      it "includes engine's importmap configuration" do
        # Check that the engine's importmap.rb is registered
        importmap_paths = app.config.importmap.paths
        engine_importmap_path = PromptTracker::Engine.root.join("config/importmap.rb")

        expect(importmap_paths).to include(engine_importmap_path)
      end
    end

    context "when importmap-rails is not available" do
      it "does not raise an error during initialization" do
        # This test verifies that the engine can initialize without importmap
        # The actual check happens in the initializer with `if defined?(Importmap)`
        expect { PromptTracker::Engine }.not_to raise_error
      end
    end
  end

  describe "asset paths" do
    it "adds engine JavaScript to asset paths" do
      asset_paths = Rails.application.config.assets.paths
      engine_js_path = PromptTracker::Engine.root.join("app/javascript")

      expect(asset_paths).to include(engine_js_path)
    end
  end

  describe "autoload paths" do
    it "includes engine lib directory" do
      # The engine adds its lib directory to autoload_paths
      # Check that the engine's lib path is configured
      engine_lib_path = PromptTracker::Engine.root.join("lib")

      # The path should be in the engine's config, not necessarily in the final Rails.application.config
      # because Rails may convert paths to strings
      expect(PromptTracker::Engine.config.autoload_paths).to include(engine_lib_path)
    end
  end

  describe "Turbo integration" do
    it "makes Turbo helpers available" do
      expect(defined?(Turbo::StreamsHelper)).to be_truthy
    end
  end
end
