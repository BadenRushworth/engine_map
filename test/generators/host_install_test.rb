require "test_helper"
require "rails/generators/test_case"
require "generators/engine_map/install/install_generator"

HOST_DEST = File.expand_path("../tmp/install_host", __dir__)

class FakeHostInstall < EngineMap::Generators::InstallGenerator
  source_root EngineMap::Generators::InstallGenerator.source_root

  private

  def candidates = []

  def app
    klass = Class.new do
      define_singleton_method(:engine_name) { "host_app" }
      define_singleton_method(:railtie_namespace) { nil }
      define_singleton_method(:module_parent_name) { "HostApp" }
    end
    klass.new.tap { |e| e.define_singleton_method(:root) { Pathname.new(HOST_DEST) } }
  end
end

class HostInstallTest < Rails::Generators::TestCase
  tests FakeHostInstall
  destination HOST_DEST
  setup :prepare_destination

  JS = "app/javascript/application.js".freeze
  LAYOUT = "app/views/layouts/application.html.erb".freeze
  MANIFEST = "app/assets/config/manifest.js".freeze

  setup do
    FileUtils.mkdir_p File.join(HOST_DEST, "app/javascript")
    FileUtils.mkdir_p File.join(HOST_DEST, "app/views/layouts")
    File.write File.join(HOST_DEST, JS), %(import "@hotwired/turbo-rails"\nimport "controllers"\n)
    File.write File.join(HOST_DEST, LAYOUT), "<head>\n  <%= javascript_importmap_tags %>\n</head>\n"
    FileUtils.mkdir_p File.join(HOST_DEST, "app/assets/config")
    File.write File.join(HOST_DEST, MANIFEST), "//= link_tree ../../javascript .js\n"
    @saved = EngineMap.configured.dup
    EngineMap.configured.replace("sample_engine" => :merge, "own_only" => :own)
  end

  teardown { EngineMap.configured.replace(@saved) }

  test "imports merge-mode engines only" do
    run_generator %w[--engine host_app]
    assert_file JS, /import "sample_engine\/application"/
    refute_match(/own_only/, File.read(File.join(HOST_DEST, JS)))
  end

  test "second run changes nothing and says so" do
    run_generator %w[--engine host_app]
    out = run_generator %w[--engine host_app]
    assert_match(/already set up/, out)
    assert_equal 1, File.read(File.join(HOST_DEST, JS)).scan("sample_engine/application").size
  end

  test "layout without importmap tags needs a manual step" do
    File.write File.join(HOST_DEST, LAYOUT), "<head>\n</head>\n"
    out = run_generator %w[--engine host_app]
    assert_match(/manual.*javascript_importmap_tags/, out)
    refute_match(/already set up|Install complete/, out)
  end

  test "import goes after the last existing import, not above comments" do
    File.write File.join(HOST_DEST, JS), %(// header comment\nimport "a"\nimport "b"\n// trailing\n)
    run_generator %w[--engine host_app]
    assert_file JS, /\A\/\/ header comment\nimport "a"\nimport "b"\nimport "sample_engine\/application"\n\/\/ trailing/
  end

  test "file with no imports gets the line at the top" do
    File.write File.join(HOST_DEST, JS), "// nothing here\n"
    run_generator %w[--engine host_app]
    assert_file JS, /\Aimport "sample_engine\/application"/
  end

  test "sprockets host whose manifest does not link javascript gets the links injected" do
    skip "Sprockets only" if defined?(Propshaft)
    File.write File.join(HOST_DEST, MANIFEST), "//= link_directory ../stylesheets .css\n"
    run_generator %w[--engine host_app]
    assert_file MANIFEST, /link_tree \.\.\/\.\.\/javascript \.js/
  end

  test "sprockets host with no manifest needs a manual step" do
    skip "Sprockets only" if defined?(Propshaft)
    FileUtils.rm_f File.join(HOST_DEST, MANIFEST)
    out = run_generator %w[--engine host_app]
    assert_match(/manual.*manifest\.js/, out)
    refute_match(/already set up|Install complete/, out)
  end
end
