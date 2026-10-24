module SampleEngine
  class Engine < ::Rails::Engine
    EngineMap.configure(self, importmap: :both)
  end
end
