# frozen_string_literal: true

module Tailscope
  class DebuggerController < ApplicationController
    before_action :ensure_debugger_enabled

    def index
      @breakpoints = Debugger::BreakpointManager.list_breakpoints
      @active_sessions = Debugger::SessionStore.active_sessions
      @recent_sessions = Debugger::SessionStore.all_sessions.first(20)
    end

    def create_breakpoint
      file = params[:file].to_s.strip
      line = params[:line].to_i

      source_root = Tailscope.configuration.source_root
      unless file.start_with?(source_root)
        head :forbidden
        return
      end

      unless File.exist?(file)
        head :not_found
        return
      end

      Debugger::BreakpointManager.add_breakpoint(file: file, line: line, condition: params[:condition])
      redirect_to debugger_index_path
    end

    def remove_breakpoint
      Debugger::BreakpointManager.remove_breakpoint(params[:id].to_i)
      redirect_to debugger_index_path
    end

    def show_session
      @session = Debugger::SessionStore.find(params[:id])
      unless @session
        head :not_found
        return
      end

      @source_lines = @session.source_context(radius: 15)
      @locals = @session.local_variables_hash
    end

    def evaluate
      session = Debugger::SessionStore.find(params[:id])
      unless session
        render json: { error: "Session not found" }, status: :not_found
        return
      end

      result = session.evaluate(params[:expression].to_s)
      render json: result
    end

    def continue_session
      session = Debugger::SessionStore.find(params[:id])
      session&.continue!
      redirect_to debugger_index_path
    end

    def step_into
      session = Debugger::SessionStore.find(params[:id])
      unless session&.paused?
        redirect_to debugger_index_path, alert: "Session not available"
        return
      end
      session.step_into!
      redirect_to debugger_index_path
    end

    def step_over
      session = Debugger::SessionStore.find(params[:id])
      unless session&.paused?
        redirect_to debugger_index_path, alert: "Session not available"
        return
      end
      session.step_over!
      redirect_to debugger_index_path
    end

    def step_out
      session = Debugger::SessionStore.find(params[:id])
      unless session&.paused?
        redirect_to debugger_index_path, alert: "Session not available"
        return
      end
      session.step_out!
      redirect_to debugger_index_path
    end

    def poll
      sessions = Debugger::SessionStore.active_sessions.map do |s|
        { id: s.id, file: s.file, line: s.line, method_name: s.method_name, created_at: s.created_at.iso8601 }
      end
      render json: { active_sessions: sessions }
    end

    def browse
      source_root = Tailscope.configuration.source_root
      @root = source_root
      @path = params[:path].to_s

      if @path.empty?
        @path = source_root
      end

      unless @path.start_with?(source_root)
        head :forbidden
        return
      end

      unless File.exist?(@path)
        head :not_found
        return
      end

      if File.directory?(@path)
        @is_directory = true
        entries = Dir.entries(@path).reject { |e| e.start_with?(".") }.sort
        @directories = entries.select { |e| File.directory?(File.join(@path, e)) }
        @files = entries.select { |e| File.file?(File.join(@path, e)) }
      else
        @is_directory = false
        @lines = File.readlines(@path)
        @breakpoint_lines = Set.new
        Debugger::BreakpointManager.list_breakpoints.each do |bp|
          @breakpoint_lines.add(bp["line"]) if bp["file"] == @path
        end
      end
    end

    private

    def ensure_debugger_enabled
      return if Debugger.enabled?

      head :forbidden
    end
  end
end
