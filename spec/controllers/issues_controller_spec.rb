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
    it "returns issues with counts" do
      get "/tailscope/api/issues"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["issues"].size).to eq(2)
      expect(body["ignored_count"]).to eq(0)
      expect(body["counts"]["critical"]).to eq(1)
      expect(body["counts"]["warning"]).to eq(1)
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
end
