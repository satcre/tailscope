# Getting Started

## Installation

Add Tailscope to your Gemfile. It should only run in development:

```ruby
group :development do
  gem "tailscope"
end
```

Install the gem:

```bash
bundle install
```

Run the install generator:

```bash
rails generate tailscope:install
```

This does two things:

1. Creates `config/initializers/tailscope.rb` with default configuration
2. Mounts the engine in your `config/routes.rb` at `/tailscope`

## First Run

Start your Rails server as usual:

```bash
rails server
```

Visit **`http://localhost:3000/tailscope`** in your browser. You'll see an empty dashboard.

Now use your application normally. As you navigate pages, Tailscope silently records slow queries, N+1 patterns, slow requests, and errors. Refresh the Tailscope dashboard to see captured issues.

## What Gets Recorded

Tailscope begins recording automatically when your Rails app starts. By default, it captures:

| Category | Condition | Default Threshold |
|----------|-----------|-------------------|
| Slow Queries | SQL duration exceeds threshold | 100ms |
| N+1 Queries | Same SQL from same call site repeated N times in one request | 3 occurrences |
| Slow Requests | HTTP request duration exceeds threshold | 500ms |
| Errors | Any uncaught exception during a request | All |
| Code Smells | Static analysis of `app/` Ruby files | On-demand |

## Dashboard Overview

The main dashboard shows aggregated **issues** — deduplicated problems sorted by severity:

- **Critical** -- Data exposure, hardcoded secrets, frequent N+1 patterns
- **Warning** -- Slow queries, missing validations, fat controllers
- **Info** -- TODO comments, long methods, Law of Demeter violations

Each issue includes:
- Source file and line number
- Occurrence count and total duration
- A suggested fix with before/after code examples
- A button to view the source code inline
- A button to open the file in your editor

## Navigation

The dashboard has five pages accessible from the sidebar:

- **Issues** -- Aggregated view of all detected problems (default)
- **Queries** -- Individual slow SQL queries with source locations
- **Requests** -- Individual slow HTTP requests with controller/action detail
- **Errors** -- Individual captured exceptions with backtraces
- **Debugger** -- Interactive breakpoint debugger (requires separate opt-in)

## CLI Access

Tailscope includes a command-line interface for terminal-based workflows:

```bash
# Summary statistics
tailscope stats

# List slow queries
tailscope queries

# List N+1 queries only
tailscope queries -n

# Live tail mode (polls for new events)
tailscope tail

# Show detail for a specific record
tailscope show query 42
```

See the [CLI Reference](cli.md) for all commands.

## Next Steps

- [Configuration](configuration.md) -- Adjust thresholds and enable features
- [Detectors](detectors.md) -- Understand how each detection system works
- [Debugger](debugger.md) -- Set up the interactive debugger
- [Editor Integration](editor-integration.md) -- Configure "Open in Editor"
