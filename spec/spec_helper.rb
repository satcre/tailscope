# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/application"

# Initialize the dummy app (guard for mutant which may have already booted it)
Dummy::Application.initialize! unless Dummy::Application.initialized?

require "rspec/rails"
require "tmpdir"

RSpec.configure do |config|
  config.before(:suite) do
    Tailscope.configuration.database_path = File.join(Dir.tmpdir, "tailscope_test_#{$$}.sqlite3")
    Tailscope.configuration.source_root = File.expand_path("dummy", __dir__)
    Tailscope.configuration.enabled = false
  end

  config.before(:each) do
    Tailscope::Database.reset!
    Tailscope::Schema.create_tables!
    # Clean all tables before each test
    db = Tailscope::Database.connection
    db.execute("DELETE FROM tailscope_queries")
    db.execute("DELETE FROM tailscope_requests")
    db.execute("DELETE FROM tailscope_errors")
    db.execute("DELETE FROM tailscope_jobs")
    db.execute("DELETE FROM tailscope_breakpoints")
  end

  config.after(:suite) do
    db_path = Tailscope.configuration.database_path
    File.delete(db_path) if db_path && File.exist?(db_path)
  end
end
