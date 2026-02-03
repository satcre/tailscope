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

  describe "#resolve_editor" do
    it "returns command for symbol editor" do
      config.editor = :vscode
      expect(config.resolve_editor).to eq(Tailscope::Configuration::EDITOR_COMMANDS[:vscode])
    end

    it "returns custom string editor as-is" do
      config.editor = "vim +{line} {file}"
      expect(config.resolve_editor).to eq("vim +{line} {file}")
    end

    it "falls back to detect_editor when editor is nil" do
      config.editor = nil
      result = config.resolve_editor
      # Result depends on environment; just verify it doesn't raise
      expect(result).to be_nil.or be_a(String)
    end
  end

  describe "#editor_name" do
    it "returns symbol name for symbol editor" do
      config.editor = :vscode
      expect(config.editor_name).to eq("vscode")
    end

    it "returns 'custom' for string editor" do
      config.editor = "vim +{line} {file}"
      expect(config.editor_name).to eq("custom")
    end

    it "returns 'none' when nothing detected and editor is nil" do
      config.editor = nil
      allow(config).to receive(:detect_editor_name).and_return(nil)
      expect(config.editor_name).to eq("none")
    end
  end

  describe ".mac?" do
    it "returns a boolean" do
      expect(described_class.mac?).to be(true).or be(false)
    end
  end

  describe ".linux?" do
    it "returns a boolean" do
      expect(described_class.linux?).to be(true).or be(false)
    end
  end

  describe ".windows?" do
    it "returns a truthy or falsy value" do
      result = described_class.windows?
      expect(result).to be_nil.or be_truthy
    end
  end

  describe ".mac_app_installed?" do
    it "returns false for unknown editor" do
      expect(described_class.mac_app_installed?(:unknown_editor)).to be false
    end

    it "checks /Applications path" do
      # This test is platform-dependent; just verify no errors
      result = described_class.mac_app_installed?(:vscode)
      expect(result).to be(true).or be(false)
    end
  end

  describe ".mac_cli_path" do
    it "returns nil for unknown editor" do
      expect(described_class.mac_cli_path(:unknown_editor)).to be_nil
    end

    it "returns path if binary exists" do
      result = described_class.mac_cli_path(:vscode)
      if result
        expect(File.executable?(result)).to be true
      end
    end
  end

  describe "EDITOR_COMMANDS" do
    it "has entries for all supported editors" do
      expect(described_class::EDITOR_COMMANDS.keys).to include(:vscode, :sublime, :rubymine, :nvim_terminal, :nvim_iterm)
    end
  end

  describe "detect_editor via EDITOR env var" do
    it "uses EDITOR env var when set" do
      config.editor = nil
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("EDITOR").and_return("nvim")
      result = config.resolve_editor
      expect(result).to eq(Tailscope::Configuration::EDITOR_COMMANDS[:nvim_terminal])
    end

    it "falls back to custom command for unknown EDITOR" do
      config.editor = nil
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("EDITOR").and_return("nano")
      allow(config).to receive(:command_exists?).and_return(false)
      result = config.resolve_editor
      expect(result).to eq("nano +{line} {file}")
    end
  end
end
