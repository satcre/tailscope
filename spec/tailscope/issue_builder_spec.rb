# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::IssueBuilder do
  let(:db) { Tailscope::Database.connection }

  def insert_n_plus_one_query
    db.execute(
      "INSERT INTO tailscope_queries (sql_text, duration_ms, source_file, source_line, source_method, n_plus_one, n_plus_one_count, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))",
      ["SELECT * FROM posts WHERE user_id = ?", 5.0, "/app/models/user.rb", 10, "posts", 1, 5]
    )
  end

  def insert_slow_query(duration: 200.0)
    db.execute(
      "INSERT INTO tailscope_queries (sql_text, duration_ms, source_file, source_line, source_method, n_plus_one, n_plus_one_count, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))",
      ["SELECT * FROM users WHERE name LIKE '%foo%'", duration, "/app/models/user.rb", 20, "search", 0, 0]
    )
  end

  def insert_error(exception_class: "NoMethodError", message: "undefined method 'foo' for nil")
    db.execute(
      "INSERT INTO tailscope_errors (exception_class, message, source_file, source_line, source_method, recorded_at) VALUES (?, ?, ?, ?, ?, datetime('now'))",
      [exception_class, message, "/app/models/user.rb", 30, "foo"]
    )
  end

  def insert_slow_request(duration: 600.0, view_ms: 100.0, db_ms: 400.0)
    db.execute(
      "INSERT INTO tailscope_requests (method, path, status, duration_ms, controller, action, view_runtime_ms, db_runtime_ms, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))",
      ["GET", "/users", 200, duration, "UsersController", "index", view_ms, db_ms]
    )
  end

  describe ".build_all" do
    it "returns an array" do
      expect(described_class.build_all).to be_an(Array)
    end

    it "includes n_plus_one issues" do
      insert_n_plus_one_query
      types = described_class.build_all.map(&:type)
      expect(types).to include(:n_plus_one)
    end

    it "includes slow_query issues" do
      insert_slow_query
      types = described_class.build_all.map(&:type)
      expect(types).to include(:slow_query)
    end

    it "includes error issues" do
      insert_error
      types = described_class.build_all.map(&:type)
      expect(types).to include(:error)
    end

    it "includes slow_request issues" do
      insert_slow_request
      types = described_class.build_all.map(&:type)
      expect(types).to include(:slow_request)
    end

    it "sorts by severity (critical first)" do
      insert_n_plus_one_query
      insert_slow_query(duration: 600.0)
      insert_slow_request(duration: 600.0)
      issues = described_class.build_all
      severities = issues.map(&:severity)
      critical_idx = severities.index(:critical)
      warning_idx = severities.index(:warning)
      info_idx = severities.index(:info)
      expect(critical_idx).to be < warning_idx if critical_idx && warning_idx
      expect(warning_idx).to be < info_idx if warning_idx && info_idx
    end

    it "respects limit" do
      3.times { |i| insert_error(exception_class: "Error#{i}", message: "msg #{i}") }
      expect(described_class.build_all(limit: 2).length).to be <= 2
    end

    it "produces deterministic fingerprints" do
      insert_n_plus_one_query
      fp1 = described_class.build_all.first.fingerprint
      fp2 = described_class.build_all.first.fingerprint
      expect(fp1).to eq(fp2)
      expect(fp1.length).to eq(16)
    end
  end

  describe "code_smell_issues resilience" do
    it "does not raise when CodeAnalyzer fails" do
      allow(Tailscope::CodeAnalyzer).to receive(:analyze_all).and_raise(StandardError, "boom")
      expect { described_class.build_all }.not_to raise_error
    end
  end
end
