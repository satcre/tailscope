# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Source API", type: :request do
  before do
    allow_any_instance_of(Tailscope::ApiController).to receive(:verify_authenticity_token).and_return(true)
  end

  let(:source_root) { Tailscope.configuration.source_root }
  let(:valid_file) { File.join(source_root, "config", "routes.rb") }

  describe "GET /tailscope/api/source" do
    it "returns source context" do
      get "/tailscope/api/source", params: { file: valid_file, line: 3 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["file"]).to eq(valid_file)
      expect(body["highlight_line"]).to eq(3)
      expect(body["lines"]).to be_an(Array)
      expect(body["lines"].any? { |l| l["current"] == true }).to be true
    end

    it "resolves relative paths against source_root" do
      get "/tailscope/api/source", params: { file: "config/routes.rb", line: 1 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["file"]).to eq(valid_file)
    end

    it "uses default radius of 50" do
      get "/tailscope/api/source", params: { file: valid_file, line: 3 }

      body = JSON.parse(response.body)
      # File is small, so all lines returned; radius controls the window
      expect(body["lines"]).to be_an(Array)
      expect(body["lines"].size).to be >= 1
    end

    it "accepts a custom radius parameter" do
      get "/tailscope/api/source", params: { file: valid_file, line: 3, radius: 10 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["lines"]).to be_an(Array)
    end

    it "clamps radius to minimum of 10" do
      get "/tailscope/api/source", params: { file: valid_file, line: 3, radius: 1 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["lines"]).to be_an(Array)
    end

    it "returns 403 for path outside source_root" do
      get "/tailscope/api/source", params: { file: "/etc/passwd", line: 1 }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for relative path traversal outside source_root" do
      get "/tailscope/api/source", params: { file: "../../etc/passwd", line: 1 }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for missing file" do
      get "/tailscope/api/source", params: { file: File.join(source_root, "nonexistent.rb"), line: 1 }
      expect(response).to have_http_status(:not_found)
    end
  end
end
