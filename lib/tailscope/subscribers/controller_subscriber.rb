# frozen_string_literal: true

module Tailscope
  module Subscribers
    class ControllerSubscriber
      def self.attach!
        ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          new.handle(event)
        end
      end

      def handle(event)
        return unless Tailscope.enabled?

        payload = event.payload
        return if payload[:controller]&.start_with?("Tailscope::")

        request_id = Thread.current[:tailscope_request_id]
        return unless request_id

        req_start = Thread.current[:tailscope_request_start]
        return unless req_start

        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        duration_ms = (now - req_start) * 1000.0

        return unless duration_ms >= 0.01

        Tailscope::Storage.record_service(
          category: "middleware",
          name: "Middleware & routing",
          duration_ms: duration_ms.round(2),
          started_at_ms: 0.0,
          detail: {},
          source_file: nil,
          source_line: nil,
          source_method: nil,
          request_id: request_id,
        )
      end
    end
  end
end
