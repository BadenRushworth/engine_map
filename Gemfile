source "https://rubygems.org"

# Specify your gem's dependencies in engine_map.gemspec.
gemspec

gem "puma"

gem "sqlite3"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

# Termux-specific additions
gem "tzinfo-data"
gem "nokogiri", "1.18.10"

# Dummy app / test dependencies (not runtime deps of the gem)
gem "rails"
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

group :test do
  gem "simplecov", require: false
end
