require "test_helper"

class NameTest < ActiveSupport::TestCase
  def fake(name, namespace)
    Class.new do
      define_singleton_method(:engine_name) { name }
      define_singleton_method(:railtie_namespace) { namespace }
    end
  end

  test "plain engines lose the suffix Rails added" do
    assert_equal "sample_engine", EngineMap.name_for(fake("sample_engine_engine", nil))
  end

  test "isolated engines keep their name" do
    assert_equal "scratch_engine", EngineMap.name_for(fake("scratch_engine", Module.new))
    assert_equal "admin", EngineMap.name_for(fake("admin", Module.new))
  end
end
