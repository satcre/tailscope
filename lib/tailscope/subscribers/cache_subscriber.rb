# frozen_string_literal: true

module Tailscope
  module Subscribers
    class CacheSubscriber
      SLOW_THRESHOLD_MS = 10

      EVENTS = %w[
        cache_read.active_support
        cache_write.active_support
        cache_delete.active_support
        cache_fetch_hit.active_support
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
        return unless event.duration >= SLOW_THRESHOLD_MS

        request_id = Thread.current[:tailscope_request_id]
        return unless request_id

        payload = event.payload
        operation = event.name.sub(".active_support", "").sub("cache_", "")
        source = Tailscope::SourceLocator.locate(caller_locations(2))

        Tailscope::Storage.record_service(
          category: "cache",
          name: "Cache #{operation}",
          duration_ms: event.duration.round(2),
          detail: {
            operation: operation,
            key: payload[:key].to_s[0..200],
          },
          source_file: source[:source_file],
          source_line: source[:source_line],
          source_method: source[:source_method],
          request_id: request_id,
        )
      end
    end
  end
end
