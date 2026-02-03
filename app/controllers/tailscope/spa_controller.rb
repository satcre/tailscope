# frozen_string_literal: true

module Tailscope
  class SpaController < ApplicationController
    layout false

    def index
      render :index
    end
  end
end
