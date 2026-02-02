# frozen_string_literal: true

module Tailscope
  module Middleware
    class RequestTracker
      def initialize(app)
        @app = app
      end

      def call(env)
        return @app.call(env) unless Tailscope.enabled?
        return @app.call(env) if tailscope_request?(env)

        request_id = env["action_dispatch.request_id"] || SecureRandom.hex(8)
        Thread.current[:tailscope_request_id] = request_id
        Thread.current[:tailscope_query_log] = []

        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          status, headers, response = @app.call(env)

          Tailscope::Detectors::NPlusOne.analyze!(request_id)

          [status, headers, response]
        rescue Exception => e
          duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
          record_error(e, env, request_id, duration_ms)
          raise
        ensure
          Thread.current[:tailscope_request_id] = nil
          Thread.current[:tailscope_query_log] = nil
        end
      end

      private

      def tailscope_request?(env)
        env["PATH_INFO"]&.start_with?("/tailscope")
      end

      def record_error(exception, env, request_id, duration_ms)
        source = Tailscope::SourceLocator.locate(exception.backtrace_locations)
        Tailscope::Storage.record_error(
          exception_class: exception.class.name,
          message: exception.message.to_s[0..1000],
          backtrace: exception.backtrace&.first(20),
          source_file: source[:source_file],
          source_line: source[:source_line],
          source_method: source[:source_method],
          request_method: env["REQUEST_METHOD"],
          request_path: env["PATH_INFO"],
          params: filtered_params(env),
          request_id: request_id,
          duration_ms: duration_ms&.round(2),
        )
      end

      def filtered_params(env)
        if env["action_dispatch.request.parameters"]
          env["action_dispatch.request.parameters"]
            .except("controller", "action")
            .reject { |_, v| v.is_a?(ActionDispatch::Http::UploadedFile) rescue false }
        else
          {}
        end
      end
    end
  end
end
