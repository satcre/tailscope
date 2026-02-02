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

      puts format("%-6s %-10s %-60s %-30s", "ID", "Duration", "SQL", "Source")
      puts "-" * 110
      results.each do |q|
        n1 = q["n_plus_one"] == 1 ? " [N+1 x#{q["n_plus_one_count"]}]" : ""
        source = q["source_file"] ? "#{short_path(q["source_file"])}:#{q["source_line"]}" : ""
        puts format("%-6s %-10s %-60s %-30s",
          q["id"],
          "#{q["duration_ms"]}ms",
          truncate(q["sql_text"], 57) + n1,
          truncate(source, 30))
      end
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

      puts format("%-6s %-7s %-40s %-6s %-10s %-20s", "ID", "Method", "Path", "Status", "Duration", "Controller#Action")
      puts "-" * 95
      results.each do |r|
        ca = [r["controller"], r["action"]].compact.join("#")
        puts format("%-6s %-7s %-40s %-6s %-10s %-20s",
          r["id"], r["method"], truncate(r["path"], 40),
          r["status"], "#{r["duration_ms"]}ms", truncate(ca, 20))
      end
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

      puts format("%-6s %-30s %-50s %-30s", "ID", "Exception", "Message", "Source")
      puts "-" * 120
      results.each do |e|
        source = e["source_file"] ? "#{short_path(e["source_file"])}:#{e["source_line"]}" : ""
        puts format("%-6s %-30s %-50s %-30s",
          e["id"], truncate(e["exception_class"], 30),
          truncate(e["message"], 50), truncate(source, 30))
      end
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
          puts "[#{time}] #{type.upcase.ljust(7)} #{e["duration_ms"]}ms  #{truncate(e["summary"], 80)}"
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

    def short_path(path)
      return path unless path
      path.sub(Tailscope.configuration.source_root + "/", "")
    end
  end
end
