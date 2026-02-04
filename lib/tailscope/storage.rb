# frozen_string_literal: true

require "json"

module Tailscope
  module Storage
    QUEUE_SIZE = 1000

    class << self
      def start_writer!
        return if @writer_thread&.alive?

        @queue = SizedQueue.new(QUEUE_SIZE)
        @writer_thread = Thread.new do
          loop do
            operation = @queue.pop
            break if operation == :shutdown

            begin
              execute_write(operation)
            rescue => e
              warn "[Tailscope] Write error: #{e.message}" if defined?(Rails) && Rails.env.development?
            end
          end
        end
        @writer_thread.name = "tailscope-writer"
      end

      def stop_writer!
        return unless @writer_thread&.alive?

        @queue&.push(:shutdown)
        @writer_thread&.join(5)
        @writer_thread = nil
      end

      def record_query(attrs)
        enqueue([:query, attrs])
      end

      def record_request(attrs)
        enqueue([:request, attrs])
      end

      def record_error(attrs)
        enqueue([:error, attrs])
      end

      def record_service(attrs)
        enqueue([:service, attrs])
      end

      def record_job(attrs)
        enqueue([:job, attrs])
      end

      def queries_count(n_plus_one_only: false)
        sql = "SELECT COUNT(*) as count FROM tailscope_queries"
        sql += " WHERE n_plus_one = 1" if n_plus_one_only
        Tailscope::Database.connection.execute(sql).first["count"]
      end

      def queries(limit: 50, offset: 0, n_plus_one_only: false)
        sql = "SELECT * FROM tailscope_queries"
        sql += " WHERE n_plus_one = 1" if n_plus_one_only
        sql += " ORDER BY id DESC LIMIT ? OFFSET ?"
        Tailscope::Database.connection.execute(sql, [limit, offset])
      end

      def requests_count
        Tailscope::Database.connection.execute(
          "SELECT COUNT(*) as count FROM tailscope_requests"
        ).first["count"]
      end

      def requests(limit: 50, offset: 0)
        Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_requests ORDER BY id DESC LIMIT ? OFFSET ?",
          [limit, offset]
        )
      end

      def errors_count
        Tailscope::Database.connection.execute(
          "SELECT COUNT(*) as count FROM tailscope_errors"
        ).first["count"]
      end

      def errors(limit: 50, offset: 0)
        Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_errors ORDER BY id DESC LIMIT ? OFFSET ?",
          [limit, offset]
        )
      end

      def find_query(id)
        results = Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_queries WHERE id = ?", [id]
        )
        results.first
      end

      def find_request(id)
        results = Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_requests WHERE id = ?", [id]
        )
        results.first
      end

      def find_error(id)
        results = Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_errors WHERE id = ?", [id]
        )
        results.first
      end

      def queries_for_request(request_id)
        return [] unless request_id

        Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_queries WHERE request_id = ? ORDER BY recorded_at ASC",
          [request_id]
        )
      end

      def errors_for_request(request_id)
        return [] unless request_id

        Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_errors WHERE request_id = ? ORDER BY recorded_at ASC",
          [request_id]
        )
      end

      def services_for_request(request_id)
        return [] unless request_id

        Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_services WHERE request_id = ? ORDER BY recorded_at ASC",
          [request_id]
        )
      end

      def stats
        db = Tailscope::Database.connection
        {
          queries: db.execute("SELECT COUNT(*) as count FROM tailscope_queries").first["count"],
          n_plus_one: db.execute("SELECT COUNT(*) as count FROM tailscope_queries WHERE n_plus_one = 1").first["count"],
          requests: db.execute("SELECT COUNT(*) as count FROM tailscope_requests").first["count"],
          errors: db.execute("SELECT COUNT(*) as count FROM tailscope_errors").first["count"],
          avg_query_ms: db.execute("SELECT AVG(duration_ms) as avg FROM tailscope_queries").first["avg"]&.round(2) || 0,
          avg_request_ms: db.execute("SELECT AVG(duration_ms) as avg FROM tailscope_requests").first["avg"]&.round(2) || 0,
        }
      end

      def delete_all_queries
        Tailscope::Database.connection.execute("DELETE FROM tailscope_queries")
      end

      def delete_all_requests
        Tailscope::Database.connection.execute("DELETE FROM tailscope_requests")
      end

      def delete_all_errors
        Tailscope::Database.connection.execute("DELETE FROM tailscope_errors")
      end

      def jobs_count
        Tailscope::Database.connection.execute(
          "SELECT COUNT(*) as count FROM tailscope_jobs"
        ).first["count"]
      end

      def jobs(limit: 50, offset: 0)
        Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_jobs ORDER BY id DESC LIMIT ? OFFSET ?",
          [limit, offset]
        )
      end

      def find_job(id)
        results = Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_jobs WHERE id = ?", [id]
        )
        results.first
      end

      def queries_for_job(job_id)
        return [] unless job_id
        tracking_id = "job_#{job_id}"

        Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_queries WHERE request_id = ? ORDER BY recorded_at ASC",
          [tracking_id]
        )
      end

      def services_for_job(job_id)
        return [] unless job_id
        tracking_id = "job_#{job_id}"

        Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_services WHERE request_id = ? ORDER BY recorded_at ASC",
          [tracking_id]
        )
      end

      def delete_all_jobs
        Tailscope::Database.connection.execute("DELETE FROM tailscope_jobs")
      end

      def purge!(days: nil)
        days ||= Tailscope.configuration.storage_retention_days
        cutoff = (Time.now - (days * 86400)).strftime("%Y-%m-%d %H:%M:%S")
        db = Tailscope::Database.connection
        db.execute("DELETE FROM tailscope_queries WHERE recorded_at < ?", [cutoff])
        db.execute("DELETE FROM tailscope_requests WHERE recorded_at < ?", [cutoff])
        db.execute("DELETE FROM tailscope_errors WHERE recorded_at < ?", [cutoff])
        db.execute("DELETE FROM tailscope_services WHERE recorded_at < ?", [cutoff])
        db.execute("DELETE FROM tailscope_jobs WHERE recorded_at < ?", [cutoff])
      end

      # --- Ignored Issues ---

      def ignore_issue(fingerprint:, title: nil, issue_type: nil)
        Tailscope::Database.connection.execute(
          "INSERT OR IGNORE INTO tailscope_ignored_issues (fingerprint, issue_title, issue_type) VALUES (?, ?, ?)",
          [fingerprint, title, issue_type]
        )
      end

      def unignore_issue(fingerprint)
        Tailscope::Database.connection.execute(
          "DELETE FROM tailscope_ignored_issues WHERE fingerprint = ?",
          [fingerprint]
        )
      end

      def ignored_fingerprints
        rows = Tailscope::Database.connection.execute(
          "SELECT fingerprint FROM tailscope_ignored_issues"
        )
        Set.new(rows.map { |r| r["fingerprint"] })
      end

      def ignored_issues_list
        Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_ignored_issues ORDER BY created_at DESC"
        )
      end

      # --- File Analysis ---

      def store_file_analysis(file_path:, issues:)
        file_path = File.expand_path(file_path)
        file_mtime = File.exist?(file_path) ? File.mtime(file_path).utc.iso8601 : nil
        issues_json = JSON.dump(issues.map { |i| serialize_issue_for_cache(i) })

        Tailscope::Database.connection.execute(
          "INSERT OR REPLACE INTO tailscope_file_analysis
           (file_path, analyzed_at, file_mtime, issues_json, updated_at)
           VALUES (?, datetime('now'), ?, ?, datetime('now'))",
          [file_path, file_mtime, issues_json]
        )
      end

      def get_file_analysis(file_path)
        file_path = File.expand_path(file_path)
        results = Tailscope::Database.connection.execute(
          "SELECT * FROM tailscope_file_analysis WHERE file_path = ?",
          [file_path]
        )
        results.first
      end

      def delete_file_analysis(file_path)
        file_path = File.expand_path(file_path)
        Tailscope::Database.connection.execute(
          "DELETE FROM tailscope_file_analysis WHERE file_path = ?",
          [file_path]
        )
      end

      def recent_events(limit: 10)
        db = Tailscope::Database.connection
        queries = db.execute(
          "SELECT id, 'query' as type, sql_text as summary, duration_ms, recorded_at FROM tailscope_queries ORDER BY id DESC LIMIT ?", [limit]
        )
        requests = db.execute(
          "SELECT id, 'request' as type, method || ' ' || path as summary, duration_ms, recorded_at FROM tailscope_requests ORDER BY id DESC LIMIT ?", [limit]
        )
        errors = db.execute(
          "SELECT id, 'error' as type, exception_class || ': ' || message as summary, duration_ms, recorded_at FROM tailscope_errors ORDER BY id DESC LIMIT ?", [limit]
        )
        (queries + requests + errors).sort_by { |e| e["recorded_at"] || "" }.reverse.first(limit)
      end

      private

      def serialize_issue_for_cache(issue)
        {
          fingerprint: issue.fingerprint,
          title: issue.title,
          description: issue.description,
          severity: issue.severity,
          type: issue.type,
          source_file: issue.source_file,
          source_line: issue.source_line,
          suggested_fix: issue.suggested_fix,
          metadata: issue.metadata,
        }
      end

      def enqueue(operation)
        if @queue
          @queue.push(operation, true) rescue nil # non-blocking, drop if full
        else
          execute_write(operation)
        end
      end

      def execute_write(operation)
        type, attrs = operation
        db = Tailscope::Database.connection

        case type
        when :query
          db.execute(
            "INSERT INTO tailscope_queries (sql_text, duration_ms, name, source_file, source_line, source_method, request_id, n_plus_one, n_plus_one_count, started_at_ms, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))",
            [attrs[:sql_text], attrs[:duration_ms], attrs[:name], attrs[:source_file],
             attrs[:source_line], attrs[:source_method], attrs[:request_id],
             attrs[:n_plus_one] ? 1 : 0, attrs[:n_plus_one_count] || 0,
             attrs[:started_at_ms]]
          )
        when :request
          db.execute(
            "INSERT INTO tailscope_requests (method, path, status, duration_ms, controller, action, view_runtime_ms, db_runtime_ms, params, request_id, source_file, source_line, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))",
            [attrs[:method], attrs[:path], attrs[:status], attrs[:duration_ms],
             attrs[:controller], attrs[:action], attrs[:view_runtime_ms], attrs[:db_runtime_ms],
             attrs[:params].is_a?(Hash) ? JSON.dump(attrs[:params]) : attrs[:params],
             attrs[:request_id], attrs[:source_file], attrs[:source_line]]
          )
        when :error
          db.execute(
            "INSERT INTO tailscope_errors (exception_class, message, backtrace, source_file, source_line, source_method, request_method, request_path, params, request_id, duration_ms, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))",
            [attrs[:exception_class], attrs[:message],
             attrs[:backtrace].is_a?(Array) ? attrs[:backtrace].join("\n") : attrs[:backtrace],
             attrs[:source_file], attrs[:source_line], attrs[:source_method],
             attrs[:request_method], attrs[:request_path],
             attrs[:params].is_a?(Hash) ? JSON.dump(attrs[:params]) : attrs[:params],
             attrs[:request_id], attrs[:duration_ms]]
          )
        when :service
          db.execute(
            "INSERT INTO tailscope_services (category, name, duration_ms, detail, source_file, source_line, source_method, request_id, started_at_ms, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))",
            [attrs[:category], attrs[:name], attrs[:duration_ms],
             attrs[:detail].is_a?(Hash) ? JSON.dump(attrs[:detail]) : attrs[:detail],
             attrs[:source_file], attrs[:source_line], attrs[:source_method],
             attrs[:request_id], attrs[:started_at_ms]]
          )
        when :job
          db.execute(
            "INSERT INTO tailscope_jobs (job_class, job_id, queue_name, status, duration_ms, error_class, error_message, source_file, source_line, request_id, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))",
            [attrs[:job_class], attrs[:job_id], attrs[:queue_name], attrs[:status],
             attrs[:duration_ms], attrs[:error_class], attrs[:error_message],
             attrs[:source_file], attrs[:source_line], attrs[:request_id]]
          )
        end
      end
    end
  end
end
