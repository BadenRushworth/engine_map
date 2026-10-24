module EngineMap
  module Generators
    Target = Struct.new(:name, :root, :namespace, :host, keyword_init: true) do
      def label = host ? "#{name} (host app)" : name
    end

    class EnginePicker
      def initialize(engines, app: nil, gem_paths: Gem.path, cwd: Dir.pwd, all: false)
        @engines = engines
        @app = app
        @gem_paths = gem_paths.map { |p| File.expand_path(p) }
        @cwd = File.expand_path(cwd)
        @all = all
      end

      def targets
        @targets ||= begin
          list = @engines.reject { |e| !@all && installed_gem?(e.root) }.map { |e| build(e) }
          list.unshift(build(@app, host: true)) if @app
          list.uniq { |t| t.root.to_s }
        end
      end

      # The target containing the current directory, if any.
      def default
        targets.select { |t| inside?(@cwd, t.root) }.max_by { |t| t.root.to_s.length }
      end

      def find(name)
        targets.find { |t| t.name == name.to_s || t.namespace == name.to_s }
      end

      private

      def build(engine, host: false)
        klass = engine.class
        name = host ? klass.module_parent_name.to_s.underscore : EngineMap.name_for(klass)
        namespace = klass.railtie_namespace&.name || name.camelize
        Target.new(name: name, root: Pathname.new(engine.root.to_s), namespace: namespace, host: host)
      end

      def installed_gem?(root)
        @gem_paths.any? { |p| root.to_s.start_with?("#{p}/") }
      end

      def inside?(dir, root)
        dir == root.to_s || dir.start_with?("#{root}/")
      end
    end
  end
end
