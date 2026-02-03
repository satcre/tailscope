# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Subscribers::SqlSubscriber do
  subject(:subscriber) { described_class.new }

  let(:payload) { { name: "User Load", sql: "SELECT * FROM users" } }
  let(:event) { double("Event", duration: duration, payload: payload) }
  let(:duration) { 10.0 }

  after do
    Thread.current[:tailscope_query_log] = nil
    Tailscope.configuration.enabled = false
  end

  describe "#handle" do
    it "does nothing when disabled" do
      Tailscope.configuration.enabled = false
      expect(Tailscope::Storage).not_to receive(:record_query)
      subscriber.handle(event)
    end

    context "when enabled" do
      before { Tailscope.configuration.enabled = true }

      it "ignores SCHEMA queries" do
        ev = double("Event", duration: 200.0, payload: { name: "SCHEMA", sql: "SELECT * FROM sqlite_master" })
        expect(Tailscope::Storage).not_to receive(:record_query)
        subscriber.handle(ev)
      end

      it "ignores EXPLAIN queries" do
        ev = double("Event", duration: 200.0, payload: { name: "EXPLAIN", sql: "EXPLAIN SELECT 1" })
        expect(Tailscope::Storage).not_to receive(:record_query)
        subscriber.handle(ev)
      end

      it "ignores blank SQL" do
        ev = double("Event", duration: 200.0, payload: { name: "User Load", sql: "" })
        expect(Tailscope::Storage).not_to receive(:record_query)
        subscriber.handle(ev)
      end

      it "adds to thread-local query log" do
        Thread.current[:tailscope_query_log] = []
        subscriber.handle(event)
        expect(Thread.current[:tailscope_query_log].length).to eq(1)
        expect(Thread.current[:tailscope_query_log].first[:sql]).to eq("SELECT * FROM users")
      end

      it "records slow queries above threshold" do
        Tailscope.configuration.slow_query_threshold_ms = 50
        slow = double("Event", duration: 150.0, payload: { name: "User Load", sql: "SELECT * FROM users" })
        expect(Tailscope::Storage).to receive(:record_query).with(hash_including(sql_text: "SELECT * FROM users"))
        subscriber.handle(slow)
      end

      it "does not record queries below threshold" do
        Tailscope.configuration.slow_query_threshold_ms = 100
        expect(Tailscope::Storage).not_to receive(:record_query)
        subscriber.handle(event)
      end
    end
  end
end
