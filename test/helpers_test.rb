require "test_helper"
require "tmpdir"

class HelpersTest < ActiveSupport::TestCase
  def h = ActionController::Base.helpers

  test "stylesheet :all finds the engine's css with digests" do
    assert_match %r{/assets/sample_engine/base-\w+\.css}, h.engine_stylesheet_link_tags("sample_engine", :all)
  end

  test "stylesheet :all ignores other prefixes" do
    assert_empty h.send(:engine_stylesheet_paths, "nope")
  end

  test "merged map includes host and engine pins" do
    html = h.javascript_importmap_tags
    assert_includes html, "sample_engine/application"
    assert_includes html, "@hotwired/stimulus"
  end

  test "own map contains only the engine's pins" do
    html = h.sample_engine_javascript_importmap_tags
    assert_includes html, "sample_engine/application"
    refute_includes html, "@hotwired"
  end

  test "unknown engine raises a helpful error" do
    error = assert_raises(ArgumentError) { EngineMap.importmap_for("nope") }
    assert_includes error.message, "sample_engine"
  end

  test "engine-only entry is standalone only when the engine pins it" do
    Dir.mktmpdir do |dir|
      plain = Pathname.new(dir).join("plain.rb")
      own = Pathname.new(dir).join("own.rb")
      plain.write(%(pin "plain_x/application"\n))
      own.write(%(pin "own_x/standalone"\n))
      EngineMap.register("plain_x", root: dir, importmap: plain)
      EngineMap.register("own_x", root: dir, importmap: own)
      assert_equal "plain_x/application", EngineMap.default_entry("plain_x")
      assert_equal "own_x/standalone", EngineMap.default_entry("own_x")
    end
  end
end
