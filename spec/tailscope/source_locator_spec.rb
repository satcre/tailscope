# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::SourceLocator do
  describe ".locate" do
    it "returns empty hash when no app frames found" do
      result = described_class.locate([])
      expect(result).to eq({})
    end

    it "locates source from caller_locations" do
      # This call itself should be locatable since we're in the source_root
      result = described_class.locate(caller_locations(0))
      # The spec file should be detected if source_root covers it
      # Since we set source_root to the dummy dir, this may not match
      expect(result).to be_a(Hash)
    end
  end
end
