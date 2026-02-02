# frozen_string_literal: true

module Tailscope
  module Debugger
    module TraceHook
      IGNORE_PATTERNS = [
        %r{/tailscope/},
        %r{/ruby/gems/},
        %r{/bundler/},
        %r{<internal:},
        %r{/lib/ruby/},
      ].freeze

      class << self
        def setup!
          @trace = TracePoint.new(:line, :call, :return) do |tp|
            next if Thread.current[:tailscope_skip_trace]

            case tp.event
            when :call, :b_call
              Thread.current[:tailscope_call_depth] ||= 0
              Thread.current[:tailscope_call_depth] += 1
              next
            when :return, :b_return
              Thread.current[:tailscope_call_depth] ||= 0
              Thread.current[:tailscope_call_depth] -= 1
              next
            end

            # :line event
            path = tp.path
            next unless path

            abs_path = resolve_path(path)
            next if ignored?(abs_path)

            current_depth = Thread.current[:tailscope_call_depth] || 0

            # Check if we're in stepping mode
            stepping = Thread.current[:tailscope_stepping]
            if stepping
              should_pause = case stepping[:mode]
                             when :step_into then true
                             when :step_over then current_depth <= stepping[:target_depth]
                             when :step_out  then current_depth < stepping[:target_depth]
                             else false
                             end

              if should_pause
                Thread.current[:tailscope_stepping] = nil
                create_session(tp, abs_path, current_depth)
              end
              next
            end

            # Normal breakpoint checking
            next unless BreakpointManager.breakpoint_at?(abs_path, tp.lineno)

            # Evaluate conditional breakpoint
            bp = BreakpointManager.get_breakpoint(abs_path, tp.lineno)
            if bp && bp[:condition] && !bp[:condition].strip.empty?
              begin
                next unless tp.binding.eval(bp[:condition])
              rescue
                # Condition eval failed — pause anyway so user can see the issue
              end
            end

            create_session(tp, abs_path, current_depth)
          end
        end

        def refresh!
          if BreakpointManager.any_breakpoints? || has_stepping_threads?
            enable!
          else
            disable!
          end
        end

        def enable!
          return if @enabled

          @trace&.enable
          @enabled = true
        end

        def disable!
          return unless @enabled

          @trace&.disable
          @enabled = false
        end

        def enabled?
          @enabled == true
        end

        private

        def create_session(tp, abs_path, call_depth)
          Thread.current[:tailscope_skip_trace] = true
          begin
            session = Session.new(
              binding_obj: tp.binding,
              file: abs_path,
              line: tp.lineno,
              method_name: tp.method_id&.to_s,
              call_depth: call_depth
            )
            session.capture_call_stack!(caller_locations)
            SessionStore.add(session)
            session.wait!

            # After unblocking, check if user clicked a step button
            if session.stepping_mode
              Thread.current[:tailscope_stepping] = {
                mode: session.stepping_mode,
                target_depth: session.target_depth || call_depth,
              }
            end
          ensure
            Thread.current[:tailscope_skip_trace] = false
          end
        end

        def has_stepping_threads?
          Thread.list.any? { |t| t[:tailscope_stepping] }
        end

        def resolve_path(path)
          return path if path.start_with?("/")

          File.expand_path(path)
        end

        def ignored?(path)
          IGNORE_PATTERNS.any? { |pat| path.match?(pat) }
        end
      end
    end
  end
end
