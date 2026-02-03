# API Reference

Tailscope exposes a JSON REST API under `/tailscope/api/`. This API powers the web dashboard and can be used for custom integrations.

All endpoints return JSON. The API is mounted within the Rails engine and shares the application's session and CSRF protection.

## Issues

### `GET /tailscope/api/issues`

Returns aggregated issues from all detection sources.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `severity` | string | Filter by severity: `critical`, `warning`, `info` |
| `tab` | string | `ignored` to show only ignored issues |

**Response:**

```json
{
  "issues": [
    {
      "severity": "critical",
      "type": "n_plus_one",
      "title": "N+1 Query — User Load",
      "description": "10 identical queries from the same call site",
      "source_file": "/app/views/users/index.html.erb",
      "source_line": 23,
      "suggested_fix": "Add `includes(:company)` to the controller query",
      "occurrences": 10,
      "total_duration_ms": 456.78,
      "fingerprint": "abc123def456",
      "latest_at": "2024-01-15T14:23:01Z",
      "metadata": {}
    }
  ],
  "counts": {
    "critical": 2,
    "warning": 5,
    "info": 8
  },
  "ignored_count": 1
}
```

### `POST /tailscope/api/issues/:fingerprint/ignore`

Mark an issue as ignored.

**Response:** `{ "ok": true }`

### `POST /tailscope/api/issues/:fingerprint/unignore`

Remove ignored status from an issue.

**Response:** `{ "ok": true }`

## Queries

### `GET /tailscope/api/queries`

List recorded slow queries.

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `page` | integer | 1 | Page number |
| `n_plus_one_only` | boolean | false | Filter to N+1 patterns only |

**Response:**

```json
{
  "queries": [
    {
      "id": 142,
      "sql_text": "SELECT \"users\".* FROM \"users\" WHERE ...",
      "duration_ms": 234.56,
      "name": "User Load",
      "source_file": "/app/controllers/users_controller.rb",
      "source_line": 15,
      "source_method": "show",
      "request_id": "abc-123",
      "n_plus_one": 0,
      "n_plus_one_count": null,
      "recorded_at": "2024-01-15T14:23:01"
    }
  ],
  "total": 47,
  "page": 1,
  "per_page": 25
}
```

### `GET /tailscope/api/queries/:id`

Get a single query record.

**Response:** Single query object (same structure as list item).

Returns `404` if not found.

## Requests

### `GET /tailscope/api/requests`

List recorded slow requests.

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `page` | integer | 1 | Page number |

**Response:**

```json
{
  "requests": [
    {
      "id": 28,
      "method": "GET",
      "path": "/users/42",
      "status": 200,
      "duration_ms": 892.34,
      "controller": "UsersController",
      "action": "show",
      "view_runtime_ms": 123.45,
      "db_runtime_ms": 456.78,
      "params": "{\"id\":\"42\"}",
      "request_id": "abc-123",
      "recorded_at": "2024-01-15T14:23:01"
    }
  ],
  "total": 8,
  "page": 1,
  "per_page": 25
}
```

### `GET /tailscope/api/requests/:id`

Get a single request record with associated queries and errors.

**Response:**

```json
{
  "request": { ... },
  "queries": [ ... ],
  "errors": [ ... ]
}
```

Returns `404` if not found.

## Errors

### `GET /tailscope/api/errors`

List recorded exceptions.

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `page` | integer | 1 | Page number |

**Response:**

```json
{
  "errors": [
    {
      "id": 5,
      "exception_class": "ActiveRecord::RecordNotFound",
      "message": "Couldn't find User with 'id'=999",
      "backtrace": "app/controllers/users_controller.rb:8:in `show'\n...",
      "source_file": "/app/controllers/users_controller.rb",
      "source_line": 8,
      "source_method": "show",
      "request_method": "GET",
      "request_path": "/users/999",
      "params": "{}",
      "request_id": "def-456",
      "duration_ms": 45.12,
      "recorded_at": "2024-01-15T14:23:05"
    }
  ],
  "total": 3,
  "page": 1,
  "per_page": 25
}
```

### `GET /tailscope/api/errors/:id`

Get a single error record.

Returns `404` if not found.

## Tests

### `GET /tailscope/api/tests/specs`

Discover spec files in the project. Returns a tree structure of `spec/` directory.

**Response:**

```json
{
  "available": true,
  "tree": [
    {
      "path": "spec/models",
      "name": "models",
      "type": "folder",
      "category": "model",
      "children": [
        {
          "path": "spec/models/user_spec.rb",
          "name": "user_spec.rb",
          "type": "file",
          "category": "model"
        }
      ]
    }
  ]
}
```

Returns `{ "available": false, "tree": [] }` if RSpec is not installed.

### `POST /tailscope/api/tests/run`

Start a spec run.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `target` | string | Optional. Spec file or directory path (e.g. `spec/models/user_spec.rb` or `spec/models/`). Omit to run all specs. Supports line targeting: `spec/models/user_spec.rb:15` |

**Response:**

```json
{
  "id": "a1b2c3d4e5f6",
  "status": "running"
}
```

Returns `409` with `{ "error": "Already running" }` if a run is in progress.

### `GET /tailscope/api/tests/status`

Get the status and results of the current or most recent spec run.

**Response:**

```json
{
  "run": {
    "id": "a1b2c3d4e5f6",
    "status": "finished",
    "target": "all",
    "started_at": "2024-01-15T14:23:01+00:00",
    "summary": {
      "total": 42,
      "passed": 38,
      "failed": 3,
      "pending": 1,
      "duration_s": 4.567
    },
    "examples": [
      {
        "id": "./spec/models/user_spec.rb[1:1:1]",
        "description": "validates presence of name",
        "full_description": "User validations validates presence of name",
        "status": "passed",
        "file_path": "./spec/models/user_spec.rb",
        "line_number": 15,
        "run_time": 0.0234,
        "exception": null
      }
    ],
    "console_output": "....(ANSI-encoded RSpec output)....",
    "error_output": null
  }
}
```

Status values: `running`, `finished`, `error`, `cancelled`.

Failed examples include an `exception` object:

```json
{
  "exception": {
    "class": "RSpec::Expectations::ExpectationNotMetError",
    "message": "expected: true\n     got: false",
    "backtrace": ["./spec/models/user_spec.rb:18:in `block (3 levels) in <top>'"]
  }
}
```

### `POST /tailscope/api/tests/cancel`

Cancel a running spec execution.

**Response:** `{ "status": "cancelled" }`

Returns `409` with `{ "error": "No run in progress" }` if nothing is running.

### `GET /tailscope/api/tests/examples`

Dry-run to discover examples in a spec file without executing them. Uses `rspec --dry-run`.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `target` | string | **Required.** Spec file path (e.g. `spec/models/user_spec.rb`) |

**Response:**

```json
{
  "examples": [
    {
      "id": "./spec/models/user_spec.rb[1:1:1]",
      "description": "validates presence of name",
      "full_description": "User validations validates presence of name",
      "file_path": "./spec/models/user_spec.rb",
      "line_number": 15
    }
  ]
}
```

## Source

### `GET /tailscope/api/source`

Get source code context around a specific line.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `file` | string | **Required.** Absolute or relative path (resolved against `source_root`) |
| `line` | integer | **Required.** Line number to highlight |
| `radius` | integer | Optional. Context lines above and below. Default: 50, range: 10–200 |

**Response:**

```json
{
  "file": "/app/controllers/users_controller.rb",
  "highlight_line": 15,
  "lines": [
    { "number": 1, "content": "class UsersController < ApplicationController", "current": false },
    { "number": 15, "content": "    @user = User.find(params[:id])", "current": true }
  ]
}
```

Returns `403` if the file is outside `source_root`.
Returns `404` if the file doesn't exist.

## Editor

### `POST /tailscope/api/editor/open`

Open a file in the configured editor.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `file` | string | **Required.** Absolute path to the file |
| `line` | integer | **Required.** Line number to open at |
| `editor` | string | Optional. Override editor selection |

**Response:** `{ "ok": true, "editor": "vscode" }`

Returns `403` if the file is outside `source_root`.
Returns `404` if the file doesn't exist.
Returns `422` if no editor is configured or available.

### `POST /tailscope/api/editor/check`

Check if an editor binary is available.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `editor` | string | **Required.** Editor name: `vscode`, `sublime`, `rubymine`, `nvim_terminal`, `nvim_iterm` |

**Response:** `{ "available": true, "editor": "vscode" }`

Returns `422` for unknown editor names.

## Debugger

### `GET /tailscope/api/debugger`

Get debugger state including breakpoints and sessions.

**Response:**

```json
{
  "breakpoints": [
    { "id": 1, "file": "/app/controllers/users_controller.rb", "line": 15, "condition": null, "enabled": true }
  ],
  "active_sessions": [],
  "recent_sessions": []
}
```

### `POST /tailscope/api/debugger/breakpoints`

Create a new breakpoint.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `file` | string | **Required.** Absolute or relative path (resolved against `source_root`) |
| `line` | integer | **Required.** Line number |
| `condition` | string | Optional. Ruby expression for conditional breakpoint |

**Response:** `{ "ok": true, "breakpoint": { ... } }`

Returns `403` if the file is outside `source_root`.

### `DELETE /tailscope/api/debugger/breakpoints/:id`

Remove a breakpoint.

**Response:** `{ "ok": true }`

### `GET /tailscope/api/debugger/sessions/:id`

Get a specific debug session with variables and source context.

**Response:**

```json
{
  "id": "session-uuid",
  "file": "/app/controllers/users_controller.rb",
  "line": 15,
  "status": "paused",
  "locals": { "user_id": "42", "params": "{...}" },
  "call_stack": [ ... ],
  "source_context": { "lines": [...], "highlight_line": 15 }
}
```

Returns `404` if session not found.

### `POST /tailscope/api/debugger/sessions/:id/evaluate`

Evaluate a Ruby expression in the session's binding.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `expression` | string | **Required.** Ruby expression to evaluate |

**Response:** `{ "result": "evaluated result as string" }`

### `POST /tailscope/api/debugger/sessions/:id/continue`

Continue execution until next breakpoint.

### `POST /tailscope/api/debugger/sessions/:id/step_into`

Step to the next line of Ruby (entering method calls).

### `POST /tailscope/api/debugger/sessions/:id/step_over`

Step to the next line at the same call depth.

### `POST /tailscope/api/debugger/sessions/:id/step_out`

Continue until the current method returns.

### `GET /tailscope/api/debugger/poll`

Poll for active debug sessions. Used by the dashboard for real-time updates.

**Response:**

```json
{
  "active_sessions": [
    { "id": "session-uuid", "file": "...", "line": 15, "status": "paused" }
  ]
}
```

### `GET /tailscope/api/debugger/browse`

Browse source files and directories.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `path` | string | Optional. Absolute or relative path (resolved against `source_root`). Defaults to `source_root` |

**Response (directory):**

```json
{
  "is_directory": true,
  "path": "/app",
  "directories": ["controllers", "models", "views"],
  "files": ["application_record.rb"]
}
```

**Response (file):**

```json
{
  "is_directory": false,
  "path": "/app/controllers/users_controller.rb",
  "lines": [
    { "number": 1, "content": "class UsersController < ApplicationController" }
  ]
}
```

Returns `403` if the path is outside `source_root`.
