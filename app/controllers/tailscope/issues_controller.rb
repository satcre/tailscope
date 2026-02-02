# frozen_string_literal: true

module Tailscope
  class IssuesController < ApplicationController
    def index
      @issues = IssueBuilder.build_all
      @filter = params[:severity]&.to_sym
      @issues = @issues.select { |i| i.severity == @filter } if @filter.present?
    end
  end
end
