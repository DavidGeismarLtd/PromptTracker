require_relative "boot"

require "rails/all"

# Fix for Sidekiq 7.3.9 - must be loaded after rails/all but before Bundler.require
# See: https://github.com/sidekiq/sidekiq/issues/6668
require "sidekiq/rails"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load environment variables from the engine root (not dummy app root)
if defined?(Dotenv)
  engine_root = File.expand_path("../../..", __dir__)
  Dotenv.load(
    File.join(engine_root, ".env.#{Rails.env}.local"),
    File.join(engine_root, ".env.local"),
    File.join(engine_root, ".env.#{Rails.env}"),
    File.join(engine_root, ".env")
  )
end

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    # For compatibility with applications that use this config
    config.action_controller.include_all_helpers = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configure ActiveJob to use Sidekiq
    config.active_job.queue_adapter = :sidekiq

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
