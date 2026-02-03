# Interactive Debugger

Tailscope includes a browser-based debugger that lets you set breakpoints, pause execution, inspect variables, evaluate expressions, and step through Ruby code -- all from the web dashboard.

![Debugger](screenshots/debugger.png)

---

## Enabling the Debugger

The debugger is disabled by default because it uses Ruby's `TracePoint` API, which adds overhead to every line of Ruby executed.

```ruby
Tailscope.configure do |config|
  config.debugger_enabled = true
  config.debugger_timeout = 60  # seconds before auto-continue
end
```

Restart your Rails server after changing this setting.

---

## Setting Breakpoints

1. Open the **Debugger** page in the dashboard
2. Use the **file browser** to navigate your source code
3. Click the **line number gutter** to toggle a breakpoint
4. The breakpoint appears in the breakpoints panel

Breakpoints persist across server restarts (stored in the SQLite database).

### Conditional Breakpoints

Set a condition that must evaluate to `true` for the breakpoint to pause:

1. Set a breakpoint as above
2. Enter a Ruby expression in the condition field (e.g., `user.id == 42` or `params[:debug]`)
3. The expression is evaluated in the binding at the breakpoint location
4. Execution only pauses when the condition returns a truthy value

---

## Debugging a Paused Session

When code hits a breakpoint, the request thread pauses and a debug session appears in the dashboard.

### Session Panel

| Section | Shows |
|---------|-------|
| File and line | Where execution paused |
| Source code | Current line highlighted with surrounding context |
| Local variables | Names and current values |
| Call stack | First 20 frames |

### Expression Evaluator

Type any Ruby expression to run it in the paused execution context:

```ruby
user.email                     # inspect a variable
User.count                     # run a query
params[:id].to_i               # check request params
local_variables                # list all locals
binding.local_variable_get(:x) # alternative variable access
```

Expressions are evaluated using `binding.eval()` in the exact scope where execution paused.

### Stepping Controls

| Button | Behavior |
|--------|----------|
| **Continue** | Resume execution until the next breakpoint |
| **Step Into** | Execute one line, stepping into method calls |
| **Step Over** | Execute one line, staying at current call depth |
| **Step Out** | Continue until the current method returns |

**Step Into** pauses on the very next line of Ruby executed, even if it's inside a called method.

**Step Over** pauses on the next line at the same call depth. If the current line calls a method, it runs to completion before pausing.

**Step Out** continues execution until the call depth decreases (the current method returns), then pauses on the line after the call.

---

## How It Works

### Architecture

| Component | Role |
|-----------|------|
| **BreakpointManager** | Stores breakpoints in SQLite, provides thread-safe access |
| **TraceHook** | Registers a Ruby `TracePoint` for `:line`, `:call`, and `:return` events |
| **Session** | Represents one paused execution, holds the Ruby `Binding` object |
| **SessionStore** | In-memory store of active and recent sessions |

### Execution Flow

```
1. TracePoint fires on :line event
2. TraceHook checks if a breakpoint exists at this file:line
3. If conditional, evaluates condition in the binding
4. Creates a Session with the binding, locals, and call stack
5. Session.wait! blocks the request thread (ConditionVariable)
6. Dashboard polls /api/debugger/poll, sees the active session
7. User clicks "Step Into" -> API calls session.step_into!
8. Session.signal! wakes the blocked thread
9. TraceHook enters stepping mode
10. Next :line event at correct depth -> creates new Session -> repeat
```

### TracePoint Events

| Event | Purpose |
|-------|---------|
| `:line` | Fires before each line of Ruby -- where breakpoint checks happen |
| `:call` | Fires when entering a method -- tracks call depth for step over/out |
| `:return` | Fires when leaving a method -- tracks call depth |

### Path Filtering

The debugger ignores events from:
- Tailscope's own code
- Gems (paths containing `/gems/`)
- Ruby internals (`<internal:`)
- Bundler paths (`/vendor/bundle/`)

---

## Session Timeout

If no user interaction occurs within `debugger_timeout` seconds (default: 60), the session automatically continues. This prevents a forgotten breakpoint from blocking your server indefinitely.

---

## Session Cleanup

Old sessions (non-paused, older than 5 minutes) are automatically cleaned up to prevent memory growth.

---

## Security

- Breakpoints can only be set on files within `config.source_root`
- Expression evaluation runs arbitrary Ruby code -- development only
- The debugger should never be enabled in production
- File browsing is restricted to `source_root`

---

## Performance Impact

| State | Overhead |
|-------|----------|
| `debugger_enabled = false` | Zero |
| Enabled, no breakpoints | Zero (TracePoint not registered) |
| Enabled, with breakpoints | 5-20% (TracePoint on every line) |

The TracePoint is only registered when at least one breakpoint exists or when stepping mode is active. If all breakpoints are removed, the TracePoint is disabled automatically.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Breakpoint doesn't pause | Verify `config.debugger_enabled = true` and restart server. Check file path matches (no symlinks). Ensure line contains executable Ruby. |
| Session times out too quickly | Increase `config.debugger_timeout` |
| Server feels slow with debugger on | Expected. Disable `debugger_enabled` when not actively debugging. |
