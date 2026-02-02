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

        duration_ms = event.duration
        request_id = Thread.current[:tailscope_request_id]

        # Update request record with controller/action details if it was slow
        if duration_ms >= Tailscope.configuration.slow_request_threshold_ms
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
          )
        end
      end
    end
  end
end
