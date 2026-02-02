# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Debugger::Session do
  let(:test_binding) do
    x = 42
    y = "hello"
    binding
  end

  let(:session) do
    described_class.new(
      binding_obj: test_binding,
      file: __FILE__,
      line: __LINE__,
      method_name: "test_method"
    )
  end

  describe "#evaluate" do
    it "returns result for valid expression" do
      result = session.evaluate("1 + 1")
      expect(result[:result]).to eq("2")
      expect(result[:error]).to be_nil
    end

    it "returns error for invalid expression" do
      result = session.evaluate("undefined_var_xyz")
      expect(result[:error]).to match(/NameError/)
    end

    it "stores results in eval_history" do
      session.evaluate("1 + 1")
      session.evaluate("2 + 2")
      expect(session.eval_history.size).to eq(2)
    end
  end

  describe "#local_variables_hash" do
    it "returns local variables from binding" do
      locals = session.local_variables_hash
      expect(locals).to have_key("x")
      expect(locals["x"]).to eq("42")
      expect(locals).to have_key("y")
      expect(locals["y"]).to include("hello")
    end
  end

  describe "#continue!" do
    it "changes status to resumed" do
      session.continue!
      expect(session.status).to eq(:resumed)
    end
  end

  describe "#wait! with timeout" do
    it "unblocks after timeout" do
      session_obj = described_class.new(
        binding_obj: binding,
        file: __FILE__,
        line: __LINE__,
        method_name: "test"
      )
      # Use a very short timeout
      Tailscope.configuration.debugger_timeout = 0.1
      session_obj.wait!
      expect(session_obj.status).to eq(:completed)
      Tailscope.configuration.debugger_timeout = 60
    end
  end

  describe "#source_context" do
    it "returns lines around the current line" do
      lines = session.source_context(radius: 3)
      expect(lines).to be_an(Array)
      expect(lines).not_to be_empty
      expect(lines.any? { |l| l[:current] }).to be true
    end
  end

  describe "#paused?" do
    it "returns true initially" do
      expect(session.paused?).to be true
    end

    it "returns false after continue" do
      session.continue!
      expect(session.paused?).to be false
    end
  end

  describe "#step_into!" do
    it "sets stepping_mode to :step_into" do
      session.step_into!
      expect(session.stepping_mode).to eq(:step_into)
    end

    it "changes status to :stepping" do
      session.step_into!
      expect(session.status).to eq(:stepping)
    end

    it "unblocks wait!" do
      s = described_class.new(binding_obj: binding, file: __FILE__, line: 1, method_name: "t")
      thread = Thread.new { s.wait!(timeout: 5) }
      sleep 0.05
      s.step_into!
      thread.join(1)
      expect(s.stepping_mode).to eq(:step_into)
    end
  end

  describe "#step_over!" do
    it "sets stepping_mode to :step_over and target_depth" do
      s = described_class.new(
        binding_obj: binding, file: __FILE__, line: 1,
        method_name: "t", call_depth: 3
      )
      s.step_over!
      expect(s.stepping_mode).to eq(:step_over)
      expect(s.target_depth).to eq(3)
    end
  end

  describe "#step_out!" do
    it "sets stepping_mode to :step_out and target_depth to parent" do
      s = described_class.new(
        binding_obj: binding, file: __FILE__, line: 1,
        method_name: "t", call_depth: 5
      )
      s.step_out!
      expect(s.stepping_mode).to eq(:step_out)
      expect(s.target_depth).to eq(4)
    end
  end

  describe "#capture_call_stack!" do
    it "stores call stack frames" do
      session.capture_call_stack!(caller_locations)
      expect(session.call_stack).to be_an(Array)
      expect(session.call_stack).not_to be_empty
      expect(session.call_stack.first).to have_key(:file)
      expect(session.call_stack.first).to have_key(:line)
      expect(session.call_stack.first).to have_key(:method)
    end

    it "limits to 20 frames" do
      session.capture_call_stack!(caller_locations)
      expect(session.call_stack.size).to be <= 20
    end
  end

  describe "#call_depth" do
    it "defaults to 0" do
      expect(session.call_depth).to eq(0)
    end

    it "accepts custom call_depth" do
      s = described_class.new(
        binding_obj: binding, file: __FILE__, line: 1,
        method_name: "t", call_depth: 7
      )
      expect(s.call_depth).to eq(7)
    end
  end
end

RSpec.describe Tailscope::Debugger::SessionStore do
  before { described_class.setup! }

  it "adds and finds sessions" do
    session = Tailscope::Debugger::Session.new(
      binding_obj: binding,
      file: __FILE__,
      line: __LINE__,
      method_name: "test"
    )
    described_class.add(session)
    expect(described_class.find(session.id)).to eq(session)
  end

  it "returns active (paused) sessions" do
    s1 = Tailscope::Debugger::Session.new(binding_obj: binding, file: __FILE__, line: 1, method_name: "a")
    s2 = Tailscope::Debugger::Session.new(binding_obj: binding, file: __FILE__, line: 2, method_name: "b")
    described_class.add(s1)
    described_class.add(s2)
    s2.continue!
    expect(described_class.active_sessions).to eq([s1])
  end
end
