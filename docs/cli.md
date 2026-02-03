# CLI Reference

Tailscope includes a command-line interface for terminal-based access to captured data. The CLI reads directly from the SQLite database and does not require the Rails server to be running.

## Setup

The CLI is available after installing the gem:

```bash
bundle exec tailscope [command]
```

Or if the gem's `bin` directory is in your `$PATH`:

```bash
tailscope [command]
```

## Commands

### `stats`

Display summary statistics.

```bash
tailscope stats
```

Output:
```
Tailscope Statistics
------------------------------
Slow queries:    47
N+1 queries:     12
Slow requests:   8
Errors:          3
Avg query time:  234ms
Avg request time:892ms
```

### `queries`

List recorded slow queries.

```bash
tailscope queries [options]
```

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--n_plus_one` | `-n` | false | Show only N+1 queries |
| `--limit` | `-l` | 20 | Number of records to show |

Examples:

```bash
# List recent slow queries
tailscope queries

# Show only N+1 patterns
tailscope queries -n

# Show more results
tailscope queries -l 50
```

Output:
```
ID     Duration   SQL                                                          Source
--------------------------------------------------------------------------------------------------------------
142    234ms      SELECT "users".* FROM "users" WHERE "users"."emai...         app/controllers/users_controller.rb:15
141    156ms      SELECT "orders".* FROM "orders" WHERE "orders"."u... [N+1 x8] app/views/users/show.html.erb:23
```

### `requests`

List recorded slow HTTP requests.

```bash
tailscope requests [options]
```

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--limit` | `-l` | 20 | Number of records to show |

Output:
```
ID     Method  Path                                     Status Duration   Controller#Action
-----------------------------------------------------------------------------------------------
28     GET     /users/42                                200    892ms      UsersController#show
27     POST    /orders                                  201    1234ms     OrdersController#create
```

### `errors`

List recorded exceptions.

```bash
tailscope errors [options]
```

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--limit` | `-l` | 20 | Number of records to show |

Output:
```
ID     Exception                      Message                                            Source
------------------------------------------------------------------------------------------------------------------------
5      ActiveRecord::RecordNotFound   Couldn't find User with 'id'=999                   app/controllers/users_controller.rb:8
4      NoMethodError                  undefined method `name' for nil                     app/views/orders/show.html.erb:12
```

### `tail`

Live polling mode. Watches for new events and prints them as they arrive.

```bash
tailscope tail [options]
```

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--interval` | `-i` | 2 | Poll interval in seconds |

Output:
```
Tailscope — live tail (Ctrl+C to stop)
------------------------------------------------------------
[2024-01-15 14:23:01] QUERY   234ms  SELECT "users".* FROM "users" WHERE...
[2024-01-15 14:23:01] REQUEST 892ms  GET /users/42 → 200
[2024-01-15 14:23:05] ERROR   45ms   NoMethodError: undefined method `name'...
```

Press `Ctrl+C` to stop.

### `show`

Show detailed information about a specific record.

```bash
tailscope show [category] [id]
```

Categories: `query`, `request`, `error`

Examples:

```bash
tailscope show query 142
tailscope show request 28
tailscope show error 5
```

Output shows all fields for the record:
```
id: 142
sql_text: SELECT "users".* FROM "users" WHERE "users"."email" = ? LIMIT ?
duration_ms: 234.56
name: User Load
source_file: /path/to/app/controllers/users_controller.rb
source_line: 15
source_method: show
request_id: abc-123-def
n_plus_one: 0
recorded_at: 2024-01-15 14:23:01
```

### `purge`

Delete old records from the database.

```bash
tailscope purge [options]
```

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--days` | | `storage_retention_days` config | Delete records older than N days |

Examples:

```bash
# Use configured retention period
tailscope purge

# Delete records older than 3 days
tailscope purge --days 3
```

## Database Location

The CLI uses the database path from your Tailscope configuration. By default this is `db/tailscope.sqlite3` in your Rails root.

If you've customized the path, ensure the CLI can find it. The CLI loads the Tailscope gem and reads the configuration.
