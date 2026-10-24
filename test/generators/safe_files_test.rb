require "test_helper"
require "rails/generators/test_case"
require "engine_map/generators/safe_files"

class SafeFilesGenerator < Rails::Generators::Base
  include EngineMap::Generators::SafeFiles
  source_root File.expand_path("../fixtures/templates", __dir__)
end

class SafeFilesTest < Rails::Generators::TestCase
  tests SafeFilesGenerator
  destination File.expand_path("../tmp/safe_files", __dir__)
  setup :prepare_destination

  def gen = generator
  def write(path, body) = File.write(File.join(destination_root, path), body)

  test "inject adds text after the anchor" do
    write "a.txt", "one\ntwo\n"
    quietly { assert gen.safe_inject("a.txt", "  added", after: "one") }
    assert_file "a.txt", /one\n  added\ntwo/
  end

  test "inject twice does not duplicate" do
    write "a.txt", "one\n"
    quietly { gen.safe_inject("a.txt", "x", after: "one") }
    quietly { refute gen.safe_inject("a.txt", "x", after: "one") }
    assert_equal 1, File.read(File.join(destination_root, "a.txt")).scan("x").size
  end

  test "missing anchor changes nothing and prints the manual step" do
    write "a.txt", "one\n"
    out = capture(:stdout) { refute gen.safe_inject("a.txt", "needle", after: "nope") }
    assert_match(/manual/, out)
    assert_match(/needle/, out)
    assert_file "a.txt", "one\n"
  end

  test "missing file prints the manual step" do
    out = capture(:stdout) { refute gen.safe_inject("gone.txt", "x", after: "y") }
    assert_match(/file not found/, out)
  end

  test "replace makes a backup first" do
    write "a.txt", "color: red\n"
    quietly { assert gen.safe_replace("a.txt", /red/, "blue") }
    assert_file "a.txt", /blue/
    assert_file "a.txt.backup", /red/
  end

  test "backups are never overwritten" do
    write "a.txt", "red\n"
    quietly { gen.safe_replace("a.txt", /red/, "blue") }
    quietly { gen.safe_replace("a.txt", /blue/, "green") }
    assert_file "a.txt.backup", /red/
    assert_file "a.txt.backup.1", /blue/
  end

  private

  def quietly(&block) = capture(:stdout, &block)
end
