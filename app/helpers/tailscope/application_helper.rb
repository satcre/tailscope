# frozen_string_literal: true

module Tailscope
  module ApplicationHelper
    def duration_badge(ms)
      return "" unless ms

      color = if ms >= 1000
        "bg-red-100 text-red-800"
      elsif ms >= 500
        "bg-yellow-100 text-yellow-800"
      elsif ms >= 100
        "bg-orange-100 text-orange-800"
      else
        "bg-green-100 text-green-800"
      end

      content_tag(:span, "#{ms.round(1)}ms", class: "inline-block px-2 py-0.5 text-xs font-medium rounded #{color}")
    end

    def source_link(file, line)
      return "—" unless file

      short = file.sub(Tailscope.configuration.source_root + "/", "")
      link_to "#{short}:#{line}", tailscope.source_path(file: file, line: line),
        class: "text-blue-600 hover:underline font-mono text-sm"
    end

    def time_ago_in_words_short(time_str)
      return "—" unless time_str

      time = Time.parse(time_str)
      diff = Time.now - time
      if diff < 60
        "#{diff.to_i}s ago"
      elsif diff < 3600
        "#{(diff / 60).to_i}m ago"
      elsif diff < 86400
        "#{(diff / 3600).to_i}h ago"
      else
        "#{(diff / 86400).to_i}d ago"
      end
    end

    def truncate_sql(sql, length: 120)
      return "" unless sql

      sql.length > length ? sql[0...length] + "..." : sql
    end

    def severity_badge(severity)
      colors = {
        critical: "bg-red-100 text-red-800",
        warning: "bg-yellow-100 text-yellow-800",
        info: "bg-blue-100 text-blue-800",
      }
      content_tag(:span, severity.to_s.upcase,
        class: "inline-block px-2 py-0.5 text-xs font-bold rounded #{colors[severity]}")
    end

    def issue_border_class(severity)
      { critical: "border-red-500", warning: "border-yellow-500", info: "border-blue-400" }[severity] || "border-gray-300"
    end

    def format_suggested_fix(text)
      return "" unless text

      html = ERB::Util.html_escape(text)
      # Convert `code` to <code> tags
      html = html.gsub(/`([^`]+)`/, '<code class="px-1 py-0.5 bg-gray-200 text-gray-800 rounded text-xs font-mono">\1</code>')
      # Convert \n to <br>
      html = html.gsub("\n", "<br>")
      html.html_safe
    end

    def issue_detail_path(issue)
      return nil if issue.raw_ids.empty?

      case issue.raw_type
      when "query"
        tailscope.query_path(issue.raw_ids.first)
      when "request"
        tailscope.request_path(issue.raw_ids.first)
      when "error"
        tailscope.error_path(issue.raw_ids.first)
      end
    end
  end
end
