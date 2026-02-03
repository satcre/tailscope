# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Editor API", type: :request do
  before do
    allow_any_instance_of(Tailscope::ApiController).to receive(:verify_authenticity_token).and_return(true)
  end

  let(:source_root) { Tailscope.configuration.source_root }
  let(:valid_file) { File.join(source_root, "config", "routes.rb") }

  describe "POST /tailscope/api/editor/open" do
    it "returns 403 for file outside source_root" do
      post "/tailscope/api/editor/open", params: { file: "/etc/passwd", line: 1 }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for non-existent file" do
      post "/tailscope/api/editor/open", params: { file: File.join(source_root, "nope.rb"), line: 1 }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when no editor configured" do
      allow(Tailscope.configuration).to receive(:resolve_editor).and_return(nil)

      post "/tailscope/api/editor/open", params: { file: valid_file, line: 1 }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 200 for valid request" do
      allow(Tailscope.configuration).to receive(:resolve_editor).and_return("echo {file}:{line}")
      allow(Tailscope.configuration).to receive(:editor_name).and_return("test")
      allow_any_instance_of(Tailscope::Api::EditorController).to receive(:spawn).and_return(123)
      allow(Process).to receive(:detach)

      post "/tailscope/api/editor/open", params: { file: valid_file, line: 5 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["ok"]).to eq(true)
    end
  end

  describe "POST /tailscope/api/editor/check" do
    it "returns 422 for unknown editor" do
      post "/tailscope/api/editor/check", params: { editor: "unknown" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 200 when binary found" do
      allow_any_instance_of(Tailscope::Api::EditorController).to receive(:system).and_return(true)

      post "/tailscope/api/editor/check", params: { editor: "vscode" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["available"]).to eq(true)
    end
  end
end
