module EngineMap
  class Railtie < ::Rails::Railtie
    initializer "engine_map.helpers" do
      ActiveSupport.on_load(:action_view) { include EngineMap::Helpers }
    end
  end
end
