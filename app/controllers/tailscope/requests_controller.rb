# frozen_string_literal: true

module Tailscope
  class RequestsController < ApplicationController
    def index
      @requests = Storage.requests(limit: per_page, offset: offset)
      @page = page_param
    end

    def show
      @request_record = Storage.find_request(params[:id])
      return head(:not_found) unless @request_record

      @queries = Storage.queries_for_request(@request_record["request_id"])
      @errors = Storage.errors_for_request(@request_record["request_id"])
    end
  end
end
