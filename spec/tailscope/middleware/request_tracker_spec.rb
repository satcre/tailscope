# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Middleware::RequestTracker do
  let(:app) { ->(env) { [200, {}, ["OK"]] } }
  let(:middleware) { described_class.new(app) }

  around(:each) do |example|
    Tailscope.configuration.enabled = true
    example.run
  ensure
    Tailscope.configuration.enabled = false
  end

  it "passes through when disabled" do
    Tailscope.configuration.enabled = false
    status, = middleware.call("PATH_INFO" => "/test", "REQUEST_METHOD" => "GET")
    expect(status).to eq(200)
  end

  it "skips tailscope routes" do
    status, = middleware.call("PATH_INFO" => "/tailscope/queries", "REQUEST_METHOD" => "GET")
    expect(status).to eq(200)
    expect(Thread.current[:tailscope_request_id]).to be_nil
  end

  it "sets request_id on thread" do
    called_with_id = nil
    inner_app = lambda do |env|
      called_with_id = Thread.current[:tailscope_request_id]
      [200, {}, ["OK"]]
    end
    mw = described_class.new(inner_app)
    mw.call("PATH_INFO" => "/users", "REQUEST_METHOD" => "GET")
    expect(called_with_id).not_to be_nil
  end

  it "captures exceptions and re-raises" do
    error_app = ->(_env) { raise "boom" }
    mw = described_class.new(error_app)

    expect {
      mw.call("PATH_INFO" => "/explode", "REQUEST_METHOD" => "POST")
    }.to raise_error(RuntimeError, "boom")

    errors = Tailscope::Storage.errors
    expect(errors.size).to eq(1)
    expect(errors.first["exception_class"]).to eq("RuntimeError")
  end
end
