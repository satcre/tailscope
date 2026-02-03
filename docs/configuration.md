# Configuration

All configuration is done in `config/initializers/tailscope.rb`, created by the install generator. Every option has a sensible default.

---

## Quick Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `Rails.env.development?` | Master switch for data recording |
| `slow_query_threshold_ms` | integer | `100` | Minimum SQL duration to record (ms) |
| `slow_request_threshold_ms` | integer | `500` | Minimum HTTP request duration to record (ms) |
| `n_plus_one_threshold` | integer | `3` | Identical queries to flag as N+1 |
| `storage_retention_days` | integer | `7` | Days to retain data before auto-purge |
| `database_path` | string | `db/tailscope.sqlite3` | Path to SQLite database |
| `source_root` | string | `Rails.root.to_s` | Root directory for source resolution |
| `debugger_enabled` | boolean | `false` | Enable interactive debugger |
| `debugger_timeout` | integer | `60` | Seconds before auto-continue |
| `editor` | symbol/string | auto-detect | Editor for "Open in Editor" |

---

## Full Example

```ruby
Tailscope.configure do |config|
  config.enabled = Rails.env.development?
  config.slow_query_threshold_ms = 100
  config.slow_request_threshold_ms = 500
  config.n_plus_one_threshold = 3
  config.storage_retention_days = 7
  config.database_path = Rails.root.join("db", "tailscope.sqlite3").to_s
  config.source_root = Rails.root.to_s
  config.debugger_enabled = false
  config.debugger_timeout = 60
  config.editor = :vscode
end
```

---

## Options Detail

### `enabled`

Controls whether Tailscope records any data. When `false`, the middleware passes requests through without timing, subscribers ignore events, and the storage writer is not started. The web dashboard remains accessible but shows no new data.

Set to `true` in staging or CI environments if you want to analyze performance there.

### `slow_query_threshold_ms`

Minimum SQL query duration (ms) before it gets recorded. Queries below this threshold are still tracked in the per-request query log (for N+1 detection) but are not stored individually.

| Value | Use case |
|-------|----------|
| `50` | Aggressive -- catches most optimization opportunities |
| `100` | Default -- good balance |
| `500` | Relaxed -- only catches major problems |

### `slow_request_threshold_ms`

Minimum HTTP request duration (ms). Requests below this are not recorded.

| Value | Use case |
|-------|----------|
| `200` | Aggressive |
| `500` | Default |
| `1000` | Only very slow requests |

### `n_plus_one_threshold`

How many identical queries from the same call site in a single request constitute an N+1 pattern. For example, if a view calls `user.company.name` for 10 users, that produces 10 `SELECT * FROM companies WHERE id = ?` queries from the same line. With a threshold of 3, this gets flagged.

Lower values catch smaller N+1 patterns but may produce more noise.

### `storage_retention_days`

Data older than this many days is automatically deleted on application startup. Purge runs once in a background thread, 5 seconds after boot.

Manual purge from the CLI:

```bash
tailscope purge --days 3
```

### `database_path`

Path to the SQLite database file. Tailscope creates the file and parent directories automatically.

Add to your `.gitignore`:

```
db/tailscope.sqlite3
db/tailscope.sqlite3-wal
db/tailscope.sqlite3-shm
```

### `source_root`

Root directory used for:
- Resolving relative source paths in backtraces
- Security -- file operations (source viewer, editor) are restricted to this directory
- Path display -- shown as relative paths in the dashboard

### `debugger_enabled`

Enables the TracePoint-based debugger. When enabled, a `TracePoint` hook is registered for `:line`, `:call`, and `:return` events. This has measurable overhead on every Ruby line executed, so only enable it when you need to debug.

The debugger can be toggled at runtime through the web dashboard without restarting the server.

### `debugger_timeout`

Maximum seconds a paused debugger session waits before automatically continuing. This prevents a forgotten breakpoint from blocking your server indefinitely.

### `editor`

Configure which editor opens when you click "Open in Editor" in the dashboard. See [Editor Integration](editor-integration.md) for details.

**Preset editors:**

| Symbol | Editor |
|--------|--------|
| `:vscode` | Visual Studio Code |
| `:sublime` | Sublime Text |
| `:rubymine` | RubyMine |
| `:nvim_terminal` | Neovim in Terminal.app (macOS) or x-terminal-emulator (Linux) |
| `:nvim_iterm` | Neovim in iTerm2 (macOS) |

**Custom command:**

```ruby
config.editor = "emacs +{line} {file}"
```

Placeholders: `{file}` (absolute path), `{line}` (line number), `{project}` (source root).

**Auto-detect:** When not configured, Tailscope checks the `$EDITOR` environment variable, then scans `$PATH` for known editor binaries.

---

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

---

## .gitignore

Add the following to your `.gitignore`:

```
db/tailscope.sqlite3
db/tailscope.sqlite3-wal
db/tailscope.sqlite3-shm
```
