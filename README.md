# Tailscope

Development profiler and debugger for Ruby on Rails. Captures slow queries, N+1 patterns, slow requests, runtime errors, and code smells — then presents them in a web dashboard with source-level detail, suggested fixes, and one-click editor integration.

 > [!CAUTION]
> **Early stage.** Tailscope is under active development and has not been battle-tested in production. APIs, configuration, and internal behavior may change. Use in development environments only.

## Features

- **Slow Query Detection** -- Records SQL queries exceeding a configurable threshold with exact source locations
- **N+1 Query Detection** -- Groups identical queries per request and flags patterns exceeding a count threshold
- **Slow Request Tracking** -- Captures HTTP requests exceeding a duration threshold with view/DB time breakdown
- **Error Capture** -- Records uncaught exceptions with backtraces, HTTP context, and request correlation
- **Code Smell Analysis** -- Static analysis detects missing validations, fat models/controllers, hardcoded secrets, and more
- **Interactive Debugger** -- Set breakpoints, inspect variables, evaluate expressions, and step through code from the browser
- **Open in Editor** -- One-click to open any source location in VS Code, Sublime Text, RubyMine, or Neovim
- **CLI Tools** -- Terminal access to stats, queries, requests, errors, and live tail mode
- **Zero Configuration** -- Works out of the box with sensible defaults; all thresholds are configurable

## Quick Start

Add to your Gemfile:

```ruby
group :development do
  gem "tailscope"
end
```

Run the install generator:

```bash
bundle install
rails generate tailscope:install
```

Start your Rails server and visit **`/tailscope`** in your browser.

## Screenshots

### Issues Dashboard

Aggregated issues with severity counts, filtering, SQL detail, and suggested fixes.

![Issues Dashboard](docs/screenshots/issues-dashboard.png)

### Queries
![Queries](docs/screenshots/queries.png)

### Requests
![Requests](docs/screenshots/requests.png)

### Debugger
![Debugger](docs/screenshots/debugger.png)

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/getting-started.md) | Installation, first run, and basic usage |
| [Configuration](docs/configuration.md) | All configuration options with examples |
| [Web Dashboard](docs/web-dashboard.md) | Dashboard pages, filtering, and navigation |
| [Detectors](docs/detectors.md) | How each detection system works |
| [Code Analysis](docs/code-analysis.md) | Static code smell detection rules |
| [Debugger](docs/debugger.md) | Interactive breakpoint debugger |
| [Editor Integration](docs/editor-integration.md) | Setting up "Open in Editor" |
| [CLI Reference](docs/cli.md) | Command-line interface |
| [API Reference](docs/api.md) | REST API endpoints |
| [Architecture](docs/architecture.md) | Internal design and data flow |

## How It Works

Tailscope installs as a Rails engine and Rack middleware. It subscribes to ActiveSupport notifications for SQL queries and controller actions, captures exceptions in middleware, and stores everything in a local SQLite database using async writes for minimal performance impact.

```
Request → Middleware (timing + error capture)
       → SQL Subscriber (query recording)
       → Action Subscriber (request recording)
       → N+1 Detector (per-request analysis)
       → SQLite Storage (async background writer)
       → Web Dashboard / CLI (read)
```

Data is automatically purged after a configurable retention period (default: 7 days).

## Requirements

- Ruby >= 3.0
- Rails >= 6.0
- SQLite3

## License

MIT. See [LICENSE.txt](LICENSE.txt).
