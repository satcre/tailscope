# frozen_string_literal: true

module Tailscope
  module Api
    class SourceController < ApiController
      def show
        file = params[:file].to_s
        line = params[:line].to_i
        source_root = Tailscope.configuration.source_root

        # Resolve relative paths against source root
        unless file.start_with?("/")
          file = File.join(source_root, file)
        end

        unless file.start_with?(source_root)
          return render(json: { error: "Forbidden" }, status: :forbidden)
        end

        unless File.exist?(file)
          return render(json: { error: "File not found" }, status: :not_found)
        end

        lines = File.readlines(file)
        radius = (params[:radius] || 50).to_i.clamp(10, 200)
        start_line = [line - radius, 0].max
        end_line = [line + radius, lines.size - 1].min
        visible_lines = lines[start_line..end_line] || []

        render json: {
          file: file,
          short_path: file.sub("#{source_root}/", ""),
          highlight_line: line,
          lines: visible_lines.each_with_index.map do |content, idx|
            {
              number: start_line + idx + 1,
              content: content.chomp,
              current: (start_line + idx + 1) == line,
            }
          end,
        }
      end
    end
  end
end
