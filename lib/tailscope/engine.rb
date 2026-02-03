# frozen_string_literal: true

module Tailscope
  class Engine < ::Rails::Engine
    isolate_namespace Tailscope

    initializer "tailscope.assets" do |app|
      app.middleware.use(
        Rack::Static,
        urls: ["/tailscope/app.js", "/tailscope/app.css"],
        root: File.expand_path("../../public", __dir__)
      )
    end
  end
end
