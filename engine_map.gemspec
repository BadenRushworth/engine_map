require_relative "lib/engine_map/version"

Gem::Specification.new do |spec|
  spec.name        = "engine_map"
  spec.version     = EngineMap::VERSION
  spec.authors     = [ "Baden" ]
  spec.email       = [ "baden.rushworth@gmail.com" ]
  spec.homepage    = "https://github.com/BadenRushworth/engine_map"
  spec.summary     = "Asset helpers and an install generator for Rails engines."
  spec.description = "Stylesheet :all helper, merged or independent importmaps, and namespaced " \
                     "Stimulus controllers for Rails engines, on Propshaft or Sprockets, " \
                     "with an idempotent install generator that backs up what it edits."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"]          = spec.homepage
  spec.metadata["source_code_uri"]       = spec.homepage
  spec.metadata["changelog_uri"]         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "railties", ">= 8.0"
end
