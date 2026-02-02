# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Schema do
  it "creates all tables" do
    tables = Tailscope::Database.connection.execute(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'tailscope_%'"
    ).map { |r| r["name"] }

    expect(tables).to include("tailscope_queries")
    expect(tables).to include("tailscope_requests")
    expect(tables).to include("tailscope_errors")
  end

  it "is idempotent" do
    expect { described_class.create_tables! }.not_to raise_error
  end
end
