# Configuration

All configuration is done in `config/initializers/tailscope.rb`, created by the install generator. Every option has a sensible default.

## Full Configuration Reference

```ruby
Tailscope.configure do |config|
  # Master switch. When false, no data is recorded and middleware is a no-op.
  # Default: Rails.env.development?
  config.enabled = Rails.env.development?

  # Minimum SQL query duration to record (milliseconds).
  # Queries faster than this are ignored.
  # Default: 100
  config.slow_query_threshold_ms = 100

  # Minimum HTTP request duration to record (milliseconds).
  # Requests faster than this are ignored.
  # Default: 500
  config.slow_request_threshold_ms = 500

  # Number of identical queries from the same call site within a single
  # request to flag as an N+1 pattern.
  # Default: 3
  config.n_plus_one_threshold = 3

  # Days to retain recorded data before automatic purge.
  # Purge runs once on application startup.
  # Default: 7
  config.storage_retention_days = 7

  # Path to the SQLite database file.
  # Default: Rails.root.join("db", "tailscope.sqlite3").to_s
  config.database_path = Rails.root.join("db", "tailscope.sqlite3").to_s

  # Root directory for source file resolution and path display.
  # Default: Rails.root.to_s
  config.source_root = Rails.root.to_s

  # Enable the interactive debugger (TracePoint-based).
  # This adds overhead to every line of Ruby executed. Only enable when needed.
  # Default: false
  config.debugger_enabled = false

  # Maximum time (seconds) a debugger session will wait for user interaction
  # before automatically continuing.
  # Default: 60
  config.debugger_timeout = 60

  # Editor for "Open in Editor" feature.
  # Accepts a symbol (:vscode, :sublime, :rubymine, :nvim_terminal, :nvim_iterm)
  # or a custom command string with {file}, {line}, {project} placeholders.
  # Default: auto-detect
  config.editor = :vscode
end
```

## Options Detail

### `enabled`

Controls whether Tailscope records any data. When `false`, the middleware passes requests through without timing, subscribers ignore events, and the storage writer is not started. The web dashboard remains accessible but shows no new data.

Set to `true` in staging or CI environments if you want to analyze performance there.

### `slow_query_threshold_ms`

The minimum SQL query duration in milliseconds before it gets recorded. Queries below this threshold are still tracked in the per-request query log (for N+1 detection) but are not stored individually.

Recommended values:
- **50** -- Aggressive, catches most optimization opportunities
- **100** -- Default, good balance
- **500** -- Relaxed, only catches major problems

### `slow_request_threshold_ms`

The minimum HTTP request duration in milliseconds. Requests below this are not recorded.

Recommended values:
- **200** -- Aggressive
- **500** -- Default
- **1000** -- Only very slow requests

### `n_plus_one_threshold`

How many identical queries from the same call site in a single request constitute an N+1 pattern. For example, if a view calls `user.company.name` for 10 users, that produces 10 `SELECT * FROM companies WHERE id = ?` queries from the same line. With a threshold of 3, this gets flagged.

Lower values catch smaller N+1 patterns but may produce more noise.

### `storage_retention_days`

Data older than this many days is automatically deleted on application startup. Purge runs once in a background thread, 5 seconds after boot.

You can also manually purge from the CLI:

```bash
tailscope purge --days 3
```

### `database_path`

Path to the SQLite database file. Tailscope creates the file and parent directories automatically. Add this path to your `.gitignore`:

```
db/tailscope.sqlite3
db/tailscope.sqlite3-wal
db/tailscope.sqlite3-shm
```

### `source_root`

Root directory used for:
- Resolving relative source paths in backtraces
- Security: file operations (source viewer, editor) are restricted to this directory
- Path display: shown as relative paths in the dashboard

### `debugger_enabled`

Enables the TracePoint-based debugger. When enabled, a `TracePoint` hook is registered for `:line`, `:call`, and `:return` events. This has measurable overhead on every Ruby line executed, so only enable it when you need to debug.

The debugger can be toggled at runtime through the web dashboard without restarting the server.

### `debugger_timeout`

Maximum seconds a paused debugger session waits before automatically continuing. This prevents a forgotten breakpoint from blocking your server indefinitely.

### `editor`

Configure which editor opens when you click "Open in Editor" in the dashboard. See [Editor Integration](editor-integration.md) for details.

**Preset editors:**
- `:vscode` -- Visual Studio Code
- `:sublime` -- Sublime Text
- `:rubymine` -- RubyMine
- `:nvim_terminal` -- Neovim in Terminal.app (macOS) or x-terminal-emulator (Linux)
- `:nvim_iterm` -- Neovim in iTerm2 (macOS)

**Custom command:**
```ruby
config.editor = "emacs +{line} {file}"
```

Placeholders: `{file}` (absolute path), `{line}` (line number), `{project}` (source root).

**Auto-detect:** When not configured, Tailscope checks the `$EDITOR` environment variable, then scans `$PATH` for known editor binaries.

## Environment-Specific Configuration

```ruby
Tailscope.configure do |config|
  config.enabled = Rails.env.development? || Rails.env.staging?

  if Rails.env.staging?
    config.slow_query_threshold_ms = 200
    config.slow_request_threshold_ms = 1000
    config.debugger_enabled = false
  end
end
```

## .gitignore

Add the following to your `.gitignore`:

```
db/tailscope.sqlite3
db/tailscope.sqlite3-wal
db/tailscope.sqlite3-shm
```
