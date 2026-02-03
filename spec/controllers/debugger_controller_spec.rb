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
end
