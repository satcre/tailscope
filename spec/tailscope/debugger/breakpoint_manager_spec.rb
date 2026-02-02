# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Debugger::BreakpointManager do
  before do
    # Stub TraceHook.refresh! to avoid enabling TracePoint in tests
    allow(Tailscope::Debugger::TraceHook).to receive(:refresh!)
    described_class.setup!
  end

  describe ".add_breakpoint / .list_breakpoints" do
    it "adds and lists a breakpoint" do
      id = described_class.add_breakpoint(file: "/app/foo.rb", line: 10)
      expect(id).to be_a(Integer)

      bps = described_class.list_breakpoints
      expect(bps.size).to eq(1)
      expect(bps.first["file"]).to eq("/app/foo.rb")
      expect(bps.first["line"]).to eq(10)
    end
  end

  describe ".breakpoint_at?" do
    it "returns true when breakpoint exists" do
      described_class.add_breakpoint(file: "/app/foo.rb", line: 5)
      expect(described_class.breakpoint_at?("/app/foo.rb", 5)).to be true
    end

    it "returns false when no breakpoint" do
      expect(described_class.breakpoint_at?("/app/foo.rb", 99)).to be false
    end
  end

  describe ".remove_breakpoint" do
    it "removes a breakpoint by id" do
      id = described_class.add_breakpoint(file: "/app/bar.rb", line: 20)
      expect(described_class.remove_breakpoint(id)).to be true
      expect(described_class.list_breakpoints.size).to eq(0)
      expect(described_class.breakpoint_at?("/app/bar.rb", 20)).to be false
    end

    it "returns false for nonexistent id" do
      expect(described_class.remove_breakpoint(99999)).to be false
    end
  end

  describe ".clear_all!" do
    it "removes all breakpoints" do
      described_class.add_breakpoint(file: "/app/a.rb", line: 1)
      described_class.add_breakpoint(file: "/app/b.rb", line: 2)
      described_class.clear_all!
      expect(described_class.list_breakpoints.size).to eq(0)
    end
  end

  describe ".get_breakpoint" do
    it "returns full breakpoint hash" do
      described_class.add_breakpoint(file: "/app/cond.rb", line: 15, condition: "x > 5")
      bp = described_class.get_breakpoint("/app/cond.rb", 15)
      expect(bp).not_to be_nil
      expect(bp[:file]).to eq("/app/cond.rb")
      expect(bp[:line]).to eq(15)
      expect(bp[:condition]).to eq("x > 5")
    end

    it "returns nil when no breakpoint exists" do
      expect(described_class.get_breakpoint("/nope.rb", 1)).to be_nil
    end
  end

  describe "persistence" do
    it "reloads breakpoints from database on setup!" do
      described_class.add_breakpoint(file: "/app/persist.rb", line: 42)
      # Re-setup simulates restart
      described_class.setup!
      expect(described_class.breakpoint_at?("/app/persist.rb", 42)).to be true
    end
  end
end
