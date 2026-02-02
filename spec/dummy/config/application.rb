# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "active_record/railtie"
require "tailscope"

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = false
    config.active_support.deprecation = :stderr
    config.secret_key_base = "test-secret-key-base-for-tailscope-dummy-app"
    config.active_record.maintain_test_schema = false
    config.hosts.clear

    # Point Rails at the dummy app's own directories
    config.root = File.expand_path("..", __dir__)
    paths["config/routes.rb"] = File.expand_path("../config/routes.rb", __dir__)
    paths["app/controllers"] = File.expand_path("../app/controllers", __dir__)
  end
end
