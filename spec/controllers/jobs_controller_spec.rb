# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Jobs API", type: :request do
  before do
    allow_any_instance_of(Tailscope::ApiController).to receive(:verify_authenticity_token).and_return(true)
  end

  describe "GET /tailscope/api/jobs" do
    it "returns paginated jobs" do
      Tailscope::Storage.record_job(job_class: "SendEmailJob", job_id: "j1", queue_name: "default", status: "performed", duration_ms: 100.0)
      Tailscope::Storage.record_job(job_class: "ProcessOrderJob", job_id: "j2", queue_name: "high", status: "performed", duration_ms: 200.0)

      get "/tailscope/api/jobs"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["jobs"].size).to eq(2)
      expect(body).to have_key("total")
      expect(body).to have_key("page")
      expect(body).to have_key("per_page")
      expect(body).to have_key("has_more")
    end

    it "returns empty list when no jobs" do
      get "/tailscope/api/jobs"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["jobs"]).to eq([])
      expect(body["total"]).to eq(0)
    end
  end

  describe "GET /tailscope/api/jobs/:id" do
    it "returns job with associated queries and services" do
      Tailscope::Storage.record_job(job_class: "TestJob", job_id: "j1", queue_name: "default", status: "performed", duration_ms: 50.0, request_id: "job_j1")
      job = Tailscope::Storage.jobs.first

      get "/tailscope/api/jobs/#{job['id']}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["job"]["job_class"]).to eq("TestJob")
      expect(body).to have_key("queries")
      expect(body).to have_key("services")
    end

    it "returns 404 when not found" do
      get "/tailscope/api/jobs/99999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /tailscope/api/jobs" do
    it "deletes all jobs" do
      Tailscope::Storage.record_job(job_class: "Job1", job_id: "j1", queue_name: "q", status: "performed", duration_ms: 10.0)
      Tailscope::Storage.record_job(job_class: "Job2", job_id: "j2", queue_name: "q", status: "performed", duration_ms: 20.0)

      delete "/tailscope/api/jobs"

      expect(response).to have_http_status(:no_content)
      expect(Tailscope::Storage.jobs_count).to eq(0)
    end
  end
end
