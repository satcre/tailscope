# frozen_string_literal: true

require "thor"
require "tailscope"

module Tailscope
  class CLI < Thor
    desc "queries", "List slow queries"
    option :n_plus_one, type: :boolean, aliases: "-n", desc: "Show only N+1 queries"
    option :limit, type: :numeric, default: 20, aliases: "-l"
    def queries
      setup_db!
      results = Storage.queries(limit: options[:limit], n_plus_one_only: options[:n_plus_one])
      if results.empty?
        puts "No queries recorded."
        return
      end

      terminal_width = (ENV["COLUMNS"] || 120).to_i

      results.each_with_index do |q, idx|
        puts "" if idx > 0
        n1 = q["n_plus_one"] == 1 ? " [N+1 x#{q["n_plus_one_count"]}]" : ""
        source = q["source_file"] ? "#{short_path(q["source_file"])}:#{q["source_line"]}" : "unknown"

        puts "Query ##{q["id"]} — #{q["duration_ms"]}ms#{n1}"
        puts wrap("  SQL: #{q["sql_text"]}", terminal_width, "       ")
        puts "  Source: #{source}"
      end

      puts "\n#{results.size} quer#{results.size == 1 ? 'y' : 'ies'} shown"
    end

    desc "requests", "List slow requests"
    option :limit, type: :numeric, default: 20, aliases: "-l"
    def requests
      setup_db!
      results = Storage.requests(limit: options[:limit])
      if results.empty?
        puts "No slow requests recorded."
        return
      end

      results.each_with_index do |r, idx|
        puts "" if idx > 0
        ca = [r["controller"], r["action"]].compact.join("#")

        puts "Request ##{r["id"]} — #{r["method"]} #{r["status"]} — #{r["duration_ms"]}ms"
        puts "  Path: #{r["path"]}"
        puts "  Controller: #{ca}" unless ca.empty?
      end

      puts "\n#{results.size} request#{results.size == 1 ? '' : 's'} shown"
    end

    desc "errors", "List captured exceptions"
    option :limit, type: :numeric, default: 20, aliases: "-l"
    def errors
      setup_db!
      results = Storage.errors(limit: options[:limit])
      if results.empty?
        puts "No errors recorded."
        return
      end

      terminal_width = (ENV["COLUMNS"] || 120).to_i

      results.each_with_index do |e, idx|
        puts "" if idx > 0
        source = e["source_file"] ? "#{short_path(e["source_file"])}:#{e["source_line"]}" : "unknown"

        puts colorize_severity(:critical, "Error ##{e["id"]} — #{e["exception_class"]}")
        puts wrap("  Message: #{e["message"]}", terminal_width, "           ") if e["message"]
        puts "  Source: #{source}"
      end

      puts "\n#{results.size} error#{results.size == 1 ? '' : 's'} shown"
    end

    desc "issues", "List code issues"
    option :severity, type: :string, aliases: "-s", desc: "Filter by severity (critical, warning, info)"
    option :type, type: :string, aliases: "-t", desc: "Filter by type (n_plus_one, slow_query, slow_request, code_smell)"
    option :ignored, type: :boolean, aliases: "-i", desc: "Show ignored issues"
    option :limit, type: :numeric, default: 20, aliases: "-l"
    def issues
      setup_db!
      all_issues = IssueBuilder.build_all
      ignored_fps = Storage.ignored_fingerprints

      issues = if options[:ignored]
        all_issues.select { |i| ignored_fps.include?(i.fingerprint) }
      else
        all_issues.reject { |i| ignored_fps.include?(i.fingerprint) }
      end

      if options[:severity]
        sev = options[:severity].to_sym
        issues = issues.select { |i| i.severity == sev }
      end

      if options[:type]
        type = options[:type].to_sym
        issues = issues.select { |i| i.type == type }
      end

      issues = issues.first(options[:limit])

      if issues.empty?
        puts "No issues found."
        return
      end

      terminal_width = (ENV["COLUMNS"] || 120).to_i

      issues.each_with_index do |issue, idx|
        puts "" if idx > 0
        puts colorize_severity(issue.severity, "#{issue.severity.to_s.upcase.ljust(8)} #{issue.title}")
        puts wrap("  #{issue.description}", terminal_width, "  ")
        puts "  Source: #{short_path(issue.source_file)}:#{issue.source_line}" if issue.source_file
        puts "  Fingerprint: #{issue.fingerprint}"
        puts "  Occurrences: #{issue.occurrences}"
        if issue.suggested_fix && !issue.suggested_fix.empty?
          puts "  Fix:"
          issue.suggested_fix.lines.each { |line| puts "    #{line}" }
        end
      end

      puts "\n#{issues.size} issue(s) shown"
    end

    desc "ignore FINGERPRINT", "Ignore an issue by fingerprint"
    def ignore(fingerprint)
      setup_db!
      all_issues = IssueBuilder.build_all
      issue = all_issues.find { |i| i.fingerprint == fingerprint }

      unless issue
        puts "Issue not found: #{fingerprint}"
        return
      end

      Storage.ignore_issue(
        fingerprint: fingerprint,
        title: issue.title,
        issue_type: issue.type.to_s
      )
      puts "Ignored: #{issue.title}"
    end

    desc "unignore FINGERPRINT", "Unignore an issue by fingerprint"
    def unignore(fingerprint)
      setup_db!
      Storage.unignore_issue(fingerprint)
      puts "Unignored: #{fingerprint}"
    end

    desc "jobs", "List background jobs"
    option :limit, type: :numeric, default: 20, aliases: "-l"
    def jobs
      setup_db!
      results = Storage.jobs(limit: options[:limit])
      if results.empty?
        puts "No jobs recorded."
        return
      end

      results.each_with_index do |j, idx|
        puts "" if idx > 0
        puts "Job ##{j["id"]} — #{j["job_class"]} — #{j["status"]}"
        puts "  Queue: #{j["queue_name"]}"
        puts "  Duration: #{j["duration_ms"]}ms" if j["duration_ms"]
        puts "  Job ID: #{j["job_id"]}"
      end

      puts "\n#{results.size} job#{results.size == 1 ? '' : 's'} shown"
    end

    desc "stats", "Show summary statistics"
    def stats
      setup_db!
      s = Storage.stats
      puts "Tailscope Statistics"
      puts "-" * 30
      puts "Slow queries:    #{s[:queries]}"
      puts "N+1 queries:     #{s[:n_plus_one]}"
      puts "Slow requests:   #{s[:requests]}"
      puts "Errors:          #{s[:errors]}"
      puts "Avg query time:  #{s[:avg_query_ms]}ms"
      puts "Avg request time:#{s[:avg_request_ms]}ms"
    end

    desc "tail", "Live polling mode"
    option :interval, type: :numeric, default: 2, aliases: "-i"
    def tail
      setup_db!
      terminal_width = (ENV["COLUMNS"] || 120).to_i
      puts "Tailscope — live tail (Ctrl+C to stop)"
      puts "-" * 60
      last_id = { query: 0, request: 0, error: 0 }

      loop do
        events = Storage.recent_events(limit: 50)
        events.reverse.each do |e|
          type = e["type"]
          id = e["id"]
          next if id.to_i <= last_id[type.to_sym].to_i

          last_id[type.to_sym] = id.to_i
          time = e["recorded_at"]
          summary_width = terminal_width - 40 # Leave room for timestamp and type
          summary = wrap(e["summary"] || "", summary_width, "").lines.first&.strip || ""
          puts "[#{time}] #{type.upcase.ljust(7)} #{e["duration_ms"]}ms  #{summary}"
        end
        sleep options[:interval]
      end
    rescue Interrupt
      puts "\nStopped."
    end

    desc "purge", "Delete old records"
    option :days, type: :numeric, desc: "Delete records older than N days"
    def purge
      setup_db!
      days = options[:days] || Tailscope.configuration.storage_retention_days
      Storage.purge!(days: days)
      puts "Purged records older than #{days} days."
    end

    desc "show CATEGORY ID", "Show detail for a record (query, request, error)"
    def show(category, id)
      setup_db!
      record = case category
      when "query" then Storage.find_query(id)
      when "request" then Storage.find_request(id)
      when "error" then Storage.find_error(id)
      else
        puts "Unknown category: #{category}. Use: query, request, error"
        return
      end

      unless record
        puts "Record not found."
        return
      end

      record.each do |key, value|
        next if value.nil? || value.to_s.empty?
        puts "#{key}: #{value}"
      end
    end

    private

    def setup_db!
      Tailscope::Schema.create_tables!
    end

    def truncate(str, len)
      return "" unless str
      str.length > len ? str[0...len] + "..." : str
    end

    def wrap(text, width, indent = "")
      return "" unless text
      text = text.to_s.strip
      return text if text.length <= width

      lines = []
      words = text.split(/\s+/)
      current_line = indent.dup

      words.each do |word|
        if (current_line + word).length <= width
          current_line << (current_line == indent ? "" : " ") << word
        else
          lines << current_line unless current_line == indent
          current_line = indent + word
        end
      end

      lines << current_line unless current_line == indent
      lines.join("\n")
    end

    def colorize_severity(severity, text)
      return text unless $stdout.tty?

      color = case severity
      when :critical then "\e[31m" # red
      when :warning then "\e[33m"  # yellow
      when :info then "\e[36m"     # cyan
      else "\e[0m"
      end

      "#{color}#{text}\e[0m"
    end

    def short_path(path)
      return path unless path
      path.sub(Tailscope.configuration.source_root + "/", "")
    end
  end
end
