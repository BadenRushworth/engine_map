module SampleEngine
  class Engine < ::Rails::Engine
    EngAssets.configure(self, importmap: :both)
  end
end
