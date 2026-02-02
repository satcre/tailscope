# frozen_string_literal: true

module Tailscope
  class QueriesController < ApplicationController
    def index
      @n_plus_one_only = params[:n_plus_one] == "1"
      @queries = Storage.queries(limit: per_page, offset: offset, n_plus_one_only: @n_plus_one_only)
      @page = page_param
    end

    def show
      @query = Storage.find_query(params[:id])
      head :not_found unless @query
    end
  end
end
