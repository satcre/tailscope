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
        render json: TestRunner.coverage
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
