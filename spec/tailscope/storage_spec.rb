# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Storage do
  before do
    Tailscope::Database.reset!
    Tailscope::Schema.create_tables!
  end

  describe ".record_query / .queries" do
    it "inserts and retrieves a query" do
      described_class.record_query(
        sql_text: "SELECT * FROM users",
        duration_ms: 150.5,
        name: "User Load",
        source_file: "/app/models/user.rb",
        source_line: 10,
        source_method: "find_all",
        request_id: "abc123"
      )

      results = described_class.queries(limit: 10)
      expect(results.size).to eq(1)
      expect(results.first["sql_text"]).to eq("SELECT * FROM users")
      expect(results.first["duration_ms"]).to eq(150.5)
    end
  end

  describe ".record_request / .requests" do
    it "inserts and retrieves a request" do
      described_class.record_request(
        method: "GET",
        path: "/users",
        status: 200,
        duration_ms: 600.0,
        controller: "UsersController",
        action: "index",
        request_id: "req1"
      )

      results = described_class.requests(limit: 10)
      expect(results.size).to eq(1)
      expect(results.first["path"]).to eq("/users")
    end
  end

  describe ".record_error / .errors" do
    it "inserts and retrieves an error" do
      described_class.record_error(
        exception_class: "RuntimeError",
        message: "something broke",
        backtrace: ["/app/foo.rb:1", "/app/bar.rb:2"],
        source_file: "/app/foo.rb",
        source_line: 1,
        source_method: "call",
        request_method: "GET",
        request_path: "/boom",
        request_id: "err1"
      )

      results = described_class.errors(limit: 10)
      expect(results.size).to eq(1)
      expect(results.first["exception_class"]).to eq("RuntimeError")
    end
  end

  describe ".stats" do
    it "returns correct counts" do
      described_class.record_query(sql_text: "SELECT 1", duration_ms: 50.0)
      described_class.record_request(method: "GET", path: "/", status: 200, duration_ms: 100.0)
      described_class.record_error(exception_class: "E", message: "m")

      stats = described_class.stats
      expect(stats[:queries]).to eq(1)
      expect(stats[:requests]).to eq(1)
      expect(stats[:errors]).to eq(1)
    end
  end

  describe ".find_query / .find_request / .find_error" do
    it "finds records by id" do
      described_class.record_query(sql_text: "SELECT 1", duration_ms: 50.0)
      query = described_class.queries.first
      found = described_class.find_query(query["id"])
      expect(found["sql_text"]).to eq("SELECT 1")
    end
  end

  describe ".purge!" do
    it "removes old records" do
      described_class.record_query(sql_text: "old query", duration_ms: 50.0)
      # Manually backdate the record
      Tailscope::Database.connection.execute(
        "UPDATE tailscope_queries SET recorded_at = datetime('now', '-30 days')"
      )
      described_class.purge!(days: 7)
      expect(described_class.queries.size).to eq(0)
    end
  end
end
