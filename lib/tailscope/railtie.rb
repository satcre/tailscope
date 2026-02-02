# frozen_string_literal: true

module Tailscope
  class Railtie < Rails::Railtie
    initializer "tailscope.configure" do
      Tailscope.configuration.database_path ||= Rails.root.join("db", "tailscope.sqlite3").to_s
      Tailscope.configuration.source_root ||= Rails.root.to_s
    end

    initializer "tailscope.middleware" do |app|
      app.middleware.insert_before(0, Tailscope::Middleware::RequestTracker)
    end

    config.after_initialize do
      if Tailscope.enabled?
        Tailscope.setup!
        Tailscope::Subscribers::SqlSubscriber.attach!
        Tailscope::Subscribers::ActionSubscriber.attach!
      end
    end

    at_exit do
      Tailscope.shutdown!
    end
  end
end
