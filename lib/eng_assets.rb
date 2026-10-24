require "eng_assets/version"
require "eng_assets/helpers"
require "eng_assets/railtie"

module EngAssets
  Registration = Struct.new(:name, :root, :importmap_path, keyword_init: true)

  class << self
    def registry
      @registry ||= {}
    end

    # EngAssets.register "admin", root: Admin::Engine.root
    def register(name, root:, importmap: nil)
      name = name.to_s
      root = Pathname.new(root)
      registry[name] = Registration.new(
        name: name, root: root,
        importmap_path: Pathname.new(importmap || root.join("config/importmap.rb"))
      )
      Helpers.define_importmap_helper(name)
      registry[name]
    end

    # Isolated engines keep their name (it matches their asset folder).
    # Plain engines lose the "_engine" suffix Rails appends.
    def name_for(engine_class)
      base = engine_class.engine_name.to_s
      engine_class.railtie_namespace ? base : base.delete_suffix("_engine")
    end

    # Called from an engine class body:
    #   EngAssets.configure(self)                    # merge into host importmap (default)
    #   EngAssets.configure(self, importmap: :own)   # independent map
    #   EngAssets.configure(self, importmap: :both)
    # The name is resolved inside initializers, after the class body (and
    # isolate_namespace) has run.
    def configure(engine, importmap: :merge, name: nil)
      unless %i[merge own both].include?(importmap)
        raise ArgumentError, "importmap must be :merge, :own or :both (got #{importmap.inspect})"
      end
      id = engine.name

      engine.initializer "eng_assets.assets.#{id}" do |app|
        js = engine.root.join("app/javascript")
        app.config.assets.paths << js.to_s if app.config.respond_to?(:assets) && js.exist?
      end

      # Sprockets only serves what is listed for precompile. Propshaft needs nothing.
      engine.initializer "eng_assets.precompile.#{id}", after: "eng_assets.assets.#{id}" do |app|
        next if defined?(Propshaft) || !app.config.respond_to?(:assets) || !app.config.assets.respond_to?(:precompile)
        EngAssets.sprockets_logical_names(engine.root, name || EngAssets.name_for(engine)).each do |logical|
          app.config.assets.precompile << logical
        end
      end

      # Make importmap-rails notice new or changed engine JS (host sweeper only
      # watches the host's folders). Must run before importmap builds its watcher.
      engine.initializer "eng_assets.sweeper.#{id}", before: "importmap.cache_sweeper" do |app|
        js = engine.root.join("app/javascript")
        if EngAssets.reloading?(app) && js.exist? && app.config.respond_to?(:importmap)
          app.config.importmap.cache_sweepers << js
        end
      end

      if %i[merge both].include?(importmap)
        engine.initializer "eng_assets.importmap_merge.#{id}", before: "importmap" do |app|
          file = engine.root.join("config/importmap.rb")
          app.config.importmap.paths << file if file.exist? && app.config.respond_to?(:importmap)
        end
      end

      if %i[own both].include?(importmap)
        engine.initializer "eng_assets.importmap_own.#{id}" do
          EngAssets.register(name || EngAssets.name_for(engine), root: engine.root,
                             importmap: engine.root.join("config/importmap.rb"))
        end
      end
    end

    # Logical names (e.g. "admin/base.css") of an engine's own assets, for
    # config.assets.precompile. Sprockets needs plain strings, not globs or procs.
    def sprockets_logical_names(root, name)
      css = Dir[root.join("app/assets/stylesheets", name, "*.css")].map { |f| "#{name}/#{File.basename(f)}" }
      js = Dir[root.join("app/javascript", name, "**/*.js")].map do |f|
        f.delete_prefix("#{root.join('app/javascript')}/")
      end
      css + js
    end

    # Entry point the engine-only helper imports. Engines with their own
    # Stimulus app pin "<name>/standalone"; everyone else uses application.
    def default_entry(name)
      file = registry.fetch(name.to_s).importmap_path
      standalone = file.exist? && file.read.include?(%(pin "#{name}/standalone"))
      standalone ? "#{name}/standalone" : "#{name}/application"
    end

    def reloading?(app = Rails.application)
      app.config.respond_to?(:reloading_enabled?) && app.config.reloading_enabled?
    end

    def importmap_for(name)
      watchers[name.to_s]&.execute_if_updated
      registration = registry.fetch(name.to_s) do
        raise ArgumentError, "No engine registered as #{name.inspect}. Registered: #{registry.keys.inspect}"
      end
      maps[registration.name] ||= build_map(registration).tap { watch(registration) }
    end

    private

    def watchers
      @watchers ||= {}
    end

    # Dev only: drop the cached map when the engine's importmap file or JS changes.
    def watch(registration)
      return unless reloading?
      dirs = [registration.root.join("app/javascript")].select(&:exist?).to_h { |d| [d.to_s, ["js"]] }
      watchers[registration.name] = Rails.application.config.file_watcher.new([registration.importmap_path.to_s], dirs) do
        maps.delete(registration.name)
      end
    end

    def maps
      @maps ||= {}
    end

    def build_map(registration)
      unless defined?(Importmap::Map)
        raise LoadError, "importmap-rails is required for #{registration.name}_javascript_importmap_tags"
      end
      Importmap::Map.new.tap { |map| map.draw(registration.importmap_path) }
    end
  end
end
