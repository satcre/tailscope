# frozen_string_literal: true

module Tailscope
  module Debugger
    module BreakpointManager
      class << self
        def setup!
          @mutex = Mutex.new
          @breakpoints = {}
          load_from_db!
        end

        def add_breakpoint(file:, line:, condition: nil)
          db = Database.connection
          db.execute(
            "INSERT OR REPLACE INTO tailscope_breakpoints (file, line, condition, enabled) VALUES (?, ?, ?, 1)",
            [file, line.to_i, condition]
          )
          id = db.last_insert_row_id
          key = "#{file}:#{line}"
          @mutex.synchronize do
            @breakpoints[key] = { id: id, file: file, line: line.to_i, condition: condition }
          end
          TraceHook.refresh!
          id
        end

        def remove_breakpoint(id)
          db = Database.connection
          row = db.execute("SELECT file, line FROM tailscope_breakpoints WHERE id = ?", [id]).first
          return false unless row

          db.execute("DELETE FROM tailscope_breakpoints WHERE id = ?", [id])
          key = "#{row["file"]}:#{row["line"]}"
          @mutex.synchronize { @breakpoints.delete(key) }
          TraceHook.refresh!
          true
        end

        def list_breakpoints
          Database.connection.execute(
            "SELECT id, file, line, condition, enabled, created_at FROM tailscope_breakpoints ORDER BY created_at DESC"
          )
        end

        def breakpoint_at?(file, line)
          key = "#{file}:#{line}"
          @mutex.synchronize { @breakpoints.key?(key) }
        end

        def get_breakpoint(file, line)
          key = "#{file}:#{line}"
          @mutex.synchronize { @breakpoints[key] }
        end

        def any_breakpoints?
          @mutex.synchronize { @breakpoints.any? }
        end

        def clear_all!
          Database.connection.execute("DELETE FROM tailscope_breakpoints")
          @mutex.synchronize { @breakpoints.clear }
          TraceHook.refresh!
        end

        private

        def load_from_db!
          rows = Database.connection.execute(
            "SELECT id, file, line, condition FROM tailscope_breakpoints WHERE enabled = 1"
          )
          @mutex.synchronize do
            @breakpoints.clear
            rows.each do |row|
              key = "#{row["file"]}:#{row["line"]}"
              @breakpoints[key] = { id: row["id"], file: row["file"], line: row["line"], condition: row["condition"] }
            end
          end
        end
      end
    end
  end
end
