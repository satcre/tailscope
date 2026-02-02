# frozen_string_literal: true

module Tailscope
  class IssuesController < ApplicationController
    def index
      all_issues = IssueBuilder.build_all
      ignored_fps = Storage.ignored_fingerprints

      @tab = params[:tab]&.to_sym
      if @tab == :ignored
        @issues = all_issues.select { |i| ignored_fps.include?(i.fingerprint) }
      else
        @issues = all_issues.reject { |i| ignored_fps.include?(i.fingerprint) }
      end

      @ignored_count = all_issues.count { |i| ignored_fps.include?(i.fingerprint) }

      @filter = params[:severity]&.to_sym
      @issues = @issues.select { |i| i.severity == @filter } if @filter.present? && @tab != :ignored
    end

    def ignore
      fingerprint = params[:fingerprint]
      all_issues = IssueBuilder.build_all
      issue = all_issues.find { |i| i.fingerprint == fingerprint }

      Storage.ignore_issue(
        fingerprint: fingerprint,
        title: issue&.title,
        issue_type: issue&.type&.to_s
      )

      redirect_to tailscope.root_path, status: :see_other
    end

    def unignore
      Storage.unignore_issue(params[:fingerprint])
      redirect_to tailscope.root_path(tab: :ignored), status: :see_other
    end
  end
end
