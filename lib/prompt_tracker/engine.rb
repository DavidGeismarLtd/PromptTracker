module PromptTracker
  class Engine < ::Rails::Engine
    isolate_namespace PromptTracker


    initializer "prompt_tracker.assets.precompile" do |app|
      app.config.assets.precompile += %w[
        prompt_tracker/application.js
        prompt_tracker/application.css
        prompt_tracker/controllers/application.js
        prompt_tracker/controllers/index.js
        prompt_tracker/controllers/playground_controller.js
        prompt_tracker/controllers/modal_fix_controller.js
        prompt_tracker/controllers/tooltip_controller.js
      ]
    end
    # # Make engine JS available to Sprockets (so importmap can find it)
    initializer "prompt_tracker.assets" do |app|
      app.config.assets.paths << root.join("app/javascript")
    end
    # Register importmap configuration
    initializer "prompt_tracker.importmap", before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/importmap.rb")
      # Add cache sweeper for development
      app.config.importmap.cache_sweepers << root.join("app/javascript")
    end



    # Include Turbo for real-time updates
    config.to_prepare do
      # Make Turbo helpers available in the engine
      ActiveSupport.on_load(:action_controller_base) do
        helper Turbo::StreamsHelper if defined?(Turbo::StreamsHelper)
      end
    end
  end
end
