require "fileutils"

module EngAssets
  module Generators
    # Failsafe file edits for generators. Order of preference:
    #   1. safe_inject  - add a line next to an anchor (no backup needed)
    #   2. safe_replace - change existing text (writes a .backup first)
    #   3. safe_rewrite - replace a whole file (writes a .backup first)
    # Every method returns true if it changed something, false if not.
    module SafeFiles
      def safe_inject(path, text, after: nil, before: nil)
        file = absolute_path(path)
        return manual(path, text, "file not found", :red) unless File.exist?(file)

        content = File.read(file)
        return skipped(path) if content.include?(text.strip)

        anchor = after || before
        found = anchor.is_a?(Regexp) ? content.match?(anchor) : content.include?(anchor)
        return manual(path, text, "anchor not found", :yellow) unless found

        if after
          inject_into_file path, "\n#{text.chomp}", after: after
        else
          inject_into_file path, "#{text.chomp}\n", before: before
        end
        true
      end

      def safe_replace(path, pattern, replacement)
        file = absolute_path(path)
        return manual(path, replacement, "file not found", :red) unless File.exist?(file)

        content = File.read(file)
        return skipped(path) if content.include?(replacement)
        return manual(path, replacement, "pattern not found", :yellow) unless content.match?(pattern)

        backup_file(path)
        gsub_file path, pattern, replacement
        true
      end

      def safe_rewrite(source, destination)
        backup_file(destination) if File.exist?(absolute_path(destination))
        template source, destination, force: true
        true
      end

      private

      def absolute_path(path)
        File.expand_path(path, destination_root)
      end

      # Never overwrites an existing backup: file.backup, file.backup.1, ...
      def backup_file(path)
        file = absolute_path(path)
        target = "#{file}.backup"
        target = "#{file}.backup.#{target.split('.').last.to_i + 1}" while File.exist?(target)
        FileUtils.cp(file, target)
        say_status :backup, target.delete_prefix("#{destination_root}/"), :blue
      end

      # One "identical" line per file per run, however many steps inspect it.
      def skipped(path)
        @reported_skips ||= []
        unless @reported_skips.include?(path)
          @reported_skips << path
          say_status :identical, "#{path} (already up to date)", :yellow
        end
        false
      end

      # For steps that can't even be attempted (no file to edit).
      def needs_manual(message)
        @manual_steps = (@manual_steps || 0) + 1
        say_status :manual, message, :yellow
        false
      end

      def manual(path, text, reason, color)
        @manual_steps = (@manual_steps || 0) + 1
        say_status :manual, "#{path} (#{reason})", color
        say "  Add this by hand:", :bold
        text.each_line { |line| say "    #{line.chomp}", :cyan }
        false
      end
    end
  end
end
