# frozen_string_literal: true

module Tailscope
  module Api
    class TestsController < ApiController
      def specs
        render json: TestRunner.discover_specs
      end

      def run
        target = params[:target]
        result = TestRunner.run!(target: target)

        if result[:error]
          render json: result, status: :conflict
        else
          render json: result
        end
      end

      def status
        render json: TestRunner.status
      end

      def examples
        target = params[:target]
        render json: TestRunner.dry_run(target)
      end

      def coverage
        result = TestRunner.coverage

        # Debug: include resultset keys and sample structure
        if defined?(Rails)
          resultset = Rails.root.join("coverage", ".resultset.json")
          if File.exist?(resultset)
            data = JSON.parse(File.read(resultset))
            result[:debug_keys] = data.keys
            first_key = data.keys.first
            if first_key && data[first_key].is_a?(Hash)
              result[:debug_entry_keys] = data[first_key].keys
              cov = data[first_key]["coverage"]
              if cov.is_a?(Hash) && cov.keys.first
                sample_key = cov.keys.first
                sample_val = cov[sample_key]
                result[:debug_sample_file] = sample_key
                result[:debug_sample_type] = sample_val.class.name
                result[:debug_sample_keys] = sample_val.keys if sample_val.is_a?(Hash)
              end
            end
          end
        end

        render json: result
      end

      def cancel
        result = TestRunner.cancel!

        if result[:error]
          render json: result, status: :conflict
        else
          render json: result
        end
      end
    end
  end
end
