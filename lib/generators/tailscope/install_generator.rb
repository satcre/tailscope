# frozen_string_literal: true

module Tailscope
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a Tailscope initializer and mounts the engine."

      def copy_initializer
        template "initializer.rb.tt", "config/initializers/tailscope.rb"
      end

      def mount_engine
        route 'mount Tailscope::Engine, at: "/tailscope"'
      end

      def show_readme
        say ""
        say "Tailscope installed!", :green
        say "Visit /tailscope in your browser to see the dashboard."
        say "Run `bundle exec tailscope stats` for CLI access."
      end
    end
  end
end
