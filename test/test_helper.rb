require "simplecov"
SimpleCov.start do
  skip "/test/"
  enable_coverage :branch
end

ENV["RAILS_ENV"] = "test"
require_relative "dummy/config/environment"
require "rails/test_help"
