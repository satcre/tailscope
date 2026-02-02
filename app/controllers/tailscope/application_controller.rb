# frozen_string_literal: true

module Tailscope
  class ApplicationController < ActionController::Base
    layout "layouts/application"

    private

    def page_param
      [(params[:page] || 1).to_i, 1].max
    end

    def per_page
      50
    end

    def offset
      (page_param - 1) * per_page
    end

    helper_method :per_page, :page_param
  end
end
