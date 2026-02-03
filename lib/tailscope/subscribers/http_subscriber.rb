# frozen_string_literal: true

module Tailscope
  module Subscribers
    class HttpSubscriber
      def self.attach!
        ActiveSupport::Notifications.subscribe("request.net_http") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          new.handle(event)
        end
      end

      def handle(event)
        return unless Tailscope.enabled?

        request_id = Thread.current[:tailscope_request_id]
        return unless request_id

        payload = event.payload
        source = Tailscope::SourceLocator.locate(caller_locations(2))

        Tailscope::Storage.record_service(
          category: "http",
          name: "#{payload[:method]} #{payload[:uri]}",
          duration_ms: event.duration.round(2),
          detail: {
            method: payload[:method],
            url: payload[:uri],
            status: payload[:status],
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
