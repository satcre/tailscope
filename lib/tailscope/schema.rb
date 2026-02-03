# frozen_string_literal: true

module Tailscope
  module Schema
    TABLES = {
      tailscope_queries: <<~SQL,
        CREATE TABLE IF NOT EXISTS tailscope_queries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sql_text TEXT NOT NULL,
          duration_ms REAL NOT NULL,
          name TEXT,
          source_file TEXT,
          source_line INTEGER,
          source_method TEXT,
          request_id TEXT,
          n_plus_one INTEGER DEFAULT 0,
          n_plus_one_count INTEGER DEFAULT 0,
          recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      SQL
      tailscope_requests: <<~SQL,
        CREATE TABLE IF NOT EXISTS tailscope_requests (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          method TEXT NOT NULL,
          path TEXT NOT NULL,
          status INTEGER,
          duration_ms REAL NOT NULL,
          controller TEXT,
          action TEXT,
          view_runtime_ms REAL,
          db_runtime_ms REAL,
          params TEXT,
          request_id TEXT,
          source_file TEXT,
          source_line INTEGER,
          recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      SQL
      tailscope_errors: <<~SQL,
        CREATE TABLE IF NOT EXISTS tailscope_errors (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          exception_class TEXT NOT NULL,
          message TEXT,
          backtrace TEXT,
          source_file TEXT,
          source_line INTEGER,
          source_method TEXT,
          request_method TEXT,
          request_path TEXT,
          params TEXT,
          request_id TEXT,
          duration_ms REAL,
          recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      SQL
      tailscope_breakpoints: <<~SQL,
        CREATE TABLE IF NOT EXISTS tailscope_breakpoints (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          file TEXT NOT NULL,
          line INTEGER NOT NULL,
          condition TEXT,
          enabled INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          UNIQUE(file, line)
        )
      SQL
      tailscope_services: <<~SQL,
        CREATE TABLE IF NOT EXISTS tailscope_services (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL,
          name TEXT,
          duration_ms REAL,
          detail TEXT,
          source_file TEXT,
          source_line INTEGER,
          source_method TEXT,
          request_id TEXT,
          recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      SQL
      tailscope_ignored_issues: <<~SQL
        CREATE TABLE IF NOT EXISTS tailscope_ignored_issues (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fingerprint TEXT NOT NULL UNIQUE,
          issue_title TEXT,
          issue_type TEXT,
          created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      SQL
    }.freeze

    INDEXES = [
      "CREATE INDEX IF NOT EXISTS idx_queries_recorded_at ON tailscope_queries(recorded_at)",
      "CREATE INDEX IF NOT EXISTS idx_queries_n_plus_one ON tailscope_queries(n_plus_one)",
      "CREATE INDEX IF NOT EXISTS idx_queries_request_id ON tailscope_queries(request_id)",
      "CREATE INDEX IF NOT EXISTS idx_requests_recorded_at ON tailscope_requests(recorded_at)",
      "CREATE INDEX IF NOT EXISTS idx_requests_request_id ON tailscope_requests(request_id)",
      "CREATE INDEX IF NOT EXISTS idx_errors_recorded_at ON tailscope_errors(recorded_at)",
      "CREATE INDEX IF NOT EXISTS idx_errors_request_id ON tailscope_errors(request_id)",
      "CREATE INDEX IF NOT EXISTS idx_services_recorded_at ON tailscope_services(recorded_at)",
      "CREATE INDEX IF NOT EXISTS idx_services_request_id ON tailscope_services(request_id)",
      "CREATE INDEX IF NOT EXISTS idx_services_category ON tailscope_services(category)",
      "CREATE INDEX IF NOT EXISTS idx_ignored_fingerprint ON tailscope_ignored_issues(fingerprint)",
    ].freeze

    MIGRATIONS = [
      "ALTER TABLE tailscope_requests ADD COLUMN source_file TEXT",
      "ALTER TABLE tailscope_requests ADD COLUMN source_line INTEGER",
      "ALTER TABLE tailscope_queries ADD COLUMN started_at_ms REAL",
      "ALTER TABLE tailscope_services ADD COLUMN started_at_ms REAL",
    ].freeze

    class << self
      def create_tables!
        db = Tailscope::Database.connection
        TABLES.each_value { |sql| db.execute(sql) }
        INDEXES.each { |sql| db.execute(sql) }
        run_migrations!(db)
      end

      private

      def run_migrations!(db)
        MIGRATIONS.each do |sql|
          db.execute(sql)
        rescue StandardError
          # column already exists — ignore
        end
      end
    end
  end
end
