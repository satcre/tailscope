# frozen_string_literal: true

module Tailscope
  module Subscribers
    class JobSubscriber
      def self.attach!
        ActiveSupport::Notifications.subscribe("enqueue.active_job") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          new.handle_enqueue(event)
        end

        ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          new.handle_perform(event)
        end
      end

      def handle_enqueue(event)
        return unless Tailscope.enabled?

        job = event.payload[:job]
        request_id = Thread.current[:tailscope_request_id]
        source = Tailscope::SourceLocator.locate(caller_locations(2))

        Tailscope::Storage.record_job(
          job_class: job.class.name,
          job_id: job.job_id,
          queue_name: job.queue_name,
          status: "enqueued",
          duration_ms: event.duration.round(2),
          source_file: source[:source_file],
          source_line: source[:source_line],
          request_id: request_id,
        )

        # Also record as service for request trace
        if request_id
          Tailscope::Storage.record_service(
            category: "job",
            name: "Enqueue #{job.class.name}",
            duration_ms: event.duration.round(2),
            started_at_ms: compute_started_at_ms(event),
            detail: {
              job_class: job.class.name,
              queue: job.queue_name,
              action: "enqueue",
            },
            source_file: source[:source_file],
            source_line: source[:source_line],
            source_method: source[:source_method],
            request_id: request_id,
          )
        end
      end

      def handle_perform(event)
        return unless Tailscope.enabled?

        job = event.payload[:job]
        tracking_id = "job_#{job.job_id}"
        exception = event.payload[:exception_object]

        source = Tailscope::SourceLocator.locate(caller_locations(2))

        Tailscope::Storage.record_job(
          job_class: job.class.name,
          job_id: job.job_id,
          queue_name: job.queue_name,
          status: exception ? "failed" : "performed",
          duration_ms: event.duration.round(2),
          error_class: exception&.class&.name,
          error_message: exception&.message&.to_s&.slice(0, 1000),
          source_file: source[:source_file],
          source_line: source[:source_line],
          request_id: tracking_id,
        )
      end

      private

      def compute_started_at_ms(event)
        return nil unless Thread.current[:tailscope_request_start]
        event_end = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ((event_end - event.duration / 1000.0) - Thread.current[:tailscope_request_start]) * 1000.0
      end
    end
  end
end
