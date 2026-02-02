# frozen_string_literal: true

module Tailscope
  class Configuration
    attr_accessor :enabled,
                  :slow_query_threshold_ms,
                  :slow_request_threshold_ms,
                  :n_plus_one_threshold,
                  :storage_retention_days,
                  :database_path,
                  :source_root,
                  :debugger_enabled,
                  :debugger_timeout

    def initialize
      @enabled = defined?(Rails) ? Rails.env.development? : true
      @slow_query_threshold_ms = 100
      @slow_request_threshold_ms = 500
      @n_plus_one_threshold = 3
      @storage_retention_days = 7
      @database_path = defined?(Rails) ? Rails.root.join("db", "tailscope.sqlite3").to_s : "db/tailscope.sqlite3"
      @source_root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
      @debugger_enabled = false
      @debugger_timeout = 60
    end
  end
end
