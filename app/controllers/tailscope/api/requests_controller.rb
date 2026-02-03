# frozen_string_literal: true

module Tailscope
  module Api
    class RequestsController < ApiController
      def index
        requests = Storage.requests(limit: per_page, offset: offset)

        render json: {
          requests: requests,
          page: page_param,
          per_page: per_page,
          has_more: requests.size == per_page,
        }
      end

      def show
        request_record = Storage.find_request(params[:id])
        return render(json: { error: "Not found" }, status: :not_found) unless request_record

        queries = Storage.queries_for_request(request_record["request_id"])
        errors = Storage.errors_for_request(request_record["request_id"])

        render json: {
          request: request_record,
          queries: queries,
          errors: errors,
        }
      end
    end
  end
end
