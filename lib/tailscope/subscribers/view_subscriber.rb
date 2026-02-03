# frozen_string_literal: true

module Tailscope
  module Subscribers
    class ViewSubscriber
      EVENTS = %w[
        render_template.action_view
        render_partial.action_view
      ].freeze

      def self.attach!
        EVENTS.each do |event_name|
          ActiveSupport::Notifications.subscribe(event_name) do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            new.handle(event)
          end
        end
      end

      def handle(event)
        return unless Tailscope.enabled?

        request_id = Thread.current[:tailscope_request_id]
        return unless request_id

        payload = event.payload
        identifier = payload[:identifier] || ""
        type = event.name.include?("partial") ? "partial" : "template"

        # Shorten the identifier for display
        short_name = identifier.sub(%r{.*/app/views/}, "").sub(%r{.*/app/}, "app/")

        started_at_ms = nil
        if Thread.current[:tailscope_request_start]
          event_end = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          started_at_ms = ((event_end - event.duration / 1000.0) - Thread.current[:tailscope_request_start]) * 1000.0
        end

        Tailscope::Storage.record_service(
          category: "view",
          name: short_name,
          duration_ms: event.duration.round(2),
          started_at_ms: started_at_ms&.round(2),
          detail: {
            identifier: identifier,
            type: type,
            layout: payload[:layout],
          },
          source_file: identifier.start_with?("/") ? identifier : nil,
          source_line: nil,
          source_method: nil,
          request_id: request_id,
        )
      end
    end
  end
end
