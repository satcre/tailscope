# Editor Integration

Tailscope can open source files at the exact line in your editor with one click. This works from any source location shown in the dashboard -- issues, queries, requests, errors, and the debugger.

---

## Supported Editors

| Editor | Config Symbol | Command |
|--------|--------------|---------|
| Visual Studio Code | `:vscode` | `code -r -g {file}:{line} {project}` |
| Sublime Text | `:sublime` | `subl {project} {file}:{line}` |
| RubyMine | `:rubymine` | `mine {project} --line {line} {file}` |
| Neovim (Terminal.app) | `:nvim_terminal` | `nvim +{line} {file}` |
| Neovim (iTerm2) | `:nvim_iterm` | `nvim +{line} {file}` |

---

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

---

## Auto-Detection

If no editor is configured, Tailscope tries to detect one:

1. Checks the `$EDITOR` environment variable and maps it to a known editor
2. Scans `$PATH` for known editor binaries: `code`, `subl`, `mine`, `nvim`
3. Uses the first one found

The detection happens at runtime, so setting `$EDITOR` in your shell profile works.

---

## macOS App Bundle Resolution

On macOS, editor CLIs (like `code` for VS Code) may not be in the Rails server's `$PATH`, especially when the server is started from an IDE or process manager rather than a terminal.

Tailscope handles this by resolving the full binary path inside the `.app` bundle:

| Editor | Full Path |
|--------|-----------|
| VS Code | `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code` |
| Sublime Text | `/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl` |
| RubyMine | `/Applications/RubyMine.app/Contents/MacOS/rubymine` |

Both `/Applications/` and `~/Applications/` are checked. This resolution happens automatically for preset editor symbols.

---

## Terminal Editors

Terminal editors (Neovim) require special handling since they need to open in a terminal window.

| Platform | Config | Behavior |
|----------|--------|----------|
| macOS + Terminal.app | `:nvim_terminal` | Opens a new Terminal window via AppleScript |
| macOS + iTerm2 | `:nvim_iterm` | Creates a new iTerm2 session via AppleScript |
| Linux | `:nvim_terminal` | Uses `x-terminal-emulator` to open a new terminal |

---

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

---

## Dashboard Editor Selector

The dashboard includes an editor dropdown that lets you switch editors at runtime without changing the server configuration. The selection is stored in the browser's local storage.

---

## Checking Editor Availability

When you select an editor in the dashboard, it calls `/api/editor/check` to verify the editor binary is available on the server. If not found, you'll see a warning.

---

## Security

- Only files within `config.source_root` can be opened
- Paths are validated server-side before launching the editor
- Files must exist on disk
- All arguments are shell-escaped to prevent command injection

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "No editor configured" error | Set `config.editor` in the initializer, or ensure `$EDITOR` is set |
| Editor opens but wrong file/line | Check that custom command uses `{file}`, `{line}`, `{project}` placeholders |
| VS Code opens but doesn't navigate (macOS) | Tailscope resolves this automatically for preset editors. For custom commands, use the full path: `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code` |
| Nothing happens on click | Check browser console for network errors. Verify the editor binary exists: `which code` |
