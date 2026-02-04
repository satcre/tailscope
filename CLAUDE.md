# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Tailscope** is a Rails development profiler and debugger gem that captures slow queries, N+1 patterns, slow requests, runtime errors, and code smells. It provides a web dashboard with source-level detail, suggested fixes, and one-click editor integration.

- **Type**: Ruby gem (Rails Engine)
- **Stack**: Ruby >= 3.0, Rails >= 6.0, SQLite3, React (Vite frontend)
- **Status**: Early stage, development use only

## Commands

### Installation

**Post-install message**: After `bundle install` or `bundle update tailscope`, Bundler displays a message (defined in `tailscope.gemspec`) reminding users to run the generator.

When Tailscope is installed in a Rails app via `rails generate tailscope:install`, the generator:
1. Creates initializer at `config/initializers/tailscope.rb`
2. Mounts the engine at `/tailscope` in routes
3. **Automatically runs `npm install` in the gem's client directory** to install frontend dependencies

The install generator is at `lib/generators/tailscope/install_generator.rb`.

**After updating the gem** with `bundle update tailscope`, re-run the generator to update frontend dependencies:
```bash
bundle update tailscope
rails generate tailscope:install  # Post-install message reminds users
```

The generator is idempotent and safe to re-run.

### Running Tests

```bash
# Full test suite
bundle exec rspec

# Single spec file
bundle exec rspec spec/path/to/file_spec.rb

# Specific example (by line number)
bundle exec rspec spec/path/to/file_spec.rb:42

# Run with N+1 query detection filter
bundle exec rspec --tag n_plus_one

# Default rake task runs full test suite
bundle exec rake
```

**CRITICAL**: Always use `bundle exec rspec` (never just `rspec`). Tests are configured with:
- `--format documentation` for verbose output
- `$stdout.sync = true` for real-time test feedback (no buffering)
- `config.example_status_persistence_file_path = "spec/examples.txt"` to track failed specs

### Mutation Testing

```bash
# Run mutation testing with Mutant
bundle exec mutant run
```

Configuration in `.mutant.yml` covers core modules: Configuration, Storage, Database, SourceLocator, Detectors, Middleware, and Subscribers.

### Frontend Development

The `client/` directory contains a React + Vite SPA:

```bash
cd client
npm run dev      # Development server
npm run build    # Production build (outputs to public/)
npm run preview  # Preview production build
```

Built assets are served from `public/` by the Rails engine.

### CLI Commands

The gem includes a Thor-based CLI:

```bash
bin/tailscope queries           # List slow queries
bin/tailscope queries -n        # Show only N+1 queries
bin/tailscope requests          # List slow requests
bin/tailscope errors            # List errors
bin/tailscope jobs              # List background jobs
bin/tailscope stats             # Show statistics
bin/tailscope tail              # Live tail mode
```

## Architecture

### High-Level Data Flow

```
Request → Middleware (RequestTracker)
       → ActiveSupport Subscribers (SQL, Action, Job, etc.)
       → Instrumentors (NetHTTP, Callbacks, ActiveJob)
       → N+1 Detector (per-request analysis)
       → Storage (async SizedQueue → background writer thread)
       → SQLite Database (WAL mode)
       → Web Dashboard / CLI (read)
```

### Core Components

#### 1. Middleware & Request Tracking

- **`Middleware::RequestTracker`**: Rack middleware that wraps each request, tracks timing, captures exceptions, and runs N+1 analysis
- Uses `Thread.current[:tailscope_request_id]` to correlate queries/errors within a single request
- Maintains `Thread.current[:tailscope_query_log]` array for per-request N+1 detection

#### 2. ActiveSupport Subscribers

Located in `lib/tailscope/subscribers/`:
- **`SqlSubscriber`**: Subscribes to `sql.active_record`, captures query timing and source location
- **`ActionSubscriber`**: Subscribes to `process_action.action_controller`, tracks request duration and metadata
- **`JobSubscriber`**: Subscribes to ActiveJob lifecycle events
- **`HttpSubscriber`**: Tracks external HTTP calls (via Net::HTTP instrumentation)
- **`CacheSubscriber`**, **`MailerSubscriber`**, **`ViewSubscriber`**, **`ControllerSubscriber`**: Additional instrumentation points

All subscribers call `SourceLocator.locate(caller_locations)` to find the relevant source file/line/method from the Ruby call stack.

#### 3. Storage Layer

- **`Storage`**: Manages async writes via a `SizedQueue` (1000 items) and background writer thread
- **`Database`**: Establishes SQLite connection with WAL mode, synchronous=NORMAL, busy_timeout=5000ms
- **`Schema`**: Creates tables on initialization (`tailscope_queries`, `tailscope_requests`, `tailscope_errors`, `tailscope_jobs`, `tailscope_services`, `tailscope_breakpoints`, `tailscope_ignored_issues`)

**Key Pattern**: All writes go through `Storage.enqueue([:type, attrs])` → background thread → SQLite. This avoids blocking request processing.

#### 4. N+1 Detection

- **`Detectors::NPlusOne`**: Groups queries by normalized SQL + call site, flags patterns exceeding threshold
- Normalizes SQL by replacing literals with `?` placeholders to detect identical query patterns
- Runs at end of each request in `RequestTracker` middleware

#### 5. Web Dashboard

- **Rails Engine**: Mounts at `/tailscope` route
- **API Controllers**: `app/controllers/tailscope/api/*_controller.rb` provide JSON endpoints
- **Frontend**: React SPA built with Vite, served from `public/app.js` and `public/app.css`
- **Features**: Issues dashboard, queries, requests, errors, jobs, test runner, interactive debugger

#### 6. Debugger

- **`Debugger`**: Interactive breakpoint debugger with TracePoint-based stepping
- **`Debugger::Session`**: Manages debug session state (breakpoints, variables, stack frames)
- **`Debugger::BreakpointManager`**: CRUD for breakpoints stored in SQLite
- **`Debugger::TraceHook`**: Uses TracePoint to intercept code execution

#### 7. Test Runner

- **`TestRunner`**: Discovers and runs RSpec specs from the browser
- Parses spec files to extract describe/context/it blocks for tree navigation
- **Streams output in real-time** using non-blocking I/O (read_nonblock) to show immediate feedback
- Runs RSpec with both `--format json` (for structured data) and `--format documentation` (for human-readable output)
- Supports filtering by failed specs via `status(filter: 'failed')` and dedicated `failed_examples` method
- Captures coverage data from SimpleCov's `.resultset.json` after test completion

#### 8. Code Analysis

- **`CodeAnalyzer`**: Static analysis detects code smells (fat models, missing validations, hardcoded secrets, etc.)
- **`IssueBuilder`**: Aggregates data into actionable issues with severity, fingerprints, and suggested fixes
- **Code smells are generated on-demand**: They are NOT stored in the database - analyzed fresh from source code on every API call
- **Rescan button**: Issues page includes a "Rescan Code" button to trigger fresh code smell analysis

## Testing Patterns

### Dummy Rails App

Tests use a minimal Rails app in `spec/dummy/` to simulate real Rails environment. Initialized in `spec/spec_helper.rb`:

```ruby
Dummy::Application.initialize! unless Dummy::Application.initialized?
```

### Test Isolation

Each test gets a fresh SQLite database:

```ruby
config.before(:suite) do
  Tailscope.configuration.database_path = File.join(Dir.tmpdir, "tailscope_test_#{$$}.sqlite3")
  Tailscope.configuration.enabled = false
end

config.before(:each) do
  Tailscope::Database.reset!
  Tailscope::Schema.create_tables!
  # Clean all tables
end
```

### Configuration

Use `Tailscope.configuration` to set thresholds:

- `slow_query_threshold_ms`: Default 100ms
- `slow_request_threshold_ms`: Default 500ms
- `n_plus_one_threshold`: Default 3 identical queries
- `storage_retention_days`: Default 7 days
- `database_path`: SQLite DB location
- `debugger_enabled`: Default false

## Gem Packaging

### Files Included in Gem

The gemspec (`tailscope.gemspec`) includes:
- `app/`, `config/`, `lib/`, `bin/` - Ruby code and Rails engine files
- `public/` - Pre-built frontend assets (`app.js`, `app.css`)
- `client/` - Frontend source code (React + Vite)
  - **EXCLUDES** `client/node_modules/` from the gem package (installed at runtime)

### .gitignore

The `.gitignore` file excludes:
- `client/node_modules/` and `client/package-lock.json`
- Test coverage files (`coverage/`, `.resultset.json`)
- SQLite databases (`*.sqlite3`)
- Logs and temporary files
- RSpec status file (`spec/examples.txt`)

### Build Process

1. **Development**: Run `cd client && npm run build` to rebuild frontend assets
2. **Gem installation**: The install generator automatically runs `npm install` in the gem's `client/` directory
3. **Pre-built assets**: The `public/tailscope/` directory contains compiled JS/CSS served by the Rails engine

## Important Guidelines

### Testing Rules

1. **ALWAYS** use `bundle exec rspec` (never bare `rspec`)
2. **NEVER** remove or change working test expectations—fix the implementation instead
3. If a test fails, investigate WHY and fix the root cause
4. Maintain 100% test coverage for new code
5. Tests run with `RAILS_ENV=test` (set in spec_helper)

### Code Patterns

1. **Source Location Tracking**: Always use `SourceLocator.locate(caller_locations)` to find the relevant app code (skips gem/framework code)
2. **Thread-Local State**: Request-scoped data uses `Thread.current[:tailscope_*]` keys
3. **Async Writes**: All database writes go through `Storage.enqueue` to avoid blocking
4. **SQL Normalization**: N+1 detector normalizes SQL by replacing literals with `?`
5. **Editor Integration**: `Configuration::EDITOR_COMMANDS` maps editor symbols to CLI commands with `{file}`, `{line}`, `{project}` placeholders

### Architectural Constraints

1. **No Application Code Changes**: Tailscope must work as a drop-in gem without modifying host app code
2. **Minimal Performance Impact**: Async writes, background threads, and selective instrumentation
3. **Development Only**: Not intended for production use (early stage)
4. **Rails Engine Isolation**: Uses `isolate_namespace Tailscope` to avoid conflicts

## File Organization

```
lib/tailscope/
  configuration.rb          # All config options and editor detection
  database.rb               # SQLite connection management
  storage.rb                # Async write queue and query methods
  schema.rb                 # Database schema definitions
  source_locator.rb         # Finds relevant source from call stack
  issue_builder.rb          # Aggregates issues from data
  code_analyzer.rb          # Static analysis for code smells
  test_runner.rb            # RSpec integration
  cli.rb                    # Thor-based CLI

  middleware/
    request_tracker.rb      # Rack middleware for timing/errors

  subscribers/              # ActiveSupport::Notifications subscribers
    sql_subscriber.rb
    action_subscriber.rb
    job_subscriber.rb
    [etc.]

  instrumentors/            # Monkey patches for instrumentation
    net_http.rb
    callbacks.rb
    active_job.rb

  detectors/
    n_plus_one.rb           # N+1 query detection logic

  debugger/
    session.rb
    breakpoint_manager.rb
    trace_hook.rb

app/controllers/tailscope/
  api/                      # JSON API endpoints
    queries_controller.rb
    requests_controller.rb
    errors_controller.rb
    issues_controller.rb
    tests_controller.rb
    debugger_controller.rb
    [etc.]

client/                     # React + Vite frontend
  src/
    pages/                  # Dashboard pages
    components/             # React components
  vite.config.js
  package.json

spec/
  controllers/              # API controller specs
  tailscope/                # Unit specs for lib classes
  dummy/                    # Minimal Rails app for testing
  spec_helper.rb            # RSpec configuration
  mutant_boot.rb            # Mutant setup
```

## API Endpoints

### Test Runner API

- `GET /api/tests/specs` - Discover all spec files in tree structure
- `GET /api/tests/examples?target=spec/path` - Dry-run to extract examples from specific spec
- `POST /api/tests/run` - Start test run (params: `target` for specific spec or nil for all)
- `GET /api/tests/status` - Poll for current run status and output
- `GET /api/tests/status?filter=failed` - Get status with only failed examples
- `GET /api/tests/failed` - Get only failed examples from current run
- `POST /api/tests/cancel` - Kill running test process
- `GET /api/tests/coverage` - Get SimpleCov coverage data from last run

The status endpoint should be polled during test runs to get real-time output updates. The `console_output` field is updated incrementally as tests execute.

## Key Implementation Details

### Query Source Location

`SourceLocator.locate(caller_locations)` walks the Ruby call stack and returns the first frame outside of:
- Rails framework code
- Active Record internals
- Tailscope itself

This ensures captured queries point to actual application code, not ORM internals.

### Request Correlation

Each request gets a unique `request_id` (from `action_dispatch.request_id` or generated). All queries, errors, and services within that request are tagged with the same ID for correlation in the dashboard.

### N+1 Detection Algorithm

1. During request, `SqlSubscriber` appends each query to `Thread.current[:tailscope_query_log]`
2. At request end, `Detectors::NPlusOne.analyze!` groups queries by:
   - Normalized SQL (literals replaced with `?`)
   - Call site (file:line)
3. Any group with ≥ threshold (default 3) is flagged as N+1

### Test Runner Real-Time Streaming

The test runner provides real-time feedback using non-blocking I/O:

1. Spawns RSpec with `Process.spawn`, capturing stdout/stderr to a pipe
2. Background thread reads from pipe using `read_nonblock(4096)` in a loop
3. Each chunk is appended to `console_output` and stored in `@current_run[:console_output]` (no truncation - full output preserved)
4. Frontend polls `/api/tests/status` to get incremental updates
5. Main thread waits for process completion with `Process.wait(pid)`, then joins reader thread
6. After completion, parses JSON output for structured data (summary, examples, failures)

This approach avoids blocking on `IO.read` until completion, allowing dashboard to show test progress as it happens. All output is preserved without character limits.

### Editor Integration

`Configuration#resolve_editor` detects installed editors by:
1. Checking `ENV["EDITOR"]`
2. Using `which` to find known binaries (`code`, `subl`, `mine`, `nvim`)
3. On macOS, checking `/Applications/*.app` paths
4. Falling back to custom command if set explicitly

Commands use placeholders: `{file}`, `{line}`, `{project}` replaced at runtime.

## Common Workflows

### Adding a New Detector

1. Create `lib/tailscope/detectors/my_detector.rb`
2. Implement `.analyze!(request_id)` class method
3. Call from `Middleware::RequestTracker` after request completes
4. Write specs in `spec/tailscope/detectors/my_detector_spec.rb`

### Adding a New Dashboard Page

1. Add API controller in `app/controllers/tailscope/api/`
2. Add route in `config/routes.rb`
3. Create React page in `client/src/pages/`
4. Add navigation link in `client/src/components/Nav.jsx`
5. Run `cd client && npm run build` to compile assets
6. Test via `/tailscope` in browser

### Adding a New Configuration Option

1. Add `attr_accessor` in `Configuration` class
2. Set default value in `#initialize`
3. Document in `docs/configuration.md`
4. Add specs in `spec/tailscope/configuration_spec.rb`
