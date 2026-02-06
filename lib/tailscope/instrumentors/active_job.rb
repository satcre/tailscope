# frozen_string_literal: true

if defined?(ActiveSupport)
  module Tailscope
    module Instrumentors
      module ActiveJobTracking
        extend ActiveSupport::Concern

        included do
          around_perform do |job, block|
            if Tailscope.enabled?
              tracking_id = "job_#{job.job_id}"
              Thread.current[:tailscope_request_id] = tracking_id
              Thread.current[:tailscope_query_log] = []
              Thread.current[:tailscope_request_start] = Process.clock_gettime(Process::CLOCK_MONOTONIC)

              begin
                block.call
              ensure
                Thread.current[:tailscope_request_id] = nil
                Thread.current[:tailscope_query_log] = nil
                Thread.current[:tailscope_request_start] = nil
              end
            else
              block.call
            end
          end
        end
      end
    end
  end

  ActiveSupport.on_load(:active_job) do
    include Tailscope::Instrumentors::ActiveJobTracking
  end
end
