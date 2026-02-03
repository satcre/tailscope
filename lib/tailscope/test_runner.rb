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

      def dry_run(target)
        target = sanitize_target(target)
        return { examples: [] } unless target

        json_file = File.join(Dir.tmpdir, "tailscope_dryrun_#{SecureRandom.hex(4)}.json")

        cmd_parts = [
          "bundle", "exec", "rspec",
          "--dry-run", "--format", "json", "--out", json_file,
          "--no-color", target
        ]

        Bundler.with_unbundled_env do
          pid = Process.spawn(
            { "RAILS_ENV" => "test" },
            *cmd_parts,
            chdir: Rails.root.to_s,
            out: File::NULL,
            err: File::NULL
          )
          Process.wait(pid)
        end

        if File.exist?(json_file)
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
          "--format", "progress", "--force-color"
        ]
        cmd_parts << target if target

        read_io, write_io = IO.pipe

        # Use unbundled_env so the child process gets a clean Bundler
        # environment and properly resolves the test group gems.
        Bundler.with_unbundled_env do
          pid = Process.spawn(
            { "RAILS_ENV" => "test", "TERM" => "xterm-256color" },
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
        end

        @current_run[:console_output] = console_output[0..10_000]

        if File.exist?(json_file)
          json_str = File.read(json_file)
          parse_results(json_str)
          File.delete(json_file) rescue nil
        else
          # Fallback: try to parse JSON from combined output
          parse_results(console_output)
        end
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
