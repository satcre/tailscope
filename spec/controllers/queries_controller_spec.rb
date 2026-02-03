# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Queries API", type: :request do
  before do
    allow_any_instance_of(Tailscope::ApiController).to receive(:verify_authenticity_token).and_return(true)
  end

  describe "GET /tailscope/api/queries" do
    it "returns queries" do
      Tailscope::Storage.record_query(sql_text: "SELECT 1", duration_ms: 50.0)
      Tailscope::Storage.record_query(sql_text: "SELECT 2", duration_ms: 30.0)

      get "/tailscope/api/queries"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["queries"].size).to eq(2)
      expect(body).to have_key("page")
      expect(body).to have_key("has_more")
    end

    it "filters by n_plus_one_only" do
      Tailscope::Storage.record_query(sql_text: "SELECT 1", duration_ms: 50.0, n_plus_one: true, n_plus_one_count: 5)
      Tailscope::Storage.record_query(sql_text: "SELECT 2", duration_ms: 30.0)

      get "/tailscope/api/queries", params: { n_plus_one_only: "true" }

      body = JSON.parse(response.body)
      expect(body["queries"].size).to eq(1)
      expect(body["queries"].first["n_plus_one"]).to eq(1)
    end
  end

  describe "GET /tailscope/api/queries/:id" do
    it "returns query when found" do
      Tailscope::Storage.record_query(sql_text: "SELECT 1", duration_ms: 50.0)
      query = Tailscope::Storage.queries.first

      get "/tailscope/api/queries/#{query['id']}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["query"]["sql_text"]).to eq("SELECT 1")
    end

    it "returns 404 when not found" do
      get "/tailscope/api/queries/99999"
      expect(response).to have_http_status(:not_found)
    end
  end
end
