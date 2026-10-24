module EngAssets
  module Helpers
    def self.define_importmap_helper(name)
      define_method("#{name.tr('-', '_')}_javascript_importmap_tags") do |entry_point = nil|
        engine_javascript_importmap_tags(name, entry_point)
      end
    end

    # engine_javascript_importmap_tags "admin"                  # entry "admin/application"
    # engine_javascript_importmap_tags "admin", "admin/other"
    def engine_javascript_importmap_tags(engine, entry_point = nil)
      javascript_importmap_tags(entry_point || EngAssets.default_entry(engine),
                                importmap: EngAssets.importmap_for(engine))
    end

    # engine_stylesheet_link_tags "my_engine", :all
    # engine_stylesheet_link_tags "my_engine", "buttons", "forms"
    def engine_stylesheet_link_tags(prefix, *sources, **options)
      names = sources.include?(:all) ? engine_stylesheet_paths(prefix) : sources.map { |s| "#{prefix}/#{s}" }
      stylesheet_link_tag(*names, **options)
    end

    private

    def engine_stylesheet_paths(prefix)
      if defined?(Propshaft)
        Rails.application.assets.load_path.assets
          .map { |asset| asset.logical_path.to_s }
          .select { |path| path.start_with?("#{prefix}/") && path.end_with?(".css") }
          .sort
      else
        sprockets_stylesheet_paths(prefix)
      end
    end

    # Precompiled manifest first (the source tree may be absent in production),
    # then the asset search paths. Sprockets resolves and digests the names itself.
    def sprockets_stylesheet_paths(prefix)
      manifest = Rails.application.respond_to?(:assets_manifest) ? Rails.application.assets_manifest : nil
      listed = manifest ? manifest.assets.keys.select { |k| k.start_with?("#{prefix}/") && k.end_with?(".css") } : []
      return listed.sort unless listed.empty?

      Rails.application.config.assets.paths
        .flat_map { |dir| Dir[File.join(dir.to_s, prefix, "*.css")] }
        .map { |f| "#{prefix}/#{File.basename(f)}" }
        .uniq.sort
    end
  end
end
