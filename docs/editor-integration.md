# Editor Integration

Tailscope can open source files at the exact line in your editor with one click. This works from any source location shown in the dashboard -- issues, queries, requests, errors, and the debugger.

## Supported Editors

| Editor | Config Symbol | Command |
|--------|--------------|---------|
| Visual Studio Code | `:vscode` | `code -r -g {file}:{line} {project}` |
| Sublime Text | `:sublime` | `subl {project} {file}:{line}` |
| RubyMine | `:rubymine` | `mine {project} --line {line} {file}` |
| Neovim (Terminal.app) | `:nvim_terminal` | `nvim +{line} {file}` |
| Neovim (iTerm2) | `:nvim_iterm` | `nvim +{line} {file}` |

## Configuration

Set your editor in the initializer:

```ruby
Tailscope.configure do |config|
  config.editor = :vscode
end
```

Or use a custom command string with placeholders:

```ruby
config.editor = "emacs +{line} {file}"
```

### Placeholders

| Placeholder | Value |
|-------------|-------|
| `{file}` | Absolute path to the source file |
| `{line}` | Line number |
| `{project}` | `config.source_root` (your Rails root) |

All paths are shell-escaped automatically.

## Auto-Detection

If no editor is configured, Tailscope tries to detect one:

1. Checks the `$EDITOR` environment variable and maps it to a known editor
2. Scans `$PATH` for known editor binaries: `code`, `subl`, `mine`, `nvim`
3. Uses the first one found

The detection happens at runtime, so setting `$EDITOR` in your shell profile works.

## macOS App Bundle Resolution

On macOS, editor CLIs (like `code` for VS Code) may not be in the Rails server's `$PATH`, especially when the server is started from an IDE or process manager rather than a terminal.

Tailscope handles this by resolving the full binary path inside the `.app` bundle:

| Editor | Full Path |
|--------|-----------|
| VS Code | `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code` |
| Sublime Text | `/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl` |
| RubyMine | `/Applications/RubyMine.app/Contents/MacOS/rubymine` |

Both `/Applications/` and `~/Applications/` are checked.

This resolution happens automatically when using a preset editor symbol. No configuration needed.

## Terminal Editors

Terminal editors (Neovim) require special handling since they need to open in a terminal window.

**macOS with Terminal.app** (`:nvim_terminal`):
- Uses AppleScript to open a new Terminal window and run the command

**macOS with iTerm2** (`:nvim_iterm`):
- Uses AppleScript to create a new iTerm2 session

**Linux** (`:nvim_terminal`):
- Uses `x-terminal-emulator` to open a new terminal window

## Custom Command Examples

```ruby
# Emacs
config.editor = "emacsclient -n +{line} {file}"

# Vim in a new tmux pane
config.editor = "tmux split-window 'vim +{line} {file}'"

# TextMate
config.editor = "mate -l {line} {file}"

# Cursor (VS Code fork)
config.editor = "cursor -r -g {file}:{line} {project}"
```

## Dashboard Editor Selector

The dashboard includes an editor dropdown that lets you switch editors at runtime without changing the server configuration. The selection is stored in the browser's local storage.

## Checking Editor Availability

The dashboard has an editor check feature. When you select an editor, it calls the `/api/editor/check` endpoint to verify the editor binary is available on the server. If not found, you'll see a warning.

## Security

- Only files within `config.source_root` can be opened
- Paths are validated server-side before launching the editor
- Files must exist on disk
- All arguments are shell-escaped to prevent command injection

## Troubleshooting

**"No editor configured" error:**
- Set `config.editor` in the initializer, or ensure `$EDITOR` is set in the server's environment

**Editor opens but wrong file/line:**
- Check that your custom command uses the correct placeholder syntax: `{file}`, `{line}`, `{project}`

**VS Code opens but doesn't navigate to the file (macOS):**
- This usually means the `code` CLI isn't in the server's `$PATH`. Tailscope resolves this automatically for preset editors. If using a custom command, use the full path:
  ```ruby
  config.editor = "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code -r -g {file}:{line} {project}"
  ```

**Nothing happens when clicking "Open in Editor":**
- Check the browser console for network errors
- Verify the editor binary exists: `which code` (or `which subl`, etc.)
- On macOS, check both `/Applications/` and `~/Applications/`
