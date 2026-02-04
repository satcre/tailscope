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

      def install_frontend_dependencies
        say "Installing frontend dependencies...", :blue
        client_path = Gem.loaded_specs["tailscope"].full_gem_path + "/client"

        return unless File.directory?(client_path)
        return unless File.exist?(File.join(client_path, "package.json"))

        Dir.chdir(client_path) do
          system("npm install --silent")
        end
      end

      def show_readme
        say ""
        say "Tailscope installed!", :green
        say "Visit /tailscope in your browser to see the dashboard."
        say "Run `bundle exec tailscope stats` for CLI access."
        say ""
        say "To update Tailscope in the future:", :yellow
        say "  bundle update tailscope"
        say "  rails generate tailscope:install"
      end
    end
  end
end
