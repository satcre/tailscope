# Web Dashboard

The Tailscope web dashboard is a React single-page application mounted at `/tailscope` in your Rails app. It provides a visual interface for browsing captured issues, queries, requests, errors, and debugging sessions.

---

## Accessing the Dashboard

Visit `http://localhost:3000/tailscope` (or wherever your Rails app runs). The dashboard is only accessible when `config.enabled` is `true`.

---

## Pages

Navigation headings for **Queries** and **Errors** display live item counts.

| Page | Description |
|------|-------------|
| [Issues](#issues) | Aggregated view of all detected problems (default) |
| [Queries](#queries) | Individual slow SQL queries |
| [Requests](#requests) | Individual slow HTTP requests |
| [Errors](#errors) | Captured exceptions |
| [Jobs](#jobs) | Background job executions |
| [Tests](#tests) | Browser-based RSpec test runner |
| [Debugger](#debugger) | Interactive breakpoint debugger |

---

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

| Type | Source |
|------|--------|
| N+1 query patterns | Runtime detection |
| Slow queries | Grouped by source location |
| Slow requests | Grouped by controller#action |
| Error patterns | Grouped by exception class and location |
| Code smells | Static analysis |

**Ignored issues:** Click the ignore button on any issue to hide it. Switch to the "Ignored" tab to see and restore ignored issues.

---

### Queries

![Queries](screenshots/queries.png)

Lists individual slow SQL queries ordered by most recent.

| Column | Description |
|--------|-------------|
| SQL text | Truncated, expandable |
| Duration | Milliseconds |
| Source | File and line |
| N+1 indicator | With count |
| Timestamp | When recorded |

**Filtering:** Toggle "N+1 only" to show only N+1 pattern queries.

**Detail drawer:** Click any query to open a side drawer showing full SQL text, duration and timing, source location with code context, and request ID (links to associated request).

---

### Requests

![Requests](screenshots/requests.png)

Lists individual slow HTTP requests ordered by most recent.

| Column | Description |
|--------|-------------|
| HTTP method and path | Request target |
| Status code | Response status |
| Total duration | Milliseconds |
| View render time | Template rendering |
| Database time | SQL execution |
| Controller#action | Which action handled it |

**Detail drawer:** Click any request to see full request details and params, breakdown (total, view, DB time), associated queries, and associated errors.

---

### Errors

Lists captured exceptions ordered by most recent.

| Column | Description |
|--------|-------------|
| Exception class | e.g., `ActiveRecord::RecordNotFound` |
| Message | Truncated |
| Source | File and line |
| HTTP method and path | Request context |
| Timestamp | When recorded |

**Detail drawer:** Click any error to see full exception message, backtrace, HTTP context (method, path, params), and source code at the error location.

---

### Jobs

![Jobs](screenshots/jobs.png)

Monitors background job executions captured via the ActiveJob subscriber.

| Column | Description |
|--------|-------------|
| Job class | e.g., `SendEmailJob` |
| Queue name | Which queue processed it |
| Duration | Milliseconds |
| Timestamp | When recorded |

**Detail drawer:** Click any job to see job class, queue, arguments, duration, timestamps, and associated queries.

---

### Tests

![Tests](screenshots/tests.png)

Browser-based RSpec test runner.

**Spec file tree:**
- Folder and file hierarchy mirroring your `spec/` directory
- Category badges (MODEL, CTRL, JOB, etc.) on each spec file
- Expand a file to see its describe/context/it groups as a nested tree
- Dry-run discovery: expanding a file fetches examples via `rspec --dry-run` without executing them

**Running specs:**
- **Run All** button to run the entire suite
- Play button on any folder, file, context group, or individual example
- Pass/fail dot indicators at every level (file, group, example)
- Auto-expand files with results after a run completes

**Results drawer:**

| Tab | Shows |
|-----|-------|
| Results | Hierarchical pass/fail breakdown per file, with describe/context nesting |
| Console | Full RSpec output with ANSI color rendering (green dots, red F, colored diffs) |

Summary bar: total, passed, failed, pending counts and duration.

**Integration:**
- View Source button opens a side drawer showing the file at the exact line
- Open in Editor button from the drawer to jump to your editor
- Open in Debugger button to set a breakpoint at that line

**Persistence:** Expanded/collapsed folder and file state persists across page reloads via LocalStorage.

---

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

---

## Source Code Viewer

Available throughout the dashboard wherever a source location is shown. Opens as a side drawer displaying:
- Line numbers
- Highlighted current line
- Surrounding context (50 lines above and below by default, configurable via `radius` parameter)
- Syntax-highlighted Ruby code

---

## Open in Editor

A button appears next to every source location. Clicking it opens the file at the exact line in your configured editor. See [Editor Integration](editor-integration.md) for setup.

---

## Pagination

All list pages (Queries, Requests, Errors, Jobs) are paginated with 25 items per page. Navigation controls appear at the bottom of each list.
