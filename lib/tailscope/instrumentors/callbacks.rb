# frozen_string_literal: true

module Tailscope
  module Instrumentors
    module CallbacksBefore
      def call(env)
        return super unless Tailscope.enabled?
        return super unless Thread.current[:tailscope_request_id]

        req_start = Thread.current[:tailscope_request_start]
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        result = super
        result
      ensure
        if start
          duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0

          if duration_ms >= 0.01
            filter_name = filter.is_a?(Symbol) ? filter : filter.class.name
            source_file, source_line = resolve_callback_source(env&.target, filter)
            started_at_ms = req_start ? (start - req_start) * 1000.0 : nil

            Tailscope::Storage.record_service(
              category: "callback",
              name: "before_action :#{filter_name}",
              duration_ms: duration_ms.round(2),
              started_at_ms: started_at_ms&.round(2),
              detail: { kind: "before", filter: filter_name.to_s },
              source_file: source_file,
              source_line: source_line,
              source_method: filter_name.to_s,
              request_id: Thread.current[:tailscope_request_id],
            )
          end
        end
      end

      private

      def resolve_callback_source(target, filter_sym)
        return [nil, nil] unless target && filter_sym.is_a?(Symbol)

        method = target.method(filter_sym)
        method.source_location
      rescue NameError, TypeError
        [nil, nil]
      end
    end

    module CallbacksAfter
      def call(env)
        return super unless Tailscope.enabled?
        return super unless Thread.current[:tailscope_request_id]

        req_start = Thread.current[:tailscope_request_start]
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        result = super
        result
      ensure
        if start
          duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0

          if duration_ms >= 0.01
            filter_name = respond_to?(:filter, true) ? (filter.is_a?(Symbol) ? filter : filter.class.name) : "after"
            started_at_ms = req_start ? (start - req_start) * 1000.0 : nil

            Tailscope::Storage.record_service(
              category: "callback",
              name: "after_action :#{filter_name}",
              duration_ms: duration_ms.round(2),
              started_at_ms: started_at_ms&.round(2),
              detail: { kind: "after", filter: filter_name.to_s },
              source_file: nil,
              source_line: nil,
              source_method: filter_name.to_s,
              request_id: Thread.current[:tailscope_request_id],
            )
          end
        end
      end
    end

    # Wraps the actual controller action method (e.g. #create, #show)
    module ActionMethod
      def send_action(method_name, *args)
        return super unless Tailscope.enabled?
        return super unless Thread.current[:tailscope_request_id]

        req_start = Thread.current[:tailscope_request_start]
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        super
      ensure
        if start
          duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0

          if duration_ms >= 0.01
            started_at_ms = req_start ? (start - req_start) * 1000.0 : nil

            source_file = nil
            source_line = nil
            begin
              m = self.class.instance_method(method_name.to_sym)
              source_file, source_line = m.source_location
            rescue NameError
            end

            controller_name = self.class.name
            unless controller_name&.start_with?("Tailscope::")
              Tailscope::Storage.record_service(
                category: "action",
                name: "#{controller_name}##{method_name}",
                duration_ms: duration_ms.round(2),
                started_at_ms: started_at_ms&.round(2),
                detail: { controller: controller_name, action: method_name.to_s },
                source_file: source_file,
                source_line: source_line,
                source_method: method_name.to_s,
                request_id: Thread.current[:tailscope_request_id],
              )
            end
          end
        end
      end
    end
  end
end

if defined?(ActiveSupport::Callbacks::Filters::Before)
  ActiveSupport::Callbacks::Filters::Before.prepend(Tailscope::Instrumentors::CallbacksBefore)
  ActiveSupport::Callbacks::Filters::After.prepend(Tailscope::Instrumentors::CallbacksAfter)
end

if defined?(ActiveSupport)
  ActiveSupport.on_load(:action_controller) do
    prepend Tailscope::Instrumentors::ActionMethod
  end
end
