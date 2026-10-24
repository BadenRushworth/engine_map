require "test_helper"
require "engine_map/generators/engine_picker"

class EnginePickerTest < ActiveSupport::TestCase
  Fake = Struct.new(:root)

  def make_engine(name, root, namespace: nil)
    klass = Class.new do
      define_singleton_method(:engine_name) { name }
      define_singleton_method(:railtie_namespace) { namespace }
      define_singleton_method(:module_parent_name) { name.camelize }
    end
    klass.new.tap { |e| e.define_singleton_method(:root) { Pathname.new(root) } }
  end

  def picker(**opts)
    engines = [make_engine("admin_engine", "/work/admin"),
               make_engine("turbo", "/gems/turbo-rails-2.0")]
    EngineMap::Generators::EnginePicker.new(engines, app: make_engine("host", "/work/host"),
                                            gem_paths: ["/gems"], cwd: "/work/admin/lib", **opts)
  end

  test "hides installed gems by default, host app listed first" do
    assert_equal %w[host admin], picker.targets.map(&:name)
    assert picker.targets.first.host
  end

  test "--all includes installed gems" do
    assert_includes picker(all: true).targets.map(&:name), "turbo"
  end

  test "default is the target containing the current directory" do
    assert_equal "admin", picker.default.name
  end

  test "default is nil outside every target" do
    assert_nil picker(cwd: "/elsewhere").default
  end

  test "find by name or namespace" do
    assert_equal "admin", picker.find("admin").name
    assert_equal "Admin", picker.find("Admin").namespace
    assert_nil picker.find("nope")
  end

  test "isolated engines keep the full name that matches their asset folder" do
    isolated = make_engine("scratch_engine", "/work/s", namespace: Struct.new(:name).new("ScratchEngine"))
    picker = EngineMap::Generators::EnginePicker.new([isolated], gem_paths: [], cwd: "/")
    assert_equal "scratch_engine", picker.targets.first.name
  end
end
