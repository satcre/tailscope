# Tailscope

Rails debugging and tracing gem that captures slow queries, N+1 patterns, slow requests, and runtime errors. Provides a web dashboard (mounted engine) and CLI for viewing issues with source-level detail.

## Installation

Add to your Gemfile:

```ruby
gem "tailscope"
```

Run the install generator:

```bash
rails generate tailscope:install
```

This creates `config/initializers/tailscope.rb` and mounts the engine at `/tailscope`.

## Configuration

```ruby
Tailscope.configure do |config|
  config.enabled = Rails.env.development?
  config.slow_query_threshold_ms = 100
  config.slow_request_threshold_ms = 500
  config.n_plus_one_threshold = 3
  config.storage_retention_days = 7
  config.database_path = Rails.root.join("db", "tailscope.sqlite3").to_s
end
```

## Web Dashboard

Visit `/tailscope` in your browser to see:

- **Dashboard** — stat cards and recent events
- **Queries** — slow SQL queries with source locations
- **N+1** — detected N+1 query patterns
- **Requests** — slow HTTP requests with controller/action detail
- **Errors** — captured exceptions with backtraces
- **Source viewer** — inline source code at the exact line

## CLI

```bash
tailscope stats              # Summary counts
tailscope queries            # List slow queries
tailscope queries -n         # List N+1 queries only
tailscope requests           # List slow requests
tailscope errors             # List captured exceptions
tailscope tail               # Live polling mode
tailscope purge              # Delete old records
tailscope show query 42      # Detail view for a record
```

## How It Works

- **Slow queries**: Subscribes to `sql.active_record` notifications, records queries exceeding the threshold
- **N+1 detection**: Groups queries per-request by normalized SQL + call site, flags when count exceeds threshold
- **Slow requests**: Rack middleware times each request, records those exceeding the threshold
- **Error capture**: Middleware rescue block captures uncaught exceptions, re-raises after recording

All data is stored in a local SQLite database (WAL mode) with async writes via a background thread.

## License

MIT
