# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Requests API", type: :request do
  before do
    allow_any_instance_of(Tailscope::ApiController).to receive(:verify_authenticity_token).and_return(true)
  end

  describe "GET /tailscope/api/requests" do
    it "returns requests" do
      Tailscope::Storage.record_request(method: "GET", path: "/users", status: 200, duration_ms: 100.0, request_id: "req-1")

      get "/tailscope/api/requests"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["requests"].size).to eq(1)
      expect(body).to have_key("page")
    end
  end

  describe "GET /tailscope/api/requests/:id" do
    it "returns request with associated queries and errors" do
      Tailscope::Storage.record_request(method: "GET", path: "/users", status: 200, duration_ms: 100.0, request_id: "req-abc")
      Tailscope::Storage.record_query(sql_text: "SELECT 1", duration_ms: 10.0, request_id: "req-abc")
      Tailscope::Storage.record_error(exception_class: "RuntimeError", message: "boom", backtrace: ["l1"], request_id: "req-abc", request_method: "GET", request_path: "/users")

      request_record = Tailscope::Storage.requests.first

      get "/tailscope/api/requests/#{request_record['id']}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["request"]["path"]).to eq("/users")
      expect(body["queries"].size).to eq(1)
      expect(body["errors"].size).to eq(1)
    end

    it "returns 404 when not found" do
      get "/tailscope/api/requests/99999"
      expect(response).to have_http_status(:not_found)
    end
  end
end
