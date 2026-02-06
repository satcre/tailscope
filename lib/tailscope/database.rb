# frozen_string_literal: true

require "sqlite3"
require "fileutils"

module Tailscope
  module Database
    class << self
      def connection
        @connection ||= establish_connection
      end

      def reset!
        @connection&.close rescue nil
        @connection = nil
      end

      private

      def establish_connection
        path = Tailscope.configuration.database_path
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)

        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA synchronous=NORMAL")
        db.execute("PRAGMA busy_timeout=5000")
        db
      end
    end
  end
end
