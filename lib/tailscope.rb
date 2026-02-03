# frozen_string_literal: true

require "tailscope/version"
require "tailscope/configuration"
require "tailscope/database"
require "tailscope/schema"
require "tailscope/storage"
require "tailscope/source_locator"
require "tailscope/detectors/n_plus_one"
require "tailscope/middleware/request_tracker"
require "tailscope/subscribers/sql_subscriber"
require "tailscope/subscribers/action_subscriber"
require "tailscope/subscribers/http_subscriber"
require "tailscope/subscribers/job_subscriber"
require "tailscope/subscribers/mailer_subscriber"
require "tailscope/subscribers/cache_subscriber"
require "tailscope/subscribers/view_subscriber"
require "tailscope/subscribers/controller_subscriber"
require "tailscope/instrumentors/net_http"
require "tailscope/instrumentors/callbacks"
require "tailscope/debugger"
require "tailscope/issue_builder"
require "tailscope/code_analyzer"

require "tailscope/engine" if defined?(Rails)
require "tailscope/railtie" if defined?(Rails::Railtie)

module Tailscope
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def enabled?
      configuration.enabled
    end

    def setup!
      return unless enabled?

      Schema.create_tables!
      Storage.start_writer!
      Debugger.setup!
      schedule_purge!
    end

    def shutdown!
      Debugger.shutdown!
      Storage.stop_writer!
    end

    private

    def schedule_purge!
      Thread.new do
        sleep 5
        begin
          Storage.purge!
        rescue => e
          warn "[Tailscope] Purge error: #{e.message}"
        end
      end
    end
  end
end
