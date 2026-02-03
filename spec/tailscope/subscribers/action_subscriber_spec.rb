# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Subscribers::ActionSubscriber do
  subject(:subscriber) { described_class.new }

  let(:payload) do
    {
      controller: "UsersController",
      action: "index",
      method: "GET",
      path: "/users",
      status: 200,
      view_runtime: 100.0,
      db_runtime: 400.0,
      params: { "id" => "1" },
    }
  end
  let(:event) { double("Event", duration: 600.0, payload: payload) }

  after do
    Thread.current[:tailscope_request_id] = nil
    Tailscope.configuration.enabled = false
  end

  describe "#handle" do
    it "does nothing when disabled" do
      Tailscope.configuration.enabled = false
      expect(Tailscope::Storage).not_to receive(:record_request)
      subscriber.handle(event)
    end

    context "when enabled" do
      before { Tailscope.configuration.enabled = true }

      it "skips Tailscope:: controller actions" do
        ev = double("Event", duration: 600.0, payload: payload.merge(controller: "Tailscope::DashboardController"))
        expect(Tailscope::Storage).not_to receive(:record_request)
        subscriber.handle(ev)
      end

      it "records slow requests above threshold" do
        Tailscope.configuration.slow_request_threshold_ms = 500
        expect(Tailscope::Storage).to receive(:record_request).with(hash_including(
          method: "GET", path: "/users", controller: "UsersController"
        ))
        subscriber.handle(event)
      end

      it "does not record requests below threshold" do
        Tailscope.configuration.slow_request_threshold_ms = 500
        fast = double("Event", duration: 100.0, payload: payload)
        expect(Tailscope::Storage).not_to receive(:record_request)
        subscriber.handle(fast)
      end
    end
  end
end
