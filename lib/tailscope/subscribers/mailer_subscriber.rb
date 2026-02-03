# frozen_string_literal: true

module Tailscope
  module Subscribers
    class MailerSubscriber
      def self.attach!
        ActiveSupport::Notifications.subscribe("deliver.action_mailer") do |*args|
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
          category: "mailer",
          name: "#{payload[:mailer]}##{payload[:action]}",
          duration_ms: event.duration.round(2),
          detail: {
            mailer: payload[:mailer],
            action: payload[:action],
            to: Array(payload[:to]).join(", "),
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
