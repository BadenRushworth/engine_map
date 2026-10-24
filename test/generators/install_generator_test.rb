require "test_helper"
require "rails/generators/test_case"
require "generators/engine_map/install/install_generator"

DEST = File.expand_path("../tmp/install", __dir__)

class FakeInstall < EngineMap::Generators::InstallGenerator
  source_root EngineMap::Generators::InstallGenerator.source_root
  private

  def app = nil

  def candidates
    klass = Class.new do
      define_singleton_method(:engine_name) { "sample_engine_engine" }
      define_singleton_method(:railtie_namespace) { nil }
    end
    [klass.new.tap { |e| e.define_singleton_method(:root) { Pathname.new(DEST) } }]
  end
end

class InstallGeneratorTest < Rails::Generators::TestCase
  tests FakeInstall
  destination DEST
  setup :prepare_destination
  setup :build_engine

  def build_engine
    File.write File.join(DEST, "sample_engine.gemspec"),
               "Gem::Specification.new do |spec|\n  spec.add_dependency \"rails\"\nend\n"
    FileUtils.mkdir_p File.join(DEST, "lib")
    FileUtils.mkdir_p File.join(DEST, "app/views/layouts/sample_engine")
    File.write File.join(DEST, "lib/sample_engine.rb"),
               "module SampleEngine\n  class Engine < ::Rails::Engine\n  end\nend\n"
    File.write File.join(DEST, "app/views/layouts/sample_engine/application.html.erb"),
               "<head>\n  <%= stylesheet_link_tag \"sample_engine/application\" %>\n  <%= javascript_importmap_tags %>\n</head>\n"
  end

  LAYOUT = "app/views/layouts/sample_engine/application.html.erb".freeze

  test "merge mode wires everything and backs up the replaced stylesheet tag" do
    run_generator %w[--engine sample_engine]
    assert_file "lib/sample_engine.rb", /EngineMap\.configure\(self\)/
    assert_file LAYOUT, /engine_stylesheet_link_tags "sample_engine", :all/
    assert_file LAYOUT, /javascript_import_module_tag "sample_engine\/application"/
    assert_file "config/importmap.rb", /pin "sample_engine\/application"/
    assert_file "app/javascript/sample_engine/application.js"
    assert_file "#{LAYOUT}.backup", /stylesheet_link_tag "sample_engine\/application"/
  end

  test "own mode swaps the importmap tag and backs up the layout" do
    run_generator %w[--engine sample_engine --importmap own]
    assert_file "lib/sample_engine.rb", /importmap: :own/
    assert_file LAYOUT, /sample_engine_javascript_importmap_tags/
    assert_file "#{LAYOUT}.backup", /<%= javascript_importmap_tags %>/
  end

  test "running twice changes nothing the second time" do
    run_generator %w[--engine sample_engine]
    first = File.read(File.join(DEST, LAYOUT))
    run_generator %w[--engine sample_engine]
    assert_equal first, File.read(File.join(DEST, LAYOUT))
    assert_equal 1, File.read(File.join(DEST, "lib/sample_engine.rb")).scan("EngineMap.configure").size
  end

  test "unknown engine name prints an error and changes nothing" do
    err = capture(:stderr) { run_generator %w[--engine nope] }
    assert_match(/No engine named "nope"/, err)
    assert_no_file "config/importmap.rb"
  end

  test "stimulus host pins namespaced controllers and adds no standalone entry" do
    run_generator %w[--engine sample_engine]
    assert_file "config/importmap.rb", /under: "controllers\/sample_engine"/
    assert_file "app/javascript/sample_engine/controllers/example_controller.js", /sample-engine--example/
    assert_no_file "app/javascript/sample_engine/standalone.js"
  end

  test "stimulus own adds the standalone entry and stimulus pins" do
    run_generator %w[--engine sample_engine --stimulus own]
    assert_file "app/javascript/sample_engine/standalone.js", /Application\.start\(\)/
    assert_file "config/importmap.rb", /pin "sample_engine\/standalone"/
    assert_file "config/importmap.rb", /stimulus-loading/
  end

  test "stimulus none adds no controllers" do
    run_generator %w[--engine sample_engine --stimulus none]
    assert_no_file "app/javascript/sample_engine/controllers/example_controller.js"
    assert_file "config/importmap.rb", /pin "sample_engine\/application"/
  end

  test "engine file requires the gem and the gemspec depends on it" do
    File.write File.join(DEST, "sample_engine.gemspec"),
               "Gem::Specification.new do |spec|\n  spec.add_dependency \"rails\"\nend\n"
    run_generator %w[--engine sample_engine]
    assert_file "lib/sample_engine.rb", /\Arequire "engine_map"\n/
    assert_file "sample_engine.gemspec", /spec\.add_dependency "engine_map"/
  end

  test "layout without importmap tags gets them before </head>" do
    File.write File.join(DEST, LAYOUT), "<head>\n  <%= stylesheet_link_tag \"x\" %>\n</head>\n"
    out = capture(:stdout) { run_generator %w[--engine sample_engine] }
    refute_match(/manual/, out)
    assert_file LAYOUT, /javascript_importmap_tags %>\n\s*<%= javascript_import_module_tag "sample_engine\/application"/
    assert_file LAYOUT, /<\/head>/
  end

  test "engine's own stylesheet tag is replaced, not duplicated" do
    run_generator %w[--engine sample_engine]
    layout = File.read(File.join(DEST, LAYOUT))
    refute_match(/<%= stylesheet_link_tag/, layout)
    assert_equal 1, layout.scan("engine_stylesheet_link_tags").size
  end

  test "starter stylesheet is created but never overwritten" do
    css = "app/assets/stylesheets/sample_engine/application.css"
    FileUtils.mkdir_p File.dirname(File.join(DEST, css))
    File.write File.join(DEST, css), "body { margin: 0 }\n"
    run_generator %w[--engine sample_engine]
    assert_file css, "body { margin: 0 }\n"
  end

  test "starter stylesheet is created when missing" do
    run_generator %w[--engine sample_engine]
    assert_file "app/assets/stylesheets/sample_engine/application.css", /engine_stylesheet_link_tags "sample_engine"/
  end

  test "first run says complete, second run says already set up" do
    first = run_generator %w[--engine sample_engine]
    assert_match(/Install complete/, first)
    second = run_generator %w[--engine sample_engine]
    assert_match(/already set up/, second)
    refute_match(/Install complete/, second)
  end

  test "manual steps suppress the all-done message" do
    FileUtils.rm_f File.join(DEST, LAYOUT)
    out = run_generator %w[--engine sample_engine]
    refute_match(/already set up|Install complete/, out)
  end

  test "second run reports each file as identical only once" do
    run_generator %w[--engine sample_engine]
    out = run_generator %w[--engine sample_engine]
    assert_equal 1, out.scan("identical  #{LAYOUT}").size
  end

  test "both mode creates a standalone layout, merge mode does not" do
    run_generator %w[--engine sample_engine --importmap both]
    assert_file "app/views/layouts/sample_engine/standalone.html.erb", /sample_engine_javascript_importmap_tags/
    assert_file "app/views/layouts/sample_engine/standalone.html.erb", /engine_stylesheet_link_tags "sample_engine", :all/
  end

  test "merge mode adds no standalone layout" do
    run_generator %w[--engine sample_engine]
    assert_no_file "app/views/layouts/sample_engine/standalone.html.erb"
  end

  test "missing layout prints own-mode tags when installing in own mode" do
    FileUtils.rm_f File.join(DEST, LAYOUT)
    out = run_generator %w[--engine sample_engine --importmap own]
    assert_match(/sample_engine_javascript_importmap_tags/, out)
    refute_match(/javascript_import_module_tag/, out)
  end
end
