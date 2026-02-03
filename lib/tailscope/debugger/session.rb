# frozen_string_literal: true

require "securerandom"

module Tailscope
  module Debugger
    class Session
      attr_reader :id, :file, :line, :method_name, :status, :eval_history, :created_at,
                  :stepping_mode, :target_depth, :call_stack, :call_depth

      def initialize(binding_obj:, file:, line:, method_name:, call_depth: 0)
        @id = SecureRandom.hex(8)
        @binding_obj = binding_obj
        @file = file
        @line = line
        @method_name = method_name
        @call_depth = call_depth
        @status = :paused
        @eval_history = []
        @created_at = Time.now
        @stepping_mode = nil
        @target_depth = nil
        @call_stack = []
        @mutex = Mutex.new
        @condition = ConditionVariable.new
      end

      def wait!(timeout: nil)
        timeout ||= Tailscope.configuration.debugger_timeout
        @mutex.synchronize do
          @condition.wait(@mutex, timeout)
        end
        @status = :completed
      end

      def continue!
        @status = :resumed
        @mutex.synchronize do
          @condition.broadcast
        end
      end

      def step_into!
        @stepping_mode = :step_into
        @status = :stepping
        @mutex.synchronize { @condition.broadcast }
      end

      def step_over!
        @stepping_mode = :step_over
        @target_depth = @call_depth
        @status = :stepping
        @mutex.synchronize { @condition.broadcast }
      end

      def step_out!
        @stepping_mode = :step_out
        @target_depth = @call_depth - 1
        @status = :stepping
        @mutex.synchronize { @condition.broadcast }
      end

      def capture_call_stack!(locations)
        @call_stack = locations.first(20).map do |loc|
          {
            file: loc.absolute_path || loc.path,
            line: loc.lineno,
            method: loc.label,
          }
        end
      end

      def evaluate(expr)
        result = begin
          value = @binding_obj.eval(expr)
          { expression: expr, result: value.inspect, error: nil }
        rescue Exception => e
          { expression: expr, result: nil, error: "#{e.class}: #{e.message}" }
        end
        @eval_history << result
        result
      end

      def local_variables_hash
        vars = {}
        @binding_obj.local_variables.each do |name|
          val = begin
            @binding_obj.local_variable_get(name)
          rescue => e
            "<error: #{e.message}>"
          end
          inspected = begin
            val.inspect
          rescue => e
            "<inspect error: #{e.message}>"
          end
          vars[name.to_s] = truncate_value(inspected)
        end
        vars
      end

      def source_context(radius: 10)
        return [] unless File.exist?(@file)

        all_lines = File.readlines(@file)
        start_idx = [(@line - 1 - radius), 0].max
        end_idx = [(@line - 1 + radius), all_lines.size - 1].min

        (start_idx..end_idx).map do |i|
          {
            number: i + 1,
            content: all_lines[i]&.chomp || "",
            current: (i + 1) == @line,
          }
        end
      end

      def paused?
        @status == :paused
      end

      private

      def truncate_value(str, max: 200)
        str.length > max ? "#{str[0...max]}..." : str
      end
    end

    module SessionStore
      class << self
        def setup!
          @mutex = Mutex.new
          @sessions = {}
        end

        def ensure_setup!
          @mutex ||= Mutex.new
          @sessions ||= {}
        end

        def add(session)
          ensure_setup!
          @mutex.synchronize { @sessions[session.id] = session }
        end

        def find(id)
          ensure_setup!
          @mutex.synchronize { @sessions[id] }
        end

        def active_sessions
          ensure_setup!
          @mutex.synchronize { @sessions.values.select(&:paused?) }
        end

        def all_sessions
          ensure_setup!
          @mutex.synchronize { @sessions.values.sort_by(&:created_at).reverse }
        end

        def cleanup_old!(max_age: 300)
          ensure_setup!
          cutoff = Time.now - max_age
          @mutex.synchronize do
            @sessions.delete_if { |_id, s| !s.paused? && s.created_at < cutoff }
          end
        end
      end
    end
  end
end
