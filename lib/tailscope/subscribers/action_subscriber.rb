# frozen_string_literal: true

module Tailscope
  module Subscribers
    class ActionSubscriber
      def self.attach!
        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          new.handle(event)
        end
      end

      def handle(event)
        return unless Tailscope.enabled?

        payload = event.payload
        return if payload[:controller]&.start_with?("Tailscope::")

        req_start = Thread.current[:tailscope_request_start]
        duration_ms = if req_start
          (Process.clock_gettime(Process::CLOCK_MONOTONIC) - req_start) * 1000.0
        else
          event.duration
        end
        request_id = Thread.current[:tailscope_request_id]

        source_file, source_line = resolve_source(payload[:controller], payload[:action])

        Tailscope::Storage.record_request(
          method: payload[:method],
          path: payload[:path],
          status: payload[:status],
          duration_ms: duration_ms.round(2),
          controller: payload[:controller],
          action: payload[:action],
          view_runtime_ms: payload[:view_runtime]&.round(2),
          db_runtime_ms: payload[:db_runtime]&.round(2),
          params: payload[:params]&.except("controller", "action"),
          request_id: request_id,
          source_file: source_file,
          source_line: source_line,
        )
      end
      private

      def resolve_source(controller_name, action_name)
        return [nil, nil] unless controller_name && action_name

        klass = controller_name.safe_constantize
        return [nil, nil] unless klass

        method = klass.instance_method(action_name.to_sym)
        method.source_location
      rescue NameError, TypeError
        [nil, nil]
      end
    end
  end
end
