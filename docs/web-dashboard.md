# Web Dashboard

The Tailscope web dashboard is a React single-page application mounted at `/tailscope` in your Rails app. It provides a visual interface for browsing captured issues, queries, requests, errors, and debugging sessions.

## Accessing the Dashboard

Visit `http://localhost:3000/tailscope` (or wherever your Rails app runs). The dashboard is only accessible when `config.enabled` is `true`.

## Pages

### Issues

The default landing page. Shows an aggregated view of all detected problems across all categories.

![Issues Dashboard](screenshots/issues-dashboard.png)

**Features:**
- Severity filter tabs: All, Critical, Warning, Info
- Issue cards with title, description, occurrence count, and total duration
- Suggested fix with before/after code examples
- Inline source code viewer
- "Open in Editor" button
- Ignore/unignore issues to hide known problems

**Issue types:**
- N+1 query patterns
- Slow queries (grouped by source location)
- Slow requests (grouped by controller#action)
- Error patterns (grouped by exception class and location)
- Code smells (from static analysis)

**Ignored issues:** Click the ignore button on any issue to hide it. Switch to the "Ignored" tab to see and restore ignored issues.

### Queries

Lists individual slow SQL queries ordered by most recent.

**Columns:**
- SQL text (truncated, expandable)
- Duration in milliseconds
- Source file and line
- N+1 indicator with count
- Recorded timestamp

**Filtering:**
- Toggle "N+1 only" to show only N+1 pattern queries

**Detail drawer:** Click any query to open a side drawer showing:
- Full SQL text
- Duration and timing
- Source location with code context
- Request ID (links to associated request)

### Requests

Lists individual slow HTTP requests ordered by most recent.

**Columns:**
- HTTP method and path
- Status code
- Total duration
- View render time
- Database time
- Controller#action

**Detail drawer:** Click any request to see:
- Full request details and params
- Breakdown: total, view, DB time
- Associated queries (all SQL executed during this request)
- Associated errors (any exceptions during this request)

### Errors

Lists captured exceptions ordered by most recent.

**Columns:**
- Exception class
- Message (truncated)
- Source file and line
- HTTP method and path
- Recorded timestamp

**Detail drawer:** Click any error to see:
- Full exception message
- Backtrace
- HTTP context (method, path, params)
- Source code at the error location

### Debugger

Interactive breakpoint debugger. Requires `config.debugger_enabled = true`.

**Features:**
- File browser to navigate your source code
- Set breakpoints on any line by clicking the gutter
- Conditional breakpoints (Ruby expression evaluated at break time)
- Active session panel shows paused execution points
- Variable inspector for local variables
- Expression evaluator
- Step controls: Step Into, Step Over, Step Out, Continue

See [Debugger](debugger.md) for detailed usage.

## Source Code Viewer

Available throughout the dashboard wherever a source location is shown. Displays the file content with:
- Line numbers
- Highlighted current line
- Surrounding context (15 lines above and below)
- Syntax awareness (Ruby code formatting)

## Open in Editor

A button appears next to every source location. Clicking it opens the file at the exact line in your configured editor. See [Editor Integration](editor-integration.md) for setup.

## Pagination

All list pages (Queries, Requests, Errors) are paginated with 25 items per page. Navigation controls appear at the bottom of each list.
