# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::TestRunner do
  after do
    # Reset module state between tests
    described_class.instance_variable_set(:@current_run, nil)
  end

  describe ".available?" do
    it "returns false when Rails is not defined" do
      allow(described_class).to receive(:available?).and_call_original
      hide_const("Rails")
      expect(described_class.available?).to eq(false)
    end

    it "returns false when spec directory does not exist" do
      spec_dir = double("Pathname", directory?: false)
      allow(Rails.root).to receive(:join).with("spec").and_return(spec_dir)
      expect(described_class.available?).to eq(false)
    end
  end

  describe ".discover_specs" do
    it "returns unavailable when not available" do
      allow(described_class).to receive(:available?).and_return(false)

      result = described_class.discover_specs
      expect(result[:available]).to eq(false)
      expect(result[:tree]).to eq([])
    end
  end

  describe ".running?" do
    it "returns falsey when no run exists" do
      expect(described_class.running?).to be_falsey
    end

    it "returns true when a run is in progress" do
      described_class.instance_variable_set(:@current_run, { status: "running" })
      expect(described_class.running?).to eq(true)
    end

    it "returns false when run is finished" do
      described_class.instance_variable_set(:@current_run, { status: "finished" })
      expect(described_class.running?).to eq(false)
    end
  end

  describe ".run!" do
    it "returns error when already running" do
      described_class.instance_variable_set(:@current_run, { status: "running" })
      result = described_class.run!
      expect(result[:error]).to eq("Already running")
    end

    it "starts a run and returns id and status" do
      # Stub the thread so we don't actually spawn rspec
      allow(Thread).to receive(:new).and_return(double("Thread"))

      result = described_class.run!
      expect(result[:id]).to be_a(String)
      expect(result[:status]).to eq("running")
    end
  end

  describe ".cancel!" do
    it "returns error when no run in progress" do
      result = described_class.cancel!
      expect(result[:error]).to eq("No run in progress")
    end

    it "cancels a running run" do
      described_class.instance_variable_set(:@current_run, { status: "running", pid: nil })
      result = described_class.cancel!
      expect(result[:status]).to eq("cancelled")
    end
  end

  describe ".status" do
    it "returns nil run when no run exists" do
      result = described_class.status
      expect(result[:run]).to be_nil
    end

    it "returns run data without pid" do
      described_class.instance_variable_set(:@current_run, {
        id: "test-123",
        status: "finished",
        pid: 12345,
        summary: { total: 1 },
      })

      result = described_class.status
      expect(result[:run][:id]).to eq("test-123")
      expect(result[:run]).not_to have_key(:pid)
    end
  end

  describe "target sanitization" do
    it "rejects targets with path traversal" do
      allow(Thread).to receive(:new).and_return(double("Thread"))

      expect {
        described_class.run!(target: "spec/../../../etc/passwd")
      }.to raise_error(RuntimeError, /Invalid target/)
    end

    it "rejects targets outside spec/" do
      allow(Thread).to receive(:new).and_return(double("Thread"))

      expect {
        described_class.run!(target: "app/models/user.rb")
      }.to raise_error(RuntimeError, /Invalid target/)
    end

    it "accepts valid spec paths" do
      allow(Thread).to receive(:new).and_return(double("Thread"))

      result = described_class.run!(target: "spec/models/user_spec.rb")
      expect(result[:status]).to eq("running")
    end

    it "accepts spec paths with line numbers" do
      allow(Thread).to receive(:new).and_return(double("Thread"))

      result = described_class.run!(target: "spec/models/user_spec.rb:15")
      expect(result[:status]).to eq("running")
    end
  end
end
