# frozen_string_literal: true

require_relative "lib/tailscope/version"

Gem::Specification.new do |spec|
  spec.name = "tailscope"
  spec.version = Tailscope::VERSION
  spec.authors = ["Tailscope"]
  spec.summary = "Rails debugging & tracing: slow queries, N+1 detection, request timing, error capture, test runner, and job monitoring"
  spec.description = "A Rails engine and CLI that captures slow queries, N+1 patterns, slow requests, runtime errors, and background job executions. Includes a browser-based RSpec test runner. Provides a web dashboard and CLI for viewing issues with source-level detail."
  spec.homepage = "https://github.com/tailscope/tailscope"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,lib,bin}/**/*", "LICENSE.txt", "README.md"]
  end
  spec.bindir = "bin"
  spec.executables = ["tailscope"]
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 6.0"
  spec.add_dependency "actionpack", ">= 6.0"
  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "sqlite3", ">= 1.4"
  spec.add_dependency "thor", ">= 1.0"

  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
