# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Database do
  describe ".connection" do
    it "returns a SQLite3::Database instance" do
      expect(described_class.connection).to be_a(SQLite3::Database)
    end

    it "sets WAL journal mode" do
      db = described_class.connection
      result = db.execute("PRAGMA journal_mode")
      expect(result.first["journal_mode"]).to eq("wal")
    end

    it "is memoized" do
      expect(described_class.connection).to equal(described_class.connection)
    end
  end

  describe ".reset!" do
    it "clears the connection so next call returns a new instance" do
      original = described_class.connection
      described_class.reset!
      Tailscope::Schema.create_tables!
      expect(described_class.connection).not_to equal(original)
    end
  end
end
