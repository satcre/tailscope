# frozen_string_literal: true

module Tailscope
  module Detectors
    module NPlusOne
      class << self
        def analyze!(request_id)
          query_log = Thread.current[:tailscope_query_log]
          return unless query_log && query_log.size > 0

          threshold = Tailscope.configuration.n_plus_one_threshold
          grouped = group_queries(query_log)

          grouped.each do |key, entries|
            next unless entries.size >= threshold

            sample = entries.first
            Tailscope::Storage.record_query(
              sql_text: sample[:sql].to_s[0..2000],
              duration_ms: entries.sum { |e| e[:duration_ms] }.round(2),
              name: "N+1 Query",
              source_file: sample[:source][:source_file],
              source_line: sample[:source][:source_line],
              source_method: sample[:source][:source_method],
              request_id: request_id,
              n_plus_one: true,
              n_plus_one_count: entries.size,
            )
          end
        end

        private

        def group_queries(query_log)
          query_log.group_by do |entry|
            normalized = normalize_sql(entry[:sql])
            call_site = "#{entry[:source][:source_file]}:#{entry[:source][:source_line]}"
            "#{normalized}||#{call_site}"
          end
        end

        def normalize_sql(sql)
          return "" if sql.nil?

          sql.gsub(/\b\d+\b/, "?")
             .gsub(/'[^']*'/, "?")
             .gsub(/"[^"]*"/, "?")
             .gsub(/\s+/, " ")
             .strip
        end
      end
    end
  end
end
