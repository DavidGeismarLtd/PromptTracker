require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

load "rails/tasks/statistics.rake"

require "bundler/gem_tasks"

# Load RSpec tasks
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# Make spec the default task
task default: :spec

# Override db:seed to run in dummy app context
namespace :db do
  desc "Load the seed data from db/seeds.rb in the dummy app"
  task :seed do
    Dir.chdir("test/dummy") do
      sh "bin/rails db:seed"
    end
  end
end
