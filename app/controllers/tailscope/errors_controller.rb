# frozen_string_literal: true

module Tailscope
  class ErrorsController < ApplicationController
    def index
      @errors = Storage.errors(limit: per_page, offset: offset)
      @page = page_param
    end

    def show
      @error = Storage.find_error(params[:id])
      head :not_found unless @error
    end
  end
end
