# frozen_string_literal: true

module Tailscope
  class DashboardController < ApplicationController
    def index
      redirect_to tailscope.root_path
    end
  end
end
