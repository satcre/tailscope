# frozen_string_literal: true

require "tailscope/debugger/breakpoint_manager"
require "tailscope/debugger/session"
require "tailscope/debugger/trace_hook"

module Tailscope
  module Debugger
    class << self
      def setup!
        return unless enabled?

        BreakpointManager.setup!
        SessionStore.setup!
        TraceHook.setup!
        TraceHook.refresh!
      end

      def shutdown!
        TraceHook.disable!
      end

      def enabled?
        Tailscope.configuration.debugger_enabled
      end
    end
  end
end
