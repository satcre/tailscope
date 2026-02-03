# frozen_string_literal: true

module Tailscope
  module Api
    class IssuesController < ApiController
      def index
        all_issues = IssueBuilder.build_all
        ignored_fps = Storage.ignored_fingerprints

        tab = params[:tab]&.to_sym
        issues = if tab == :ignored
          all_issues.select { |i| ignored_fps.include?(i.fingerprint) }
        else
          all_issues.reject { |i| ignored_fps.include?(i.fingerprint) }
        end

        filter = params[:severity]&.to_sym
        issues = issues.select { |i| i.severity == filter } if filter.present? && tab != :ignored

        ignored_count = all_issues.count { |i| ignored_fps.include?(i.fingerprint) }

        render json: {
          issues: issues.map { |i| serialize_issue(i) },
          ignored_count: ignored_count,
          counts: {
            critical: issues.count { |i| i.severity == :critical },
            warning: issues.count { |i| i.severity == :warning },
            info: issues.count { |i| i.severity == :info },
          },
        }
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

        render json: { ok: true }
      end

      def unignore
        Storage.unignore_issue(params[:fingerprint])
        render json: { ok: true }
      end

      private

      def serialize_issue(issue)
        {
          fingerprint: issue.fingerprint,
          title: issue.title,
          description: issue.description,
          severity: issue.severity,
          type: issue.type,
          occurrences: issue.occurrences,
          total_duration_ms: issue.total_duration_ms,
          source_file: issue.source_file,
          source_line: issue.source_line,
          latest_at: issue.latest_at,
          suggested_fix: issue.suggested_fix,
          metadata: issue.metadata,
          raw_ids: issue.raw_ids,
          raw_type: issue.raw_type,
        }
      end
    end
  end
end
