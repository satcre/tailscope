# frozen_string_literal: true

module Tailscope
  module Api
    class DebuggerController < ApiController
      def index
        breakpoints = Debugger::BreakpointManager.list_breakpoints
        active_sessions = Debugger::SessionStore.active_sessions
        recent_sessions = Debugger::SessionStore.all_sessions.first(20)

        render json: {
          breakpoints: breakpoints,
          active_sessions: active_sessions.map { |s| session_summary(s) },
          recent_sessions: recent_sessions.map { |s| session_summary(s) },
        }
      end

      def create_breakpoint
        file = params[:file].to_s.strip
        line = params[:line].to_i
        source_root = Tailscope.configuration.source_root
        file = File.join(source_root, file) unless file.start_with?("/")
        file = File.expand_path(file)

        unless file.start_with?(source_root)
          return render(json: { error: "Forbidden" }, status: :forbidden)
        end

        Debugger::BreakpointManager.add_breakpoint(
          file: file, line: line, condition: params[:condition]
        )
        render json: { ok: true }
      end

      def remove_breakpoint
        Debugger::BreakpointManager.remove_breakpoint(params[:id].to_i)
        render json: { ok: true }
      end

      def show_session
        session = Debugger::SessionStore.find(params[:id])
        return render(json: { error: "Not found" }, status: :not_found) unless session

        render json: {
          session: {
            id: session.id,
            file: session.file,
            line: session.line,
            method_name: session.method_name,
            status: session.status,
            paused: session.paused?,
            source_context: session.source_context(radius: 15),
            local_variables: session.local_variables_hash,
            call_stack: session.call_stack,
            eval_history: session.eval_history,
          },
        }
      end

      def evaluate
        session = Debugger::SessionStore.find(params[:id])
        return render(json: { error: "Not found" }, status: :not_found) unless session

        result = session.evaluate(params[:expression].to_s)
        render json: result
      end

      def continue_session
        session = Debugger::SessionStore.find(params[:id])
        session&.continue!
        render json: { ok: true }
      end

      def step_into
        session = Debugger::SessionStore.find(params[:id])
        return render(json: { error: "Not available" }, status: :bad_request) unless session&.paused?

        session.step_into!
        render json: { ok: true }
      end

      def step_over
        session = Debugger::SessionStore.find(params[:id])
        return render(json: { error: "Not available" }, status: :bad_request) unless session&.paused?

        session.step_over!
        render json: { ok: true }
      end

      def step_out
        session = Debugger::SessionStore.find(params[:id])
        return render(json: { error: "Not available" }, status: :bad_request) unless session&.paused?

        session.step_out!
        render json: { ok: true }
      end

      def poll
        sessions = Debugger::SessionStore.active_sessions.map { |s| session_summary(s) }
        render json: { active_sessions: sessions }
      end

      def browse
        source_root = Tailscope.configuration.source_root
        path = params[:path].to_s
        path = source_root if path.empty?
        path = File.join(source_root, path) unless path.start_with?("/")
        path = File.expand_path(path)

        unless path.start_with?(source_root)
          return render(json: { error: "Forbidden" }, status: :forbidden)
        end

        unless File.exist?(path)
          return render(json: { error: "Not found" }, status: :not_found)
        end

        if File.directory?(path)
          skip = %w[node_modules tmp log .git vendor public .bundle storage].to_set
          entries = Dir.entries(path).reject { |e| e.start_with?(".") || skip.include?(e) }.sort
          render json: {
            is_directory: true,
            path: path,
            root: source_root,
            directories: entries.select { |e| File.directory?(File.join(path, e)) },
            files: entries.select { |e| File.file?(File.join(path, e)) },
          }
        else
          lines = File.readlines(path)
          bp_lines = Set.new
          Debugger::BreakpointManager.list_breakpoints.each do |bp|
            bp_lines.add(bp["line"]) if bp["file"] == path
          end

          render json: {
            is_directory: false,
            path: path,
            lines: lines.map(&:chomp),
            breakpoint_lines: bp_lines.to_a,
          }
        end
      end

      private

      def session_summary(session)
        {
          id: session.id,
          file: session.file,
          line: session.line,
          method_name: session.method_name,
          status: session.status,
        }
      end
    end
  end
end
