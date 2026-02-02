# frozen_string_literal: true

module Tailscope
  class SourceController < ApplicationController
    def show
      @file = params[:file]
      @line = (params[:line] || 1).to_i

      source_root = Tailscope.configuration.source_root
      unless @file&.start_with?(source_root)
        head :forbidden
        return
      end

      unless File.exist?(@file)
        head :not_found
        return
      end

      @lines = File.readlines(@file)
      @start_line = [(@line - 10), 0].max
      @end_line = [(@line + 10), @lines.size - 1].min
      @visible_lines = @lines[@start_line..@end_line] || []
    end
  end
end
