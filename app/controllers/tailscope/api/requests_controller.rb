# frozen_string_literal: true

module Tailscope
  module Api
    class RequestsController < ApiController
      def index
        requests = Storage.requests(limit: per_page, offset: offset)
        total = Storage.requests_count

        render json: {
          requests: requests,
          total: total,
          page: page_param,
          per_page: per_page,
          has_more: requests.size == per_page,
        }
      end

      def destroy_all
        Storage.delete_all_requests
        head :no_content
      end

      def show
        request_record = Storage.find_request(params[:id])
        return render(json: { error: "Not found" }, status: :not_found) unless request_record

        # Backfill source_file for old records that don't have it
        if request_record["source_file"].nil? && request_record["controller"] && request_record["action"]
          source_file, source_line = resolve_action_source(
            request_record["controller"], request_record["action"]
          )
          request_record = request_record.merge("source_file" => source_file, "source_line" => source_line)
        end

        queries = Storage.queries_for_request(request_record["request_id"])
        errors = Storage.errors_for_request(request_record["request_id"])
        services = Storage.services_for_request(request_record["request_id"])

        render json: {
          request: request_record,
          queries: queries,
          errors: errors,
          services: services,
        }
      end

      private

      def resolve_action_source(controller_name, action_name)
        klass = controller_name.safe_constantize
        return [nil, nil] unless klass

        method = klass.instance_method(action_name.to_sym)
        method.source_location
      rescue NameError, TypeError
        [nil, nil]
      end
    end
  end
end
