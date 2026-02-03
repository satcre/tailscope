# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tests API", type: :request do
  before do
    allow_any_instance_of(Tailscope::ApiController).to receive(:verify_authenticity_token).and_return(true)
  end

  describe "GET /tailscope/api/tests/specs" do
    it "returns spec tree when available" do
      allow(Tailscope::TestRunner).to receive(:discover_specs).and_return(
        { available: true, tree: [{ path: "spec/models", name: "models", type: "folder", children: [] }] }
      )

      get "/tailscope/api/tests/specs"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["available"]).to eq(true)
      expect(body["tree"]).to be_an(Array)
    end

    it "returns unavailable when RSpec is not installed" do
      allow(Tailscope::TestRunner).to receive(:discover_specs).and_return(
        { available: false, tree: [] }
      )

      get "/tailscope/api/tests/specs"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["available"]).to eq(false)
      expect(body["tree"]).to eq([])
    end
  end

  describe "POST /tailscope/api/tests/run" do
    it "starts a spec run" do
      allow(Tailscope::TestRunner).to receive(:run!).and_return(
        { id: "abc123", status: "running" }
      )

      post "/tailscope/api/tests/run"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq("abc123")
      expect(body["status"]).to eq("running")
    end

    it "passes target parameter" do
      allow(Tailscope::TestRunner).to receive(:run!)
        .with(target: "spec/models/user_spec.rb")
        .and_return({ id: "abc123", status: "running" })

      post "/tailscope/api/tests/run", params: { target: "spec/models/user_spec.rb" }

      expect(response).to have_http_status(:ok)
    end

    it "returns 409 when already running" do
      allow(Tailscope::TestRunner).to receive(:run!).and_return(
        { error: "Already running" }
      )

      post "/tailscope/api/tests/run"

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Already running")
    end
  end

  describe "GET /tailscope/api/tests/status" do
    it "returns current run status" do
      allow(Tailscope::TestRunner).to receive(:status).and_return(
        {
          run: {
            id: "abc123",
            status: "finished",
            target: "all",
            summary: { total: 5, passed: 4, failed: 1, pending: 0, duration_s: 1.23 },
            examples: [],
            console_output: "..F..",
          },
        }
      )

      get "/tailscope/api/tests/status"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["run"]["status"]).to eq("finished")
      expect(body["run"]["summary"]["total"]).to eq(5)
    end

    it "returns null run when no run exists" do
      allow(Tailscope::TestRunner).to receive(:status).and_return({ run: nil })

      get "/tailscope/api/tests/status"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["run"]).to be_nil
    end
  end

  describe "GET /tailscope/api/tests/examples" do
    it "returns discovered examples for a target" do
      allow(Tailscope::TestRunner).to receive(:dry_run)
        .with("spec/models/user_spec.rb")
        .and_return({
          examples: [
            { id: "./spec/models/user_spec.rb[1:1]", description: "is valid", full_description: "User is valid", file_path: "./spec/models/user_spec.rb", line_number: 5 },
          ],
        })

      get "/tailscope/api/tests/examples", params: { target: "spec/models/user_spec.rb" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["examples"].size).to eq(1)
      expect(body["examples"].first["description"]).to eq("is valid")
    end
  end

  describe "POST /tailscope/api/tests/cancel" do
    it "cancels a running spec" do
      allow(Tailscope::TestRunner).to receive(:cancel!).and_return(
        { status: "cancelled" }
      )

      post "/tailscope/api/tests/cancel"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("cancelled")
    end

    it "returns 409 when no run in progress" do
      allow(Tailscope::TestRunner).to receive(:cancel!).and_return(
        { error: "No run in progress" }
      )

      post "/tailscope/api/tests/cancel"

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("No run in progress")
    end
  end
end
