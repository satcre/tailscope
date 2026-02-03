# frozen_string_literal: true

require "json"
require "securerandom"

module Tailscope
  module TestRunner
    CATEGORY_MAP = {
      "controllers" => "controller",
      "models" => "model",
      "requests" => "request",
      "system" => "system",
      "features" => "feature",
      "jobs" => "job",
      "mailers" => "mailer",
      "helpers" => "helper",
      "views" => "view",
      "routing" => "routing",
      "services" => "service",
      "lib" => "lib",
      "integration" => "integration",
    }.freeze

    class << self
      def available?
        return false unless defined?(Rails)

        spec_dir = Rails.root.join("spec")
        return false unless spec_dir.directory?

        gemfile = Rails.root.join("Gemfile")
        return false unless gemfile.exist?

        content = gemfile.read
        content.match?(/rspec/)
      end

      def discover_specs
        return { available: false, tree: [] } unless available?

        spec_dir = Rails.root.join("spec")
        files = Dir.glob(spec_dir.join("**/*_spec.rb")).sort
        tree = build_tree(spec_dir, files)

        { available: true, tree: tree }
      end

      def running?
        @current_run && @current_run[:status] == "running"
      end

      def current_run
        @current_run
      end

      def run!(target: nil)
        return { error: "Already running" } if running?

        target = sanitize_target(target)

        @current_run = {
          id: SecureRandom.hex(8),
          status: "running",
          target: target || "all",
          started_at: Time.now.iso8601,
          pid: nil,
          summary: nil,
          examples: nil,
          console_output: nil,
          error_output: nil,
        }

        Thread.new do
          begin
            execute_rspec(target)
          rescue => e
            @current_run[:status] = "error"
            @current_run[:error_output] = e.message
          end
        end

        { id: @current_run[:id], status: "running" }
      end

      def cancel!
        return { error: "No run in progress" } unless running?

        pid = @current_run[:pid]
        if pid
          begin
            Process.kill("TERM", pid)
            sleep 0.5
            Process.kill("KILL", pid) rescue nil
          rescue Errno::ESRCH
            # already dead
          end
        end

        @current_run[:status] = "cancelled"
        { status: "cancelled" }
      end

      def status
        return { run: nil } unless @current_run

        run = @current_run.dup
        run.delete(:pid)
        { run: run }
      end

      def coverage
        return { available: false } unless defined?(Rails)

        # Read stored coverage from SQLite (captured immediately after test run)
        row = Tailscope::Database.connection.execute(
          "SELECT overall_percentage, total_lines, covered_lines, files_json FROM tailscope_coverage ORDER BY id DESC LIMIT 1"
        ).first

        if row
          files = JSON.parse(row["files_json"] || "[]")
          {
            available: true,
            summary: {
              total_lines: row["total_lines"],
              covered_lines: row["covered_lines"],
              percentage: row["overall_percentage"],
            },
            files: files,
          }
        else
          { available: false }
        end
      rescue => e
        { available: false, error: e.message }
      end

      def dry_run(target)
        target = sanitize_target(target)
        return { examples: [] } unless target

        # Cache results by file path + mtime to avoid re-spawning rspec
        @dry_run_cache ||= {}
        spec_file = target.split(":").first
        full_path = Rails.root.join(spec_file).to_s
        if File.exist?(full_path)
          mtime = File.mtime(full_path).to_f
          cache_key = "#{spec_file}:#{mtime}"
          return @dry_run_cache[cache_key] if @dry_run_cache[cache_key]
        end

        json_file = File.join(Dir.tmpdir, "tailscope_dryrun_#{SecureRandom.hex(4)}.json")

        cmd_parts = [
          "bundle", "exec", "rspec",
          "--dry-run", "--format", "json", "--out", json_file,
          "--no-color", target
        ]

        pid = Process.spawn(
          { "RAILS_ENV" => "test", "DISABLE_SPRING" => "1" },
          *cmd_parts,
          chdir: Rails.root.to_s,
          out: File::NULL,
          err: File::NULL
        )
        Process.wait(pid)

        result = if File.exist?(json_file)
          data = JSON.parse(File.read(json_file))
          File.delete(json_file) rescue nil

          examples = (data["examples"] || []).map do |ex|
            {
              id: ex["id"],
              description: ex["description"],
              full_description: ex["full_description"],
              file_path: ex["file_path"],
              line_number: ex["line_number"],
            }
          end

          { examples: examples }
        else
          { examples: [] }
        end

        @dry_run_cache[cache_key] = result if cache_key
        result
      rescue => e
        { examples: [], error: e.message }
      end

      private

      def sanitize_target(target)
        return nil if target.nil? || target.strip.empty?

        target = target.strip

        # Only allow spec/ paths and line numbers
        unless target.match?(%r{\Aspec/[\w/.\-:]+\z})
          raise "Invalid target: #{target}"
        end

        # Prevent path traversal
        raise "Invalid target" if target.include?("..")

        target
      end

      def execute_rspec(target)
        # Use a temp file for JSON output, capture human-readable output on stdout/stderr
        json_file = File.join(Dir.tmpdir, "tailscope_rspec_#{@current_run[:id]}.json")

        cmd_parts = [
          "bundle", "exec", "rspec",
          "--format", "json", "--out", json_file,
          "--format", "documentation", "--force-color",
          target || "spec"
        ]

        console_output = ""
        read_io, write_io = IO.pipe

        pid = Process.spawn(
          { "RAILS_ENV" => "test", "DISABLE_SPRING" => "1", "TERM" => "xterm-256color" },
          *cmd_parts,
          chdir: Rails.root.to_s,
          out: write_io,
          err: write_io
        )

        @current_run[:pid] = pid
        write_io.close

        console_output = read_io.read
        read_io.close

        Process.wait(pid)

        @current_run[:console_output] = console_output[0..100_000]

        if File.exist?(json_file)
          json_str = File.read(json_file)
          parse_results(json_str)
          File.delete(json_file) rescue nil
        else
          # Fallback: try to parse JSON from combined output
          parse_results(console_output)
        end

        # If rspec reported 0 examples but console output contains errors,
        # the spec files failed to load — surface the errors instead of
        # showing a misleading "Passed — 0 examples".
        if @current_run[:status] == "finished" &&
            @current_run.dig(:summary, :total) == 0 &&
            console_output.include?("An error occurred while loading")
          @current_run[:status] = "error"
          @current_run[:error_output] = console_output[0..5000]
        end

        # Capture coverage data immediately after the child process exits,
        # while .resultset.json is still fresh from SimpleCov's at_exit hook.
        store_coverage(console_output)
      end

      def parse_results(output)
        # Try direct parse first (works when output is pure JSON from file),
        # fall back to extracting JSON from mixed output.
        data = begin
          JSON.parse(output)
        rescue JSON::ParserError
          json_str = extract_json(output)
          json_str ? JSON.parse(json_str) : nil
        end

        if data

          @current_run[:summary] = {
            total: data.dig("summary", "example_count") || 0,
            passed: (data.dig("summary", "example_count") || 0) - (data.dig("summary", "failure_count") || 0) - (data.dig("summary", "pending_count") || 0),
            failed: data.dig("summary", "failure_count") || 0,
            pending: data.dig("summary", "pending_count") || 0,
            duration_s: data.dig("summary", "duration")&.round(3),
          }

          @current_run[:examples] = (data["examples"] || []).map do |ex|
            {
              id: ex["id"],
              description: ex["description"],
              full_description: ex["full_description"],
              status: ex["status"],
              file_path: ex["file_path"],
              line_number: ex["line_number"],
              run_time: ex["run_time"]&.round(4),
              exception: ex["exception"] ? {
                class: ex["exception"]["class"],
                message: ex["exception"]["message"],
                backtrace: ex["exception"]["backtrace"],
              } : nil,
            }
          end

          @current_run[:status] = "finished"
        else
          @current_run[:status] = "error"
          @current_run[:error_output] = output.strip.empty? ? "No output from rspec" : output[0..2000]
        end
      rescue JSON::ParserError => e
        @current_run[:status] = "error"
        @current_run[:error_output] = "Failed to parse rspec output: #{e.message}\n#{output[0..500]}"
      end

      def store_coverage(console_output)
        return unless defined?(Rails)

        resultset = Rails.root.join("coverage", ".resultset.json")
        return unless File.exist?(resultset)

        data = JSON.parse(File.read(resultset))
        raw_coverage = nil

        # SimpleCov may store multiple command entries. Use the most recent.
        latest_timestamp = 0
        data.each_value do |entry|
          next unless entry.is_a?(Hash) && entry["coverage"]
          ts = entry["timestamp"].to_i
          if ts >= latest_timestamp
            latest_timestamp = ts
            raw_coverage = entry["coverage"]
          end
        end

        return unless raw_coverage

        source_root = Rails.root.to_s + "/"
        total_covered = 0
        total_relevant = 0
        files = []

        raw_coverage.each do |file_path, file_data|
          relative = file_path.sub(source_root, "")
          next unless relative.start_with?("app/") || relative.start_with?("lib/")

          lines = file_data.is_a?(Hash) ? file_data["lines"] : file_data
          next unless lines.is_a?(Array)

          relevant = lines.count { |v| !v.nil? }
          covered = lines.count { |v| v.is_a?(Integer) && v > 0 }
          missed = relevant - covered
          percentage = relevant > 0 ? (covered.to_f / relevant * 100).round(1) : 100.0

          total_covered += covered
          total_relevant += relevant

          files << {
            path: relative,
            covered: covered,
            missed: missed,
            total: relevant,
            percentage: percentage,
            lines: lines,
          }
        end

        files.sort_by! { |f| f[:percentage] }
        overall = total_relevant > 0 ? (total_covered.to_f / total_relevant * 100).round(1) : 0.0

        # If resultset shows near-zero coverage but console output has a higher
        # SimpleCov percentage, use the console value instead — the resultset
        # can be unreliable when rspec is spawned from a running Rails process.
        console_pct = parse_simplecov_line(console_output)
        if console_pct && console_pct > overall && console_pct > 1.0
          overall = console_pct
          # We can't reconstruct per-file data from the console line,
          # so clear files to avoid showing misleading per-file breakdowns.
          files = []
          total_relevant = 0
          total_covered = 0
        end

        db = Tailscope::Database.connection
        db.execute(
          "INSERT INTO tailscope_coverage (run_id, overall_percentage, total_lines, covered_lines, files_json) VALUES (?, ?, ?, ?, ?)",
          [@current_run[:id], overall, total_relevant, total_covered, JSON.generate(files)]
        )

        # Keep only the latest 10 coverage records
        db.execute("DELETE FROM tailscope_coverage WHERE id NOT IN (SELECT id FROM tailscope_coverage ORDER BY id DESC LIMIT 10)")
      rescue => e
        # Coverage storage is best-effort; don't break test runs
        Rails.logger.warn("[Tailscope] Failed to store coverage: #{e.message}") if defined?(Rails)
      end

      def parse_simplecov_line(output)
        return nil unless output
        # SimpleCov prints: "Coverage report generated... 870 / 938 LOC (92.75%) covered."
        match = output.match(/\((\d+\.?\d*)%\)\s+covered/)
        match ? match[1].to_f : nil
      end

      def extract_json(output)
        start = output.index("{")
        return nil unless start

        depth = 0
        in_string = false
        escape = false

        (start...output.length).each do |i|
          char = output[i]

          if escape
            escape = false
            next
          end

          if char == '\\'
            escape = true if in_string
            next
          end

          if char == '"' && !escape
            in_string = !in_string
            next
          end

          next if in_string

          if char == "{"
            depth += 1
          elsif char == "}"
            depth -= 1
            return output[start..i] if depth == 0
          end
        end

        nil
      end

      def build_tree(spec_dir, files)
        root = {}

        files.each do |file|
          relative = file.sub("#{spec_dir}/", "")
          parts = relative.split("/")

          current = root
          parts.each_with_index do |part, i|
            if i == parts.length - 1
              # File node
              current[part] = {
                path: "spec/#{relative}",
                name: part,
                type: "file",
                category: categorize(relative),
              }
            else
              # Folder node
              current[part] ||= { _children: {} }
              current = current[part][:_children]
            end
          end
        end

        flatten_tree(root, "spec")
      end

      def flatten_tree(hash, parent_path)
        result = []

        hash.each do |name, value|
          if value[:type] == "file"
            result << value
          elsif value[:_children]
            path = "#{parent_path}/#{name}"
            children = flatten_tree(value[:_children], path)
            result << {
              path: path,
              name: name,
              type: "folder",
              category: CATEGORY_MAP[name],
              children: children,
            }
          end
        end

        result.sort_by { |n| [n[:type] == "folder" ? 0 : 1, n[:name]] }
      end

      def categorize(relative_path)
        first_dir = relative_path.split("/").first
        CATEGORY_MAP[first_dir] || "spec"
      end
    end
  end
end
