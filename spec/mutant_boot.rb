# frozen_string_literal: true

# Boot file for mutant - loads the dummy Rails app so all Tailscope
# constants are available when mutant resolves subject expressions.
ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/application"
Dummy::Application.initialize!
