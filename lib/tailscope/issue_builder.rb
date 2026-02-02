# frozen_string_literal: true

module Tailscope
  Issue = Struct.new(
    :severity,
    :type,
    :title,
    :description,
    :source_file,
    :source_line,
    :suggested_fix,
    :occurrences,
    :total_duration_ms,
    :latest_at,
    :raw_ids,
    :raw_type,
    :metadata,
    keyword_init: true
  )

  module IssueBuilder
    class << self
      def build_all(limit: 100)
        issues = []
        issues.concat(n_plus_one_issues)
        issues.concat(slow_query_issues)
        issues.concat(error_issues)
        issues.concat(slow_request_issues)
        issues.concat(code_smell_issues)
        issues.sort_by { |i| [severity_rank(i.severity), -(i.occurrences || 0)] }
              .first(limit)
      end

      private

      def severity_rank(sev)
        { critical: 0, warning: 1, info: 2 }[sev] || 3
      end

      def n_plus_one_issues
        rows = Tailscope::Database.connection.execute(<<~SQL)
          SELECT
            q.source_file, q.source_line, q.source_method, q.sql_text,
            COUNT(*) as occurrence_count,
            SUM(q.duration_ms) as total_duration_ms,
            MAX(q.n_plus_one_count) as max_n_plus_one_count,
            MAX(q.recorded_at) as latest_at,
            GROUP_CONCAT(q.id) as raw_ids,
            r.controller, r.action
          FROM tailscope_queries q
          LEFT JOIN tailscope_requests r ON q.request_id = r.request_id
          WHERE q.n_plus_one = 1
          GROUP BY q.source_file, q.source_line
          ORDER BY occurrence_count DESC
          LIMIT 50
        SQL

        rows.map do |row|
          n_count = row["max_n_plus_one_count"].to_i
          controller = row["controller"]
          action = row["action"]
          controller_ref = controller && action ? "#{controller}##{action}" : nil

          # Extract likely association name from SQL
          association = extract_association(row["sql_text"])

          description = "Same query executed #{n_count} times in a single request"
          description += " in #{controller_ref}" if controller_ref
          description += ". Found #{row['occurrence_count']} time#{'s' if row['occurrence_count'] != 1}."

          fix = if association && controller_ref
            "Before (#{n_count} separate queries):\n`@records = Record.all` → each record fires a query for `#{association}`\nAfter (1 query):\n`@records = Record.includes(:#{association}).all`\nAdd this in `#{controller_ref}`."
          elsif association
            "Before:\n`Record.all` — triggers #{n_count} extra queries for `#{association}`\nAfter:\n`Record.includes(:#{association}).all`\nThis batches #{n_count} queries into one."
          else
            "Before:\n`Record.all` — triggers #{n_count} extra queries per record\nAfter:\n`Record.includes(:association).all`\nReplace `:association` with the name of the related model being loaded."
          end

          Issue.new(
            severity: :critical,
            type: :n_plus_one,
            title: "N+1 Query — #{association || 'association'}",
            description: description,
            source_file: row["source_file"],
            source_line: row["source_line"],
            suggested_fix: fix,
            occurrences: row["occurrence_count"].to_i,
            total_duration_ms: row["total_duration_ms"]&.round(1),
            latest_at: row["latest_at"],
            raw_ids: parse_ids(row["raw_ids"]),
            raw_type: "query",
            metadata: {
              sql_text: row["sql_text"],
              source_method: row["source_method"],
              controller: controller_ref,
            },
          )
        end
      end

      def slow_query_issues
        rows = Tailscope::Database.connection.execute(<<~SQL)
          SELECT
            q.source_file, q.source_line, q.source_method, q.sql_text,
            COUNT(*) as occurrence_count,
            AVG(q.duration_ms) as avg_duration_ms,
            MAX(q.duration_ms) as max_duration_ms,
            SUM(q.duration_ms) as total_duration_ms,
            MAX(q.recorded_at) as latest_at,
            GROUP_CONCAT(q.id) as raw_ids,
            r.controller, r.action
          FROM tailscope_queries q
          LEFT JOIN tailscope_requests r ON q.request_id = r.request_id
          WHERE q.n_plus_one = 0
          GROUP BY q.source_file, q.source_line
          ORDER BY avg_duration_ms DESC
          LIMIT 50
        SQL

        rows.map do |row|
          avg = row["avg_duration_ms"]&.round(1) || 0
          max = row["max_duration_ms"]&.round(1) || 0
          severity = avg >= 500 ? :warning : :info
          controller_ref = row["controller"] && row["action"] ? "#{row['controller']}##{row['action']}" : nil

          description = "Query averaging #{avg}ms (max #{max}ms)"
          description += " in #{controller_ref}" if controller_ref
          description += ", occurred #{row['occurrence_count']} time#{'s' if row['occurrence_count'] != 1}."

          Issue.new(
            severity: severity,
            type: :slow_query,
            title: "Slow Query",
            description: description,
            source_file: row["source_file"],
            source_line: row["source_line"],
            suggested_fix: fix_for_slow_query(row["sql_text"]),
            occurrences: row["occurrence_count"].to_i,
            total_duration_ms: row["total_duration_ms"]&.round(1),
            latest_at: row["latest_at"],
            raw_ids: parse_ids(row["raw_ids"]),
            raw_type: "query",
            metadata: {
              sql_text: row["sql_text"],
              source_method: row["source_method"],
              avg_duration_ms: avg,
              controller: controller_ref,
            },
          )
        end
      end

      def error_issues
        rows = Tailscope::Database.connection.execute(<<~SQL)
          SELECT
            exception_class, message, source_file, source_line, source_method,
            backtrace, request_path,
            COUNT(*) as occurrence_count,
            MAX(recorded_at) as latest_at,
            GROUP_CONCAT(id) as raw_ids
          FROM tailscope_errors
          GROUP BY exception_class, source_file, source_line
          ORDER BY occurrence_count DESC
          LIMIT 50
        SQL

        rows.map do |row|
          Issue.new(
            severity: :critical,
            type: :error,
            title: "#{row['exception_class']}",
            description: "#{row['message']}",
            source_file: row["source_file"],
            source_line: row["source_line"],
            suggested_fix: fix_for_exception(row["exception_class"], row["message"]),
            occurrences: row["occurrence_count"].to_i,
            total_duration_ms: nil,
            latest_at: row["latest_at"],
            raw_ids: parse_ids(row["raw_ids"]),
            raw_type: "error",
            metadata: {
              exception_class: row["exception_class"],
              message: row["message"],
              backtrace: row["backtrace"]&.split("\n")&.first(5),
              request_path: row["request_path"],
              source_method: row["source_method"],
            },
          )
        end
      end

      def slow_request_issues
        rows = Tailscope::Database.connection.execute(<<~SQL)
          SELECT
            controller, action, method, path,
            COUNT(*) as occurrence_count,
            AVG(duration_ms) as avg_duration_ms,
            MAX(duration_ms) as max_duration_ms,
            SUM(duration_ms) as total_duration_ms,
            AVG(view_runtime_ms) as avg_view_ms,
            AVG(db_runtime_ms) as avg_db_ms,
            MAX(recorded_at) as latest_at,
            GROUP_CONCAT(id) as raw_ids
          FROM tailscope_requests
          WHERE controller IS NOT NULL
          GROUP BY controller, action
          ORDER BY avg_duration_ms DESC
          LIMIT 50
        SQL

        rows.map do |row|
          avg = row["avg_duration_ms"]&.round(1) || 0
          avg_view = row["avg_view_ms"]&.round(1)
          avg_db = row["avg_db_ms"]&.round(1)
          severity = avg >= 1000 ? :warning : :info

          controller_action = "#{row['controller']}##{row['action']}"
          fix = if avg_db && avg_view && avg_db > avg_view
            "DB time (#{avg_db}ms) dominates in `#{controller_action}`.\nCheck for:\n• N+1 queries — add `includes(:association)` to your query\n• Missing indexes — run `EXPLAIN` on slow queries\n• Unnecessary data — use `.select(:col1, :col2)` instead of `SELECT *`"
          elsif avg_view && avg_db && avg_view > avg_db
            "View rendering (#{avg_view}ms) dominates in `#{controller_action}`.\nCheck for:\n• Too many partials — reduce `render partial:` calls in loops\n• Missing caching — wrap slow sections in `cache do ... end`\n• Heavy helpers — precompute data in the controller"
          else
            "Profile `#{controller_action}` to find the bottleneck.\n• DB time: #{avg_db || '?'}ms — look for N+1 queries and missing indexes\n• View time: #{avg_view || '?'}ms — look for expensive partials and missing caches"
          end

          Issue.new(
            severity: severity,
            type: :slow_request,
            title: "Slow Request",
            description: "#{row['controller']}##{row['action']} averaging #{avg}ms#{avg_view ? " (view: #{avg_view}ms" : ""}#{avg_db ? ", DB: #{avg_db}ms)" : ")"}. Occurred #{row['occurrence_count']} time#{'s' if row['occurrence_count'] != 1}.",
            source_file: nil,
            source_line: nil,
            suggested_fix: fix,
            occurrences: row["occurrence_count"].to_i,
            total_duration_ms: row["total_duration_ms"]&.round(1),
            latest_at: row["latest_at"],
            raw_ids: parse_ids(row["raw_ids"]),
            raw_type: "request",
            metadata: {
              controller: row["controller"],
              action: row["action"],
              method: row["method"],
              path: row["path"],
              avg_duration_ms: avg,
              avg_view_ms: avg_view,
              avg_db_ms: avg_db,
            },
          )
        end
      end

      def code_smell_issues
        CodeAnalyzer.analyze_all(source_root: Tailscope.configuration.source_root)
      rescue => e
        warn "[Tailscope] Code analysis failed: #{e.message}" if defined?(Rails)
        []
      end

      def parse_ids(ids_str)
        return [] unless ids_str

        ids_str.split(",").map(&:to_i)
      end

      def extract_association(sql)
        return nil unless sql

        # Try to extract the table name from common N+1 patterns
        # "SELECT ... FROM \"users\" WHERE ..." → "users" → "user"
        if sql =~ /FROM\s+["']?(\w+)["']?\s/i
          table = $1
          # Singularize naively: remove trailing 's' for common cases
          table.end_with?("ies") ? table.sub(/ies$/, "y") : table.chomp("s")
        end
      end

      def fix_for_slow_query(sql)
        return "Review this query for optimization opportunities." unless sql

        suggestions = []

        if sql =~ /LIKE\s+['"]%/i
          suggestions << "Leading wildcard `LIKE '%...'` prevents index use.\nBefore: `.where(\"name LIKE ?\", \"%term%\")`\nAfter: Use `pg_search` or full-text search, or remove the leading `%`."
        end

        if sql =~ /ORDER BY.*LENGTH|RANDOM|RAND/i
          suggestions << "Ordering by `RANDOM()`/`LENGTH()` forces a full table scan.\nFor random: precompute a random offset or use `.order(\"RANDOM()\").limit(1)` only on small tables.\nFor computed sorts: add a database column to store the computed value."
        end

        if sql =~ /SELECT\s+\*/i
          suggestions << "Before: `SELECT *` — fetches all columns\nAfter: `.select(:id, :name, :email)` — fetch only what you need."
        end

        if sql =~ /COUNT\(\*\)/i && sql =~ /WHERE/i
          suggestions << "This `COUNT(*)` with a `WHERE` clause may be slow without an index.\nAdd an index: `add_index :table, :filtered_column`"
        end

        if suggestions.empty?
          "Check the `WHERE` and `ORDER BY` columns.\nRun `EXPLAIN ANALYZE` on this query to identify missing indexes.\nAdd indexes: `add_index :table_name, :column_name`"
        else
          suggestions.join("\n")
        end
      end

      def fix_for_exception(klass, message)
        case klass
        when "NoMethodError"
          if message&.include?("nil")
            method_name = message[/undefined method `(\w+)'/, 1]
            "A method#{method_name ? " `#{method_name}`" : ''} was called on `nil`.\nBefore: `object.#{method_name || 'method'}`\nAfter: `object&.#{method_name || 'method'}` (returns nil if object is nil)\nOr guard: `object.#{method_name || 'method'} if object.present?`\nCheck why the variable is nil — is a record missing from the DB?"
          else
            "A method was called on an object that doesn't support it.\nCheck the object's actual type with `object.class` in the console.\nCommon cause: expecting an ActiveRecord object but getting an Array or Hash."
          end
        when "NameError"
          const_name = message[/uninitialized constant (\S+)/, 1] || message[/undefined local variable or method `(\w+)'/, 1]
          if const_name
            "Cannot find `#{const_name}`.\nCheck for:\n• Typo in the name\n• Missing `require` or `autoload` statement\n• File not in the expected directory for Rails autoloading"
          else
            "A variable or constant was referenced that doesn't exist.\nCheck for typos, missing requires, or incorrect file placement for Rails autoloading."
          end
        when "ActiveRecord::RecordNotFound"
          "Before: `Model.find(id)` — raises if record doesn't exist\nAfter: `Model.find_by(id: id)` — returns `nil` instead\nThen handle the nil case:\n`@record = Model.find_by(id: params[:id])`\n`return head :not_found unless @record`"
        when "ActionController::ParameterMissing"
          param_name = message[/param is missing or the value is empty: (\w+)/, 1]
          "Required parameter `#{param_name || ':key'}` is missing from the request.\nCheck that your form includes a field for `#{param_name || 'this parameter'}`.\nIf the param is optional, use:\n`params.fetch(:#{param_name || 'key'}, default_value)`\ninstead of `params.require(:#{param_name || 'key'})`."
        when "ArgumentError"
          "Wrong number or type of arguments passed to a method.\nCheck the method signature — look for:\n• Missing required keyword arguments\n• Extra positional arguments\n• `nil` passed where a specific type is expected"
        when "TypeError"
          "An operation was performed on an incompatible type.\nCommon causes:\n• String concatenation with nil: use `to_s` or string interpolation\n• Math on nil: add a nil guard or default value\n• Passing wrong type to a gem method: check the docs"
        else
          "Review the backtrace to identify the root cause.\nThe top line in the backtrace is where the error occurred.\nLines from your app (not gems) are the most useful to investigate."
        end
      end
    end
  end
end
