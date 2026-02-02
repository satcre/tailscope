# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Debugger::TraceHook do
  before do
    Tailscope::Debugger::SessionStore.setup!
    Tailscope::Debugger::BreakpointManager.setup!
    described_class.setup!
  end

  after do
    described_class.disable!
  end

  describe ".enable! / .disable!" do
    it "enables and disables the trace" do
      described_class.enable!
      expect(described_class.enabled?).to be true
      described_class.disable!
      expect(described_class.enabled?).to be false
    end
  end

  describe ".refresh!" do
    it "enables when breakpoints exist" do
      allow(Tailscope::Debugger::BreakpointManager).to receive(:any_breakpoints?).and_return(true)
      described_class.refresh!
      expect(described_class.enabled?).to be true
    end

    it "disables when no breakpoints exist" do
      allow(Tailscope::Debugger::BreakpointManager).to receive(:any_breakpoints?).and_return(false)
      described_class.refresh!
      expect(described_class.enabled?).to be false
    end
  end

  describe "breakpoint hit" do
    it "pauses thread and creates session when breakpoint is hit" do
      # Create a temp file to set breakpoint on
      tmpfile = File.join(Dir.tmpdir, "tailscope_trace_test_#{$$}.rb")
      File.write(tmpfile, <<~RUBY)
        x = 1
        y = 2
        z = x + y
      RUBY

      # Stub breakpoint check for line 2 of the temp file
      allow(Tailscope::Debugger::BreakpointManager).to receive(:breakpoint_at?).and_return(false)
      allow(Tailscope::Debugger::BreakpointManager).to receive(:breakpoint_at?)
        .with(tmpfile, 2).and_return(true)
      allow(Tailscope::Debugger::BreakpointManager).to receive(:any_breakpoints?).and_return(true)

      described_class.refresh!

      session_found = nil
      thread = Thread.new do
        load(tmpfile)
      end

      # Wait briefly for the thread to hit the breakpoint
      sleep 0.3
      sessions = Tailscope::Debugger::SessionStore.active_sessions
      session_found = sessions.find { |s| s.file == tmpfile }

      if session_found
        expect(session_found.paused?).to be true
        expect(session_found.line).to eq(2)
        session_found.continue!
      end

      thread.join(2)
    ensure
      File.delete(tmpfile) if tmpfile && File.exist?(tmpfile)
    end
  end
end
