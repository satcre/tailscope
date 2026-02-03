# frozen_string_literal: true

module Tailscope
  module Api
    class ErrorsController < ApiController
      def index
        errors = Storage.errors(limit: per_page, offset: offset)
        total = Storage.errors_count

        render json: {
          errors: errors,
          total: total,
          page: page_param,
          per_page: per_page,
          has_more: errors.size == per_page,
        }
      end

      def destroy_all
        Storage.delete_all_errors
        head :no_content
      end

      def show
        error = Storage.find_error(params[:id])
        return render(json: { error: "Not found" }, status: :not_found) unless error

        render json: { error: error }
      end
    end
  end
end
