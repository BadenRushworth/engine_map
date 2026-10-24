require "bundler/setup"

require "bundler/gem_tasks"

namespace :test do
  desc "Run the suite under Propshaft and Sprockets"
  task :pipelines do
    [ "Gemfile", "gemfiles/sprockets.gemfile" ].each do |gemfile|
      puts "\n== #{gemfile} =="
      system({ "BUNDLE_GEMFILE" => gemfile }, "bin/test") || abort("failed under #{gemfile}")
    end
  end
end
