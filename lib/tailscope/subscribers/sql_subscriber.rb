# frozen_string_literal: true

module Tailscope
  module Subscribers
    class SqlSubscriber
      IGNORED_NAMES = %w[SCHEMA EXPLAIN].freeze

      def self.attach!
        ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          new.handle(event)
        end
      end

      def handle(event)
        return unless Tailscope.enabled?

        name = event.payload[:name]
        return if name && IGNORED_NAMES.include?(name)

        sql = event.payload[:sql]
        return if sql.blank?

        duration_ms = event.duration

        source = Tailscope::SourceLocator.locate(caller_locations(2))

        # Add to per-request query log for N+1 detection
        if Thread.current[:tailscope_query_log]
          Thread.current[:tailscope_query_log] << {
            sql: sql,
            duration_ms: duration_ms,
            name: name,
            source: source,
          }
        end

        # Record queries: all queries during a tracked request, or slow standalone queries
        if duration_ms >= Tailscope.configuration.slow_query_threshold_ms || Thread.current[:tailscope_request_id]
          Tailscope::Storage.record_query(
            sql_text: sql.to_s[0..2000],
            duration_ms: duration_ms.round(2),
            name: name,
            source_file: source[:source_file],
            source_line: source[:source_line],
            source_method: source[:source_method],
            request_id: Thread.current[:tailscope_request_id],
          )
        end
      end
    end
  end
end
