# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Detectors::NPlusOne do
  before do
    Tailscope::Database.reset!
    Tailscope::Schema.create_tables!
  end

  describe ".analyze!" do
    it "detects N+1 patterns when threshold is exceeded" do
      Thread.current[:tailscope_query_log] = 5.times.map do
        {
          sql: "SELECT * FROM posts WHERE user_id = 1",
          duration_ms: 5.0,
          name: "Post Load",
          source: { source_file: "/app/models/user.rb", source_line: 10, source_method: "posts" },
        }
      end

      described_class.analyze!("test-request-id")

      queries = Tailscope::Storage.queries(n_plus_one_only: true)
      expect(queries.size).to eq(1)
      expect(queries.first["n_plus_one"]).to eq(1)
      expect(queries.first["n_plus_one_count"]).to eq(5)
    end

    it "does not flag below threshold" do
      Thread.current[:tailscope_query_log] = 2.times.map do
        {
          sql: "SELECT * FROM posts WHERE user_id = 1",
          duration_ms: 5.0,
          name: "Post Load",
          source: { source_file: "/app/models/user.rb", source_line: 10, source_method: "posts" },
        }
      end

      described_class.analyze!("test-request-id")

      queries = Tailscope::Storage.queries(n_plus_one_only: true)
      expect(queries.size).to eq(0)
    end
  end
end
