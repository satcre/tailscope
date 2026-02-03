# frozen_string_literal: true

module Tailscope
  class ApiController < ActionController::API
    include ActionController::RequestForgeryProtection

    protect_from_forgery with: :exception

    rescue_from StandardError do |e|
      render json: { error: e.message }, status: :internal_server_error
    end

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
  end
end
