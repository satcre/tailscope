# Architecture

This document describes Tailscope's internal design, data flow, and key implementation decisions.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Rails Application                         │
│                                                                   │
│  ┌─────────────────┐    ┌──────────────────┐                     │
│  │   Middleware     │    │  ActiveSupport    │                     │
│  │ RequestTracker   │    │  Notifications    │                     │
│  │                  │    │                   │                     │
│  │ • Request timing │    │ ┌───────────────┐ │                     │
│  │ • Error capture  │    │ │ SqlSubscriber  │ │                     │
│  │ • Request ID     │    │ │ sql.active_    │ │                     │
│  │ • N+1 trigger    │    │ │ record         │ │                     │
│  │                  │    │ └───────────────┘ │                     │
│  │                  │    │ ┌───────────────┐ │                     │
│  │                  │    │ │ActionSubscriber│ │                     │
│  │                  │    │ │ process_action.│ │                     │
│  │                  │    │ │ action_ctrl    │ │                     │
│  │                  │    │ └───────────────┘ │                     │
│  └────────┬─────────┘    └────────┬──────────┘                     │
│           │                       │                                │
│           └───────────┬───────────┘                                │
│                       ▼                                            │
│              ┌─────────────────┐                                   │
│              │   Storage       │                                   │
│              │  (Async Queue)  │                                   │
│              │                 │                                   │
│              │ SizedQueue(1000)│                                   │
│              │       │         │                                   │
│              │  Writer Thread  │                                   │
│              │       │         │                                   │
│              │       ▼         │                                   │
│              │    SQLite DB    │                                   │
│              │   (WAL mode)    │                                   │
│              └────────┬────────┘                                   │
│                       │                                            │
│           ┌───────────┴───────────┐                                │
│           ▼                       ▼                                │
│  ┌─────────────────┐    ┌─────────────────┐                       │
│  │  Web Dashboard   │    │      CLI        │                       │
│  │  (Rails Engine)  │    │    (Thor)       │                       │
│  │                  │    │                 │                       │
│  │ React SPA ←→ API │    │ Direct DB reads │                       │
│  └──────────────────┘    └─────────────────┘                       │
└───────────────────────────────────────────────────────────────────┘
```

## Component Details

### Middleware: RequestTracker

**File:** `lib/tailscope/middleware/request_tracker.rb`

Rack middleware inserted at position 0 (outermost) in the middleware stack.

**Responsibilities:**
1. Generate and set `Thread.current[:tailscope_request_id]` for request correlation
2. Initialize `Thread.current[:tailscope_query_log]` as an empty array
3. Record request start time
4. Pass request to the next middleware
5. On exception: capture error details, re-raise
6. On completion: trigger N+1 analysis on accumulated query log
7. Clean up thread-local variables

**Thread safety:** Uses `Thread.current` for per-request state, which is safe in both threaded (Puma) and forked (Unicorn) servers.

**Filtered paths:** Requests to `/tailscope/` paths are passed through without tracking.

### Subscribers

**SQL Subscriber** (`lib/tailscope/subscribers/sql_subscriber.rb`):
- Attaches to `sql.active_record` via `ActiveSupport::Notifications.subscribe`
- Runs synchronously inside the ActiveRecord query flow
- Adds every query to the thread-local query log (for N+1)
- Records slow queries to storage asynchronously

**Action Subscriber** (`lib/tailscope/subscribers/action_subscriber.rb`):
- Attaches to `process_action.action_controller`
- Fires at the end of each controller action
- Records slow requests to storage asynchronously

Both subscribers check `Tailscope.enabled?` on every event and short-circuit when disabled.

### N+1 Detector

**File:** `lib/tailscope/detectors/n_plus_one.rb`

Called at the end of each request by the middleware. Operates on the thread-local query log.

**Algorithm:**
```
1. For each query in the log:
   a. Normalize SQL (replace literals with ?)
   b. Build key: "normalized_sql||source_file:source_line"
2. Group queries by key
3. For groups with count >= threshold:
   a. Record as N+1 with count and total duration
```

**SQL normalization:**
- Numbers → `?`
- Single-quoted strings → `?`
- Collapse whitespace

### Storage

**File:** `lib/tailscope/storage.rb`

The storage layer handles all data persistence with an async write queue for minimal request-path impact.

**Write path (async):**
```
record_query/request/error → SizedQueue.push(operation)
                                     │
                              Writer Thread (loop)
                                     │
                              SizedQueue.pop → execute SQL INSERT
```

- `SizedQueue` capacity: 1000 operations
- Non-blocking push: if queue is full, the operation is dropped (logged in development)
- Writer thread is started on `Tailscope.setup!` and stopped on `shutdown!`
- Graceful shutdown: `:shutdown` sentinel pushed to queue

**Read path (synchronous):**
- All query methods (`queries`, `requests`, `errors`, `find_*`, `stats`) read directly from SQLite
- No caching layer — reads go straight to the database

### Database

**File:** `lib/tailscope/database.rb`

SQLite3 connection management with optimizations:

- **WAL mode** (Write-Ahead Logging): Allows concurrent reads while writing
- **PRAGMA synchronous=NORMAL**: Reduced fsync for better write performance
- **busy_timeout=5000**: Waits up to 5 seconds for locks instead of failing immediately

The connection is memoized per-process. `Database.reset!` closes and clears the connection (used in tests).

### Schema

**File:** `lib/tailscope/schema.rb`

Creates tables on first run using `CREATE TABLE IF NOT EXISTS`. Tables:

| Table | Purpose |
|-------|---------|
| `tailscope_queries` | Slow SQL queries and N+1 patterns |
| `tailscope_requests` | Slow HTTP requests |
| `tailscope_errors` | Captured exceptions |
| `tailscope_breakpoints` | Debugger breakpoints (persisted) |
| `tailscope_ignored_issues` | User-ignored issue fingerprints |

All tables use `tailscope_` prefix to avoid conflicts with application tables.

### Rails Engine

**File:** `lib/tailscope/engine.rb`

```ruby
class Engine < ::Rails::Engine
  isolate_namespace Tailscope
end
```

- Isolated namespace: controllers, views, and routes don't conflict with the host app
- Static asset serving: Rack::Static middleware serves compiled React SPA from `public/`

### Railtie

**File:** `lib/tailscope/railtie.rb`

Hooks into the Rails boot process:

1. **`tailscope.configure`**: Sets default `database_path` and `source_root` from `Rails.root`
2. **`tailscope.middleware`**: Inserts `RequestTracker` at position 0
3. **`config.after_initialize`**: If enabled, calls `Tailscope.setup!` and attaches subscribers
4. **`at_exit`**: Calls `Tailscope.shutdown!` for clean writer thread termination

### IssueBuilder

**File:** `lib/tailscope/issue_builder.rb`

Aggregates raw data into deduplicated, categorized issues. Called on-demand when the Issues page loads.

**Issue sources:**
1. N+1 queries → grouped by source location
2. Slow queries → grouped by source location, severity by average duration
3. Errors → grouped by exception class + location
4. Slow requests → grouped by controller#action
5. Code smells → from CodeAnalyzer

**Output:** Array of `Tailscope::Issue` structs, sorted by severity (critical first) then occurrence count.

### Frontend

**Technology:** React 18 + React Router 6 + Tailwind CSS, built with Vite

**Build output:** Single `app.js` and `app.css` in `public/`

**Architecture:**
- `client/src/main.jsx` — Entry point
- `client/src/App.jsx` — Router definition
- `client/src/api.js` — Fetch wrapper for API calls
- `client/src/pages/` — Page components (Issues, Queries, Requests, Errors, Debugger)
- `client/src/components/` — Shared UI components
- `client/src/drawers/` — Detail drawer components

The SPA is served by `SpaController#index` which renders the HTML shell. All navigation is client-side via React Router. API calls go to `/tailscope/api/*`.

## Data Flow Examples

### Slow Query Recording

```
1. ActiveRecord executes SQL
2. sql.active_record notification fires
3. SqlSubscriber.handle receives event
4. Duration > threshold? → resolve source location
5. Storage.record_query pushes to SizedQueue
6. Writer thread pops and INSERTs into tailscope_queries
```

### N+1 Detection

```
1. Middleware starts request, initializes empty query log
2. Each SQL query → SqlSubscriber adds to Thread.current[:tailscope_query_log]
3. Request completes → middleware calls NPlusOne.analyze!
4. Queries grouped by normalized SQL + source location
5. Groups exceeding threshold → Storage.record_query with n_plus_one flag
```

### Error Capture

```
1. Exception raised during request processing
2. Middleware rescue block catches it
3. Error details extracted (class, message, backtrace, source)
4. Storage.record_error pushes to SizedQueue
5. Exception re-raised (not suppressed)
6. Normal error handling continues
```

### Issue Aggregation

```
1. User visits /tailscope (Issues page)
2. API controller calls IssueBuilder.build_all
3. IssueBuilder queries Storage for raw data
4. Groups and deduplicates by source location
5. Runs CodeAnalyzer for code smells
6. Sorts by severity, returns Issue structs
7. React renders issue cards
```

## Thread Safety

- Storage write queue uses Ruby's `SizedQueue` (thread-safe)
- Per-request state uses `Thread.current` (thread-local)
- BreakpointManager uses `Mutex` for thread-safe access
- Debug sessions use `ConditionVariable` for thread synchronization
- SQLite WAL mode allows concurrent reads during writes

## Performance Characteristics

| Operation | Impact |
|-----------|--------|
| SQL subscriber | ~0.1ms per query (source location resolution) |
| Action subscriber | ~0.05ms per request |
| Middleware overhead | ~0.1ms per request |
| Storage write | Async, non-blocking on request path |
| N+1 analysis | ~1ms per request (proportional to query count) |
| Debugger (disabled) | Zero overhead |
| Debugger (enabled) | 5-20% overhead (TracePoint on every line) |
