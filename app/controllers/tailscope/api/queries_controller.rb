# frozen_string_literal: true

module Tailscope
  module Api
    class QueriesController < ApiController
      def index
        n_plus_one_only = params[:n_plus_one_only] == "true"
        queries = Storage.queries(limit: per_page, offset: offset, n_plus_one_only: n_plus_one_only)
        total = Storage.queries_count(n_plus_one_only: n_plus_one_only)

        render json: {
          queries: queries,
          total: total,
          page: page_param,
          per_page: per_page,
          has_more: queries.size == per_page,
        }
      end

      def destroy_all
        Storage.delete_all_queries
        head :no_content
      end

      def show
        query = Storage.find_query(params[:id])
        return render(json: { error: "Not found" }, status: :not_found) unless query

        render json: { query: query }
      end
    end
  end
end
