# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Issues API", type: :request do
  before do
    allow_any_instance_of(Tailscope::ApiController).to receive(:verify_authenticity_token).and_return(true)
    allow(Tailscope::IssueBuilder).to receive(:build_all).and_return(test_issues)
  end

  let(:test_issues) do
    [
      Tailscope::Issue.new(
        severity: :critical, type: :n_plus_one, title: "N+1 Query",
        description: "test", source_file: "/app/user.rb", source_line: 1,
        suggested_fix: "fix", occurrences: 3, raw_ids: [], raw_type: "query",
        fingerprint: "abc123", total_duration_ms: 150.0, latest_at: nil, metadata: {}
      ),
      Tailscope::Issue.new(
        severity: :warning, type: :slow_query, title: "Slow Query",
        description: "test", source_file: "/app/user.rb", source_line: 2,
        suggested_fix: "fix", occurrences: 1, raw_ids: [], raw_type: "query",
        fingerprint: "def456", total_duration_ms: 500.0, latest_at: nil, metadata: {}
      ),
    ]
  end

  describe "GET /tailscope/api/issues" do
    it "returns issues with counts and pagination" do
      get "/tailscope/api/issues"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["issues"].size).to eq(2)
      expect(body["ignored_count"]).to eq(0)
      expect(body["counts"]["critical"]).to eq(1)
      expect(body["counts"]["warning"]).to eq(1)
      expect(body["pagination"]["page"]).to eq(1)
      expect(body["pagination"]["per_page"]).to eq(20)
      expect(body["pagination"]["total_count"]).to eq(2)
      expect(body["pagination"]["total_pages"]).to eq(1)
    end

    it "filters by severity" do
      get "/tailscope/api/issues", params: { severity: "critical" }

      body = JSON.parse(response.body)
      expect(body["issues"].size).to eq(1)
      expect(body["issues"].first["severity"]).to eq("critical")
    end

    it "returns only ignored issues when tab=ignored" do
      Tailscope::Storage.ignore_issue(fingerprint: "abc123", title: "N+1", issue_type: "n_plus_one")

      get "/tailscope/api/issues", params: { tab: "ignored" }

      body = JSON.parse(response.body)
      expect(body["issues"].size).to eq(1)
      expect(body["issues"].first["fingerprint"]).to eq("abc123")
    end

    context "pagination" do
      let(:many_issues) do
        25.times.map do |i|
          Tailscope::Issue.new(
            severity: :info, type: :slow_query, title: "Query #{i}",
            description: "test", source_file: "/app/user.rb", source_line: i,
            suggested_fix: "fix", occurrences: 1, raw_ids: [], raw_type: "query",
            fingerprint: "issue#{i}", total_duration_ms: 100.0, latest_at: nil, metadata: {}
          )
        end
      end

      before do
        allow(Tailscope::IssueBuilder).to receive(:build_all).and_return(many_issues)
      end

      it "paginates results with default per_page" do
        get "/tailscope/api/issues", params: { page: 1, per_page: 10 }

        body = JSON.parse(response.body)
        expect(body["issues"].size).to eq(10)
        expect(body["pagination"]["page"]).to eq(1)
        expect(body["pagination"]["per_page"]).to eq(10)
        expect(body["pagination"]["total_count"]).to eq(25)
        expect(body["pagination"]["total_pages"]).to eq(3)
      end

      it "returns second page of results" do
        get "/tailscope/api/issues", params: { page: 2, per_page: 10 }

        body = JSON.parse(response.body)
        expect(body["issues"].size).to eq(10)
        expect(body["pagination"]["page"]).to eq(2)
        expect(body["issues"].first["title"]).to eq("Query 10")
      end

      it "returns last page with remaining items" do
        get "/tailscope/api/issues", params: { page: 3, per_page: 10 }

        body = JSON.parse(response.body)
        expect(body["issues"].size).to eq(5)
        expect(body["pagination"]["page"]).to eq(3)
        expect(body["issues"].first["title"]).to eq("Query 20")
      end

      it "caps per_page at 100" do
        get "/tailscope/api/issues", params: { per_page: 500 }

        body = JSON.parse(response.body)
        expect(body["pagination"]["per_page"]).to eq(100)
      end

      it "defaults to page 1 if invalid page provided" do
        get "/tailscope/api/issues", params: { page: 0 }

        body = JSON.parse(response.body)
        expect(body["pagination"]["page"]).to eq(1)
      end
    end
  end

  describe "POST /tailscope/api/issues/:fingerprint/ignore" do
    it "marks issue as ignored" do
      post "/tailscope/api/issues/abc123/ignore"

      expect(response).to have_http_status(:ok)
      expect(Tailscope::Storage.ignored_fingerprints).to include("abc123")
    end
  end

  describe "POST /tailscope/api/issues/:fingerprint/unignore" do
    it "removes ignored status" do
      Tailscope::Storage.ignore_issue(fingerprint: "abc123", title: "N+1", issue_type: "n_plus_one")

      post "/tailscope/api/issues/abc123/unignore"

      expect(response).to have_http_status(:ok)
      expect(Tailscope::Storage.ignored_fingerprints).not_to include("abc123")
    end
  end

  describe "POST /tailscope/api/issues/bulk_ignore" do
    it "marks multiple issues as ignored" do
      post "/tailscope/api/issues/bulk_ignore", params: { fingerprints: ["abc123", "def456"] }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["ok"]).to eq(true)
      expect(body["count"]).to eq(2)
      expect(Tailscope::Storage.ignored_fingerprints).to include("abc123")
      expect(Tailscope::Storage.ignored_fingerprints).to include("def456")
    end

    it "returns 400 when fingerprints param is missing" do
      post "/tailscope/api/issues/bulk_ignore", params: {}

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("fingerprints required")
    end

    it "ignores only existing issues" do
      post "/tailscope/api/issues/bulk_ignore", params: { fingerprints: ["abc123", "nonexistent"] }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["count"]).to eq(1)
      expect(Tailscope::Storage.ignored_fingerprints).to include("abc123")
      expect(Tailscope::Storage.ignored_fingerprints).not_to include("nonexistent")
    end

    it "handles empty fingerprints array" do
      post "/tailscope/api/issues/bulk_ignore", params: { fingerprints: [] }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["count"]).to eq(0)
    end
  end
end
