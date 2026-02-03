# Detectors

Tailscope uses several detection systems to identify performance issues and errors. Each detector operates automatically — no code changes required.

## Slow Query Detector

**Implementation:** `Tailscope::Subscribers::SqlSubscriber`

Subscribes to Rails' `sql.active_record` ActiveSupport notification. Every SQL query executed by ActiveRecord triggers this subscriber.

**How it works:**

1. When a query completes, the subscriber receives the event with duration and SQL text
2. Queries with `SCHEMA` or `EXPLAIN` in the name are ignored (internal Rails queries)
3. Blank SQL is ignored
4. The query is added to the current request's query log (`Thread.current[:tailscope_query_log]`) for N+1 analysis
5. If duration exceeds `slow_query_threshold_ms`, the query source location is resolved and the query is recorded to storage

**Source location resolution:** Uses `SourceLocator` to walk the call stack and find the first frame inside your application (filtering out gems, stdlib, and Tailscope internals). This tells you exactly which line of your code triggered the query.

**Recorded data:**
- SQL text
- Duration (milliseconds)
- ActiveRecord event name (e.g., "User Load")
- Source file, line, and method
- Current request ID (for correlation)

## N+1 Query Detector

**Implementation:** `Tailscope::Detectors::NPlusOne`

Identifies N+1 query patterns by analyzing all queries within a single HTTP request.

**How it works:**

1. During a request, every SQL query is accumulated in `Thread.current[:tailscope_query_log]`
2. At the end of the request (in middleware), `NPlusOne.analyze!` processes the log
3. Each query's SQL is **normalized**: numeric literals become `?`, string literals become `?`, whitespace is collapsed
4. Queries are grouped by a key: `"normalized_sql||source_file:source_line"`
5. Groups with count >= `n_plus_one_threshold` (default: 3) are flagged as N+1

**Example:**

```ruby
# In controller:
@users = User.all

# In view (N+1):
<% @users.each do |user| %>
  <%= user.company.name %>  <%# This triggers a SELECT for each user %>
<% end %>
```

This produces queries like:
```sql
SELECT "companies".* FROM "companies" WHERE "companies"."id" = 1
SELECT "companies".* FROM "companies" WHERE "companies"."id" = 2
SELECT "companies".* FROM "companies" WHERE "companies"."id" = 3
...
```

After normalization, all become: `SELECT ? FROM ? WHERE ? = ?`

Since they share the same normalized SQL and originate from the same source line, they're grouped and flagged as N+1 with the total count.

**Recorded data:**
- SQL text (of one representative query)
- Total duration across all occurrences
- Source file and line
- N+1 flag and count

**Common fixes suggested by Tailscope:**
- Add `includes(:association)` to eager-load
- Use `preload` or `eager_load` for specific cases
- Use `pluck` if you only need a single column

## Slow Request Detector

**Implementation:** `Tailscope::Subscribers::ActionSubscriber`

Subscribes to Rails' `process_action.action_controller` notification, which fires at the end of every controller action.

**How it works:**

1. When a controller action completes, the subscriber receives the event with total duration
2. Actions from Tailscope's own controllers are ignored (avoids recording dashboard requests)
3. If duration exceeds `slow_request_threshold_ms`, the request is recorded

**Recorded data:**
- HTTP method, path, status code
- Total duration (milliseconds)
- View render time (milliseconds)
- Database time (milliseconds)
- Controller name and action
- Request params (excluding `controller` and `action` keys)
- Request ID (for query/error correlation)

**Time breakdown:** The view and DB times help identify where slowness comes from:
- High view time → template rendering is slow (consider caching or simplifying views)
- High DB time → queries are slow (check the associated queries)
- High total but low view+DB → application logic is slow (look for CPU-bound operations)

## Error Detector

**Implementation:** `Tailscope::Middleware::RequestTracker`

A Rack middleware that wraps every request in a begin/rescue block.

**How it works:**

1. Records request start time and generates a request ID
2. Sets `Thread.current[:tailscope_request_id]` for query/request correlation
3. Passes the request through the middleware stack
4. If an exception occurs, captures it before re-raising
5. At request end, triggers N+1 analysis on the accumulated query log

**Recorded data:**
- Exception class name
- Exception message (first 1000 characters)
- Backtrace (first 20 frames)
- Source file, line, and method (from backtrace)
- HTTP method, path, and params
- Request ID
- Duration to error (how long the request ran before the exception)

**Behavior:** Tailscope never suppresses exceptions. After recording, the exception is re-raised so your existing error handling (rescue_from, error pages, etc.) works unchanged.

**Filtered requests:** Requests to Tailscope's own routes (`/tailscope/*`) are excluded from tracking.

## Code Smell Detector

**Implementation:** `Tailscope::CodeAnalyzer`

Static analysis of Ruby files in your `app/` directory. Unlike the other detectors, this runs on-demand when the Issues page is loaded (not during request processing).

See [Code Analysis](code-analysis.md) for the complete list of rules.

## Source Locator

**Implementation:** `Tailscope::SourceLocator`

A shared utility used by all detectors to resolve the application source location from a call stack.

**How it works:**

1. Walks the caller's backtrace locations
2. Skips frames matching ignore patterns:
   - Gem paths (`/gems/`)
   - Ruby stdlib (`<internal:`)
   - Tailscope internals (`/tailscope/`)
   - Bundle paths (`/vendor/bundle/`)
3. Returns the first frame with an `absolute_path` inside the application

**Returns:** `{ source_file: "/path/to/file.rb", source_line: 42, source_method: "index" }`
