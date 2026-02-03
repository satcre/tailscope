# Detectors

Tailscope uses several detection systems to identify performance issues and errors. Each detector operates automatically -- no code changes required.

---

## Overview

| Detector | Trigger | Implementation |
|----------|---------|----------------|
| [Slow Query](#slow-query-detector) | SQL duration exceeds threshold | `SqlSubscriber` |
| [N+1 Query](#n1-query-detector) | Repeated identical queries per request | `NPlusOne` |
| [Slow Request](#slow-request-detector) | HTTP request duration exceeds threshold | `ActionSubscriber` |
| [Error](#error-detector) | Uncaught exception during request | `RequestTracker` middleware |
| [Code Smell](#code-smell-detector) | Static analysis of `app/` files | `CodeAnalyzer` |

---

## Slow Query Detector

**Implementation:** `Tailscope::Subscribers::SqlSubscriber`

Subscribes to Rails' `sql.active_record` ActiveSupport notification. Every SQL query executed by ActiveRecord triggers this subscriber.

**How it works:**

1. Query completes, subscriber receives the event with duration and SQL text
2. Queries with `SCHEMA` or `EXPLAIN` in the name are ignored (internal Rails queries)
3. Blank SQL is ignored
4. Query is added to the current request's query log for N+1 analysis
5. If duration exceeds `slow_query_threshold_ms`, the source location is resolved and the query is recorded

**Source location resolution:** Uses `SourceLocator` to walk the call stack and find the first frame inside your application (filtering out gems, stdlib, and Tailscope internals).

**Recorded data:**

| Field | Description |
|-------|-------------|
| SQL text | The executed query |
| Duration | Milliseconds |
| Name | ActiveRecord event name (e.g., "User Load") |
| Source file, line, method | Where in your code the query originated |
| Request ID | For correlation with requests and errors |

---

## N+1 Query Detector

**Implementation:** `Tailscope::Detectors::NPlusOne`

Identifies N+1 query patterns by analyzing all queries within a single HTTP request.

**How it works:**

1. During a request, every SQL query accumulates in `Thread.current[:tailscope_query_log]`
2. At request end, `NPlusOne.analyze!` processes the log
3. Each query's SQL is **normalized**: numeric literals become `?`, string literals become `?`, whitespace is collapsed
4. Queries are grouped by key: `"normalized_sql||source_file:source_line"`
5. Groups with count >= `n_plus_one_threshold` (default: 3) are flagged

**Example:**

```ruby
# Controller
@users = User.all

# View (N+1)
<% @users.each do |user| %>
  <%= user.company.name %>  <%# Triggers a SELECT for each user %>
<% end %>
```

Produces queries like:

```sql
SELECT "companies".* FROM "companies" WHERE "companies"."id" = 1
SELECT "companies".* FROM "companies" WHERE "companies"."id" = 2
SELECT "companies".* FROM "companies" WHERE "companies"."id" = 3
```

After normalization, all become `SELECT ? FROM ? WHERE ? = ?` -- same SQL, same source line, flagged as N+1.

**Recorded data:**

| Field | Description |
|-------|-------------|
| SQL text | One representative query |
| Total duration | Across all occurrences |
| Source file and line | Where the N+1 originates |
| N+1 flag and count | Number of repeated queries |

**Common fixes:**
- Add `includes(:association)` to eager-load
- Use `preload` or `eager_load` for specific cases
- Use `pluck` if you only need a single column

---

## Slow Request Detector

**Implementation:** `Tailscope::Subscribers::ActionSubscriber`

Subscribes to Rails' `process_action.action_controller` notification, which fires at the end of every controller action.

**How it works:**

1. Controller action completes, subscriber receives the event with total duration
2. Actions from Tailscope's own controllers are ignored
3. If duration exceeds `slow_request_threshold_ms`, the request is recorded

**Recorded data:**

| Field | Description |
|-------|-------------|
| HTTP method, path, status | Request details |
| Total duration | Milliseconds |
| View render time | Template rendering (ms) |
| Database time | SQL execution (ms) |
| Controller and action | Which action handled the request |
| Params | Request parameters (excluding `controller`/`action`) |
| Request ID | For query/error correlation |

**Diagnosing slowness from time breakdown:**

| Pattern | Likely cause |
|---------|-------------|
| High view time | Template rendering is slow -- consider caching or simplifying views |
| High DB time | Queries are slow -- check associated queries |
| High total, low view+DB | Application logic is slow -- look for CPU-bound operations |

---

## Error Detector

**Implementation:** `Tailscope::Middleware::RequestTracker`

A Rack middleware that wraps every request in a begin/rescue block.

**How it works:**

1. Records request start time and generates a request ID
2. Sets `Thread.current[:tailscope_request_id]` for correlation
3. Passes the request through the middleware stack
4. If an exception occurs, captures it before re-raising
5. At request end, triggers N+1 analysis on the accumulated query log

**Recorded data:**

| Field | Description |
|-------|-------------|
| Exception class | e.g., `ActiveRecord::RecordNotFound` |
| Message | First 1000 characters |
| Backtrace | First 20 frames |
| Source file, line, method | From backtrace |
| HTTP method, path, params | Request context |
| Request ID | For correlation |
| Duration to error | How long the request ran before the exception |

> Tailscope never suppresses exceptions. After recording, the exception is re-raised so your existing error handling works unchanged.

**Filtered requests:** Requests to Tailscope's own routes (`/tailscope/*`) are excluded from tracking.

---

## Code Smell Detector

**Implementation:** `Tailscope::CodeAnalyzer`

Static analysis of Ruby files in your `app/` directory. Unlike the other detectors, this runs on-demand when the Issues page is loaded (not during request processing).

See [Code Analysis](code-analysis.md) for the complete list of rules.

---

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

**Returns:**

```ruby
{ source_file: "/path/to/file.rb", source_line: 42, source_method: "index" }
```
