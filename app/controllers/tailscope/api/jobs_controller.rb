# frozen_string_literal: true

module Tailscope
  module Api
    class JobsController < ApiController
      def index
        jobs = Storage.jobs(limit: per_page, offset: offset)
        total = Storage.jobs_count

        render json: {
          jobs: jobs,
          total: total,
          page: page_param,
          per_page: per_page,
          has_more: jobs.size == per_page,
        }
      end

      def show
        job = Storage.find_job(params[:id])
        return render(json: { error: "Not found" }, status: :not_found) unless job

        queries = Storage.queries_for_job(job["job_id"])
        services = Storage.services_for_job(job["job_id"])

        render json: { job: job, queries: queries, services: services }
      end

      def destroy_all
        Storage.delete_all_jobs
        head :no_content
      end
    end
  end
end
