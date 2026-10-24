module EngAssets
  class Railtie < ::Rails::Railtie
    initializer "eng_assets.helpers" do
      ActiveSupport.on_load(:action_view) { include EngAssets::Helpers }
    end
  end
end
