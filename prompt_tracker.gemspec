require_relative "lib/prompt_tracker/version"

Gem::Specification.new do |spec|
  spec.name        = "prompt_tracker"
  spec.version     = PromptTracker::VERSION
  spec.authors     = [ "David Geismar" ]
  spec.email       = [ "davidgeismar@yunoo.io" ]
  spec.homepage    = "TODO"
  spec.summary     = "TODO: Summary of PromptTracker."
  spec.description = "TODO: Description of PromptTracker."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.2.3"
  spec.add_dependency "kaminari", "~> 1.2"
  spec.add_dependency "groupdate", "~> 6.0"
  spec.add_dependency "liquid", "~> 5.5"
  spec.add_dependency "importmap-rails"
  spec.add_dependency "turbo-rails"
  spec.add_dependency "stimulus-rails"
end
