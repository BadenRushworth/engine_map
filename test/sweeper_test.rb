require "test_helper"
require "tmpdir"

class SweeperTest < ActiveSupport::TestCase
  setup do
    @config = Rails.application.config
    @config.singleton_class.send(:define_method, :reloading_enabled?) { true }
  end

  teardown do
    @config.singleton_class.send(:remove_method, :reloading_enabled?)
  end

  test "own map rebuilds after the engine's importmap file changes" do
    Dir.mktmpdir do |dir|
      file = Pathname.new(dir).join("importmap.rb")
      file.write(%(pin "sweep_x/application"\n))
      # Rails' watcher ignores mtimes in the future, so work in the past.
      File.utime(Time.now - 60, Time.now - 60, file.to_s)
      EngineMap.register("sweep_x", root: dir, importmap: file)

      first = EngineMap.importmap_for("sweep_x")
      assert_same first, EngineMap.importmap_for("sweep_x")

      file.write(%(pin "sweep_x/application"\npin "sweep_x/extra"\n))
      File.utime(Time.now - 30, Time.now - 30, file.to_s)

      refute_same first, EngineMap.importmap_for("sweep_x")
    end
  end
end
