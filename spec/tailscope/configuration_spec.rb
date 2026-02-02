# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Configuration do
  subject(:config) { described_class.new }

  it "has sensible defaults" do
    expect(config.slow_query_threshold_ms).to eq(100)
    expect(config.slow_request_threshold_ms).to eq(500)
    expect(config.n_plus_one_threshold).to eq(3)
    expect(config.storage_retention_days).to eq(7)
  end

  it "allows overrides via configure block" do
    Tailscope.configure do |c|
      c.slow_query_threshold_ms = 200
    end
    expect(Tailscope.configuration.slow_query_threshold_ms).to eq(200)
    Tailscope.configuration.slow_query_threshold_ms = 100
  end
end
