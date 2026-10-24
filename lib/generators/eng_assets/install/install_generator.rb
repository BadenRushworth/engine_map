require "rails/generators"
require "digest"
require "eng_assets/generators/safe_files"
require "eng_assets/generators/engine_picker"

module EngAssets
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include SafeFiles
      source_root File.expand_path("templates", __dir__)
      desc "Set up engine asset helpers (stylesheets and importmap) in an engine."

      ENGINE_CLASS = /class \w+ < (::)?Rails::Engine/
      IMPORTMAP_TAGS = /<%= javascript_importmap_tags[^%]*%>/
      STYLESHEET_TAG = /<%= stylesheet_link_tag [^%]*%>/

      class_option :engine, type: :string, desc: "Engine name (skips the prompt)"
      class_option :importmap, type: :string, default: "merge", enum: %w[merge own both],
                   desc: "merge into host importmap, own independent map, or both"
      class_option :stimulus, type: :string, default: "host", enum: %w[host own none],
                   desc: "host Stimulus app, engine's own Stimulus app, or no controllers"
      class_option :all, type: :boolean, default: false, desc: "Also list engines from installed gems"

      def choose_target
        picker = EnginePicker.new(candidates, app: app, all: options[:all])
        @target = options[:engine] ? picker.find(options[:engine]) : (picker.default || prompt_for(picker))
        raise Thor::Error, "No engine named #{options[:engine].inspect}. Try --all." unless @target

        self.destination_root = @target.root.to_s
        say_status :target, @target.label, :green
        @before = snapshot
      end

      def configure_engine
        return if host?
        file = engine_file
        return manual("lib/<engine>/engine.rb", configure_line, "engine class not found", :yellow) unless file
        safe_inject file, %(require "eng_assets"), before: /\A/
        return if File.read(File.join(destination_root, file)).include?("EngAssets.configure")

        safe_inject file, configure_line, after: ENGINE_CLASS
      end

      def add_gem_dependency
        return if host?
        spec = Dir[File.join(destination_root, "*.gemspec")].first
        return needs_manual("no gemspec found (add `spec.add_dependency \"eng_assets\"` by hand)") unless spec
        safe_inject relative(spec), %(  spec.add_dependency "eng_assets"), after: /^\s*spec\.add_dependency [^\n]*/
      end

      def create_javascript
        return if host?
        template "application.js.tt", "app/javascript/#{name}/application.js", skip: true
        unless stimulus == "none"
          template "example_controller.js.tt", "app/javascript/#{name}/controllers/example_controller.js", skip: true
        end
        template "standalone.js.tt", "app/javascript/#{name}/standalone.js", skip: true if stimulus == "own"
        if File.exist?(File.join(destination_root, "config/importmap.rb"))
          safe_inject "config/importmap.rb", importmap_lines, after: /\A[^\n]*/
        else
          template "importmap.rb.tt", "config/importmap.rb"
        end
      end

      def create_stylesheet
        return if host?
        template "application.css.tt", "app/assets/stylesheets/#{name}/application.css", skip: true
      end

      def create_standalone_layout
        return if host? || options[:importmap] != "both"
        template "standalone.html.erb.tt", "app/views/layouts/#{name}/standalone.html.erb", skip: true
      end

      def update_layout
        return if host?
        layout = layout_file
        unless layout
          needs_manual("no layout found (add these inside <head> of the layout your engine uses)")
          js = if options[:importmap] == "own"
                 %(    <%= #{name}_javascript_importmap_tags %>)
               else
                 %(    <%= javascript_importmap_tags %>\n    <%= javascript_import_module_tag "#{name}/application" %>)
               end
          say %(    <%= engine_stylesheet_link_tags "#{name}", :all %>\n#{js}), :cyan
          return
        end

        add_stylesheet_tag(layout)
        has_tags = File.read(File.join(destination_root, layout)).match?(IMPORTMAP_TAGS)
        if options[:importmap] == "own"
          if has_tags
            safe_replace layout, /(?<!\w)javascript_importmap_tags/, "#{name}_javascript_importmap_tags"
          else
            safe_inject layout, %(  <%= #{name}_javascript_importmap_tags %>), before: %r{^\s*</head>}
          end
        elsif has_tags
          safe_inject layout, %(    <%= javascript_import_module_tag "#{name}/application" %>), after: IMPORTMAP_TAGS
        else
          safe_inject layout, %(  <%= javascript_importmap_tags %>\n  <%= javascript_import_module_tag "#{name}/application" %>),
                      before: %r{^\s*</head>}
        end
      end

      def wire_host
        return unless host?
        layout = "app/views/layouts/application.html.erb"
        path = File.join(destination_root, layout)
        if File.exist?(path) && !File.read(path).match?(IMPORTMAP_TAGS)
          needs_manual("#{layout} has no javascript_importmap_tags (add it before </head>)")
        end
        check_sprockets_manifest
        import_configured_engines
      end

      # Must stay the last public method: Rails runs public methods in order.
      def finish
        if @manual_steps.to_i > 0
          say "\n#{@manual_steps} step(s) need a manual edit (see the 'manual' lines above).", :yellow
        elsif snapshot == @before
          say "\nEverything is already set up. Nothing left to do, please proceed.", :green
        else
          say "\nInstall complete. Backups (if any) are saved as *.backup next to the edited files.", :green
        end
      end

      private

      def check_sprockets_manifest
        return if defined?(Propshaft)
        manifest = "app/assets/config/manifest.js"
        return needs_manual("#{manifest} not found (Sprockets must link app/javascript)") unless File.exist?(File.join(destination_root, manifest))
        return if File.read(File.join(destination_root, manifest)).include?("javascript")
        safe_inject manifest, "//= link_tree ../../javascript .js\n//= link_tree ../../../vendor/javascript .js", before: /\A/
      end

      def import_after_last(entry, line)
        last = File.readlines(File.join(destination_root, entry)).grep(/^import\b.*["'];?\s*$/).last
        if last
          safe_inject entry, line, after: last.chomp
        else
          safe_inject entry, line, before: /\A/
        end
      end

      def import_configured_engines
        entry = "app/javascript/application.js"
        names = EngAssets.configured.select { |_, mode| %i[merge both].include?(mode) }.keys.sort
        return say_status(:skipped, "no engines using EngAssets in merge mode", :yellow) if names.empty?
        return needs_manual("#{entry} not found (import each engine's application module by hand)") unless File.exist?(File.join(destination_root, entry))
        names.each { |n| import_after_last(entry, %(import "#{n}/application")) }
      end

      def snapshot
        files = Dir[File.join(destination_root, "{app,config,lib}/**/*"), File.join(destination_root, "*.gemspec")]
        files.select { |f| File.file?(f) }.sort.map { |f| [f, Digest::MD5.file(f).hexdigest] }
      end

      def candidates = Rails.application.railties.select { |r| r.is_a?(Rails::Engine) }
      def app = Rails.application
      def host? = @target.host
      def name = @target.name
      def stimulus = options[:stimulus]

      def add_stylesheet_tag(layout)
        tag = %(<%= engine_stylesheet_link_tags "#{name}", :all %>)
        content = File.read(File.join(destination_root, layout))
        own = /<%= stylesheet_link_tag\s+["']#{Regexp.escape(name)}\/application["'][^%]*%>/
        if content.match?(own)
          safe_replace layout, own, tag
        elsif content.match?(STYLESHEET_TAG)
          safe_inject layout, "    #{tag}", after: STYLESHEET_TAG
        else
          safe_inject layout, "  #{tag}", before: %r{^\s*</head>}
        end
      end

      def importmap_lines
        lines = [%(pin "#{name}/application")]
        unless stimulus == "none"
          lines << %(pin_all_from File.expand_path("../app/javascript/#{name}/controllers", __dir__),\n) +
                   %(             under: "controllers/#{name}", to: "#{name}/controllers")
        end
        if stimulus == "own"
          lines << %(pin "#{name}/standalone")
          lines << %(pin "@hotwired/stimulus", to: "stimulus.min.js")
          lines << %(pin "@hotwired/stimulus-loading", to: "stimulus-loading.js")
        end
        lines.join("\n")
      end

      def configure_line
        arg = options[:importmap] == "merge" ? "" : ", importmap: :#{options[:importmap]}"
        "    EngAssets.configure(self#{arg})"
      end

      def relative(path) = Pathname.new(path).relative_path_from(Pathname.new(destination_root)).to_s

      def engine_file
        found = Dir[File.join(destination_root, "lib/**/*.rb")].find { |f| File.read(f).match?(ENGINE_CLASS) }
        found && relative(found)
      end

      def layout_file
        found = Dir[File.join(destination_root, "app/views/layouts/**/application.html.erb")].first
        found && relative(found)
      end

      def prompt_for(picker)
        say "Where should EngAssets be installed?", :bold
        picker.targets.each_with_index { |t, i| say "  #{i + 1}. #{t.label}", :cyan }
        answer = ask("Number:", limited_to: (1..picker.targets.size).map(&:to_s))
        picker.targets[answer.to_i - 1]
      end
    end
  end
end
