# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Debugger API", type: :request do
  before do
    allow_any_instance_of(Tailscope::ApiController).to receive(:verify_authenticity_token).and_return(true)
    allow(Tailscope::Debugger::TraceHook).to receive(:refresh!)
    Tailscope::Debugger::BreakpointManager.setup!
    Tailscope::Debugger::SessionStore.setup!
  end

  let(:source_root) { Tailscope.configuration.source_root }
  let(:valid_file) { File.join(source_root, "config", "routes.rb") }

  describe "GET /tailscope/api/debugger" do
    it "returns breakpoints and sessions" do
      get "/tailscope/api/debugger"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to have_key("breakpoints")
      expect(body).to have_key("active_sessions")
      expect(body).to have_key("recent_sessions")
    end
  end

  describe "POST /tailscope/api/debugger/breakpoints" do
    it "creates a breakpoint" do
      post "/tailscope/api/debugger/breakpoints", params: { file: valid_file, line: 3 }

      expect(response).to have_http_status(:ok)
      bps = Tailscope::Debugger::BreakpointManager.list_breakpoints
      expect(bps.size).to eq(1)
      expect(bps.first["file"]).to eq(valid_file)
    end

    it "resolves relative paths against source_root" do
      post "/tailscope/api/debugger/breakpoints", params: { file: "config/routes.rb", line: 3 }

      expect(response).to have_http_status(:ok)
      bps = Tailscope::Debugger::BreakpointManager.list_breakpoints
      expect(bps.size).to eq(1)
      expect(bps.first["file"]).to eq(valid_file)
    end

    it "returns 403 for file outside source_root" do
      post "/tailscope/api/debugger/breakpoints", params: { file: "/etc/passwd", line: 1 }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for relative path traversal outside source_root" do
      post "/tailscope/api/debugger/breakpoints", params: { file: "../../etc/passwd", line: 1 }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /tailscope/api/debugger/breakpoints/:id" do
    it "removes a breakpoint" do
      Tailscope::Debugger::BreakpointManager.add_breakpoint(file: valid_file, line: 3)
      bp_id = Tailscope::Debugger::BreakpointManager.list_breakpoints.first["id"]

      delete "/tailscope/api/debugger/breakpoints/#{bp_id}"

      expect(response).to have_http_status(:ok)
      expect(Tailscope::Debugger::BreakpointManager.list_breakpoints).to be_empty
    end
  end

  describe "GET /tailscope/api/debugger/sessions/:id" do
    it "returns 404 when not found" do
      get "/tailscope/api/debugger/sessions/nonexistent"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /tailscope/api/debugger/poll" do
    it "returns active sessions" do
      get "/tailscope/api/debugger/poll"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["active_sessions"]).to be_an(Array)
    end
  end

  describe "GET /tailscope/api/debugger/browse" do
    it "returns directory listing" do
      get "/tailscope/api/debugger/browse"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["is_directory"]).to eq(true)
      expect(body).to have_key("directories")
      expect(body).to have_key("files")
    end

    it "returns file content" do
      get "/tailscope/api/debugger/browse", params: { path: valid_file }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["is_directory"]).to eq(false)
      expect(body["lines"]).to be_an(Array)
    end

    it "resolves relative paths against source_root" do
      get "/tailscope/api/debugger/browse", params: { path: "config/routes.rb" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["is_directory"]).to eq(false)
      expect(body["path"]).to eq(valid_file)
    end

    it "returns 403 for path outside source_root" do
      get "/tailscope/api/debugger/browse", params: { path: "/etc" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for relative path traversal outside source_root" do
      get "/tailscope/api/debugger/browse", params: { path: "../../etc/passwd" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /tailscope/api/debugger/analyze_file" do
    let(:ruby_file) { File.join(source_root, "app", "models", "user.rb") }

    before do
      FileUtils.mkdir_p(File.dirname(ruby_file))
      File.write(ruby_file, "class User < ApplicationRecord\n  # TODO: add validations\nend\n")
      # Clear analysis cache
      Tailscope::Storage.delete_file_analysis(ruby_file)
    end

    after do
      File.delete(ruby_file) if File.exist?(ruby_file)
    end

    it "analyzes a Ruby file and returns issues" do
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "app/models/user.rb" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to have_key("issues")
      expect(body).to have_key("analyzed_at")
      expect(body["cached"]).to eq(false)
      expect(body["issues"]).to be_an(Array)
    end

    it "caches analysis results" do
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "app/models/user.rb" }

      expect(response).to have_http_status(:ok)
      first_body = JSON.parse(response.body)
      expect(first_body["cached"]).to eq(false)
      first_analyzed_at = first_body["analyzed_at"]

      # Second request should return cached result
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "app/models/user.rb" }

      expect(response).to have_http_status(:ok)
      second_body = JSON.parse(response.body)
      expect(second_body["cached"]).to eq(true)
      expect(second_body["analyzed_at"]).not_to be_nil
      # Both timestamps should be present (may have different formats but should be similar)
      expect(second_body["analyzed_at"]).to match(/#{first_analyzed_at.split('T').first}/)
    end

    it "forces fresh analysis when force=true" do
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "app/models/user.rb" }
      first_analyzed_at = JSON.parse(response.body)["analyzed_at"]

      sleep(1.1) # Ensure time difference (need at least 1 second for timestamp)

      post "/tailscope/api/debugger/analyze_file", params: { file_path: "app/models/user.rb", force: true }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["cached"]).to eq(false)
      expect(body["analyzed_at"]).not_to eq(first_analyzed_at)
    end

    it "resolves relative paths against source_root" do
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "app/models/user.rb" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["issues"]).to be_an(Array)
    end

    it "returns 403 for file outside source_root" do
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "/etc/passwd" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for relative path traversal outside source_root" do
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "../../etc/passwd" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for non-existent file" do
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "app/models/nonexistent.rb" }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 for non-Ruby file" do
      text_file = File.join(source_root, "test.txt")
      File.write(text_file, "not ruby")

      post "/tailscope/api/debugger/analyze_file", params: { file_path: "test.txt" }
      expect(response).to have_http_status(:unprocessable_entity)

      File.delete(text_file) if File.exist?(text_file)
    end

    it "returns issues with all required fields" do
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "app/models/user.rb" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      issues = body["issues"]

      if issues.any?
        issue = issues.first
        expect(issue).to have_key("fingerprint")
        expect(issue).to have_key("title")
        expect(issue).to have_key("description")
        expect(issue).to have_key("severity")
        expect(issue).to have_key("type")
        expect(issue).to have_key("source_file")
        expect(issue).to have_key("source_line")
      end
    end
  end

  describe "GET /tailscope/api/debugger/file_analysis_status" do
    let(:ruby_file) { File.join(source_root, "app", "models", "user.rb") }

    before do
      FileUtils.mkdir_p(File.dirname(ruby_file))
      File.write(ruby_file, "class User < ApplicationRecord\n  # TODO: add validations\nend\n")
      # Clear analysis cache
      Tailscope::Storage.delete_file_analysis(ruby_file)
    end

    after do
      File.delete(ruby_file) if File.exist?(ruby_file)
    end

    it "returns cached status when file has been analyzed" do
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "app/models/user.rb" }

      get "/tailscope/api/debugger/file_analysis_status", params: { file_path: "app/models/user.rb" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["cached"]).to eq(true)
      expect(body).to have_key("analyzed_at")
      expect(body).to have_key("issue_count")
      expect(body["issue_count"]).to be_a(Integer)
    end

    it "returns not cached status for unanalyzed file" do
      get "/tailscope/api/debugger/file_analysis_status", params: { file_path: "app/models/user.rb" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["cached"]).to eq(false)
    end

    it "resolves relative paths against source_root" do
      post "/tailscope/api/debugger/analyze_file", params: { file_path: "app/models/user.rb" }

      get "/tailscope/api/debugger/file_analysis_status", params: { file_path: "app/models/user.rb" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["cached"]).to eq(true)
    end

    it "returns 403 for file outside source_root" do
      get "/tailscope/api/debugger/file_analysis_status", params: { file_path: "/etc/passwd" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for relative path traversal outside source_root" do
      get "/tailscope/api/debugger/file_analysis_status", params: { file_path: "../../etc/passwd" }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
