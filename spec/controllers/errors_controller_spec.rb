# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Errors API", type: :request do
  before do
    allow_any_instance_of(Tailscope::ApiController).to receive(:verify_authenticity_token).and_return(true)
  end

  describe "GET /tailscope/api/errors" do
    it "returns errors" do
      Tailscope::Storage.record_error(exception_class: "RuntimeError", message: "boom", backtrace: ["l1"], request_method: "GET", request_path: "/test")

      get "/tailscope/api/errors"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["errors"].size).to eq(1)
      expect(body).to have_key("page")
    end
  end

  describe "GET /tailscope/api/errors/:id" do
    it "returns error when found" do
      Tailscope::Storage.record_error(exception_class: "RuntimeError", message: "boom", backtrace: ["l1"], request_method: "GET", request_path: "/test")
      error_record = Tailscope::Storage.errors.first

      get "/tailscope/api/errors/#{error_record['id']}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["error"]["exception_class"]).to eq("RuntimeError")
    end

    it "returns 404 when not found" do
      get "/tailscope/api/errors/99999"
      expect(response).to have_http_status(:not_found)
    end
  end
end
