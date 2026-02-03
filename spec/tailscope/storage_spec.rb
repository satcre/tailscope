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

  describe ".ignore_issue / .unignore_issue / .ignored_fingerprints" do
    it "ignores an issue and returns its fingerprint" do
      described_class.ignore_issue(fingerprint: "abc123", title: "Test Issue", issue_type: "code_smell")
      expect(described_class.ignored_fingerprints).to include("abc123")
    end

    it "unignores an issue" do
      described_class.ignore_issue(fingerprint: "abc123", title: "Test Issue", issue_type: "code_smell")
      described_class.unignore_issue("abc123")
      expect(described_class.ignored_fingerprints).not_to include("abc123")
    end

    it "does not error on duplicate ignore" do
      described_class.ignore_issue(fingerprint: "abc123", title: "Test", issue_type: "code_smell")
      expect {
        described_class.ignore_issue(fingerprint: "abc123", title: "Test", issue_type: "code_smell")
      }.not_to raise_error
      expect(described_class.ignored_fingerprints.size).to eq(1)
    end

    it "returns ignored issues list" do
      # Clear any leftover data
      Tailscope::Database.connection.execute("DELETE FROM tailscope_ignored_issues")
      described_class.ignore_issue(fingerprint: "fp1", title: "Issue 1", issue_type: "n_plus_one")
      described_class.ignore_issue(fingerprint: "fp2", title: "Issue 2", issue_type: "code_smell")
      list = described_class.ignored_issues_list
      expect(list.size).to eq(2)
      expect(list.first["fingerprint"]).to be_a(String)
    end
  end

  describe ".queries_for_request" do
    it "returns queries matching a request_id" do
      described_class.record_query(sql_text: "SELECT 1", duration_ms: 10.0, request_id: "req-abc")
      described_class.record_query(sql_text: "SELECT 2", duration_ms: 20.0, request_id: "req-abc")
      described_class.record_query(sql_text: "SELECT 3", duration_ms: 30.0, request_id: "req-other")

      results = described_class.queries_for_request("req-abc")
      expect(results.size).to eq(2)
      expect(results.map { |r| r["sql_text"] }).to contain_exactly("SELECT 1", "SELECT 2")
    end

    it "returns empty array for nil request_id" do
      expect(described_class.queries_for_request(nil)).to eq([])
    end
  end

  describe ".errors_for_request" do
    it "returns errors matching a request_id" do
      described_class.record_error(exception_class: "E1", message: "m1", request_id: "req-abc")
      described_class.record_error(exception_class: "E2", message: "m2", request_id: "req-other")

      results = described_class.errors_for_request("req-abc")
      expect(results.size).to eq(1)
      expect(results.first["exception_class"]).to eq("E1")
    end

    it "returns empty array for nil request_id" do
      expect(described_class.errors_for_request(nil)).to eq([])
    end
  end

  describe ".recent_events" do
    it "returns mixed events sorted by time" do
      described_class.record_query(sql_text: "SELECT 1", duration_ms: 10.0)
      described_class.record_request(method: "GET", path: "/", status: 200, duration_ms: 50.0)
      described_class.record_error(exception_class: "E", message: "m")

      events = described_class.recent_events(limit: 10)
      expect(events.size).to eq(3)
      expect(events.map { |e| e["type"] }).to contain_exactly("query", "request", "error")
    end
  end

  describe ".record_job / .jobs" do
    it "inserts and retrieves a job" do
      described_class.record_job(
        job_class: "SendEmailJob",
        job_id: "job-abc-123",
        queue_name: "default",
        status: "performed",
        duration_ms: 250.5,
        source_file: "/app/jobs/send_email_job.rb",
        source_line: 10,
        request_id: "job_job-abc-123"
      )

      results = described_class.jobs(limit: 10)
      expect(results.size).to eq(1)
      expect(results.first["job_class"]).to eq("SendEmailJob")
      expect(results.first["duration_ms"]).to eq(250.5)
      expect(results.first["queue_name"]).to eq("default")
      expect(results.first["status"]).to eq("performed")
    end
  end

  describe ".jobs_count" do
    it "returns correct count" do
      described_class.record_job(job_class: "Job1", job_id: "j1", queue_name: "q", status: "performed", duration_ms: 10.0)
      described_class.record_job(job_class: "Job2", job_id: "j2", queue_name: "q", status: "performed", duration_ms: 20.0)

      expect(described_class.jobs_count).to eq(2)
    end
  end

  describe ".find_job" do
    it "finds a job by id" do
      described_class.record_job(job_class: "TestJob", job_id: "j1", queue_name: "q", status: "performed", duration_ms: 10.0)
      job = described_class.jobs.first
      found = described_class.find_job(job["id"])
      expect(found["job_class"]).to eq("TestJob")
    end

    it "returns nil for missing id" do
      expect(described_class.find_job(99999)).to be_nil
    end
  end

  describe ".queries_for_job" do
    it "returns queries matching a job_id via tracking_id" do
      described_class.record_query(sql_text: "SELECT 1", duration_ms: 10.0, request_id: "job_j1")
      described_class.record_query(sql_text: "SELECT 2", duration_ms: 20.0, request_id: "job_j1")
      described_class.record_query(sql_text: "SELECT 3", duration_ms: 30.0, request_id: "other")

      results = described_class.queries_for_job("j1")
      expect(results.size).to eq(2)
    end

    it "returns empty array for nil job_id" do
      expect(described_class.queries_for_job(nil)).to eq([])
    end
  end

  describe ".delete_all_jobs" do
    it "removes all jobs" do
      described_class.record_job(job_class: "Job1", job_id: "j1", queue_name: "q", status: "performed", duration_ms: 10.0)
      described_class.record_job(job_class: "Job2", job_id: "j2", queue_name: "q", status: "performed", duration_ms: 20.0)

      described_class.delete_all_jobs
      expect(described_class.jobs_count).to eq(0)
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
