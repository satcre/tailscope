# frozen_string_literal: true

module Tailscope
  module Api
    class EditorController < ApiController
      def open
        file = params[:file].to_s.strip
        line = (params[:line] || 1).to_i
        source_root = Tailscope.configuration.source_root

        # Resolve relative paths against source root
        unless file.start_with?("/")
          file = File.join(source_root, file)
        end

        unless file.start_with?(source_root)
          return render(json: { error: "Forbidden" }, status: :forbidden)
        end

        unless File.exist?(file)
          return render(json: { error: "File not found" }, status: :not_found)
        end

        editor_key = params[:editor].to_s.strip
        editor_sym = editor_key.present? ? editor_key.to_sym : nil

        command_template = if editor_sym && Configuration::EDITOR_COMMANDS[editor_sym]
          Configuration::EDITOR_COMMANDS[editor_sym]
        else
          Tailscope.configuration.resolve_editor
        end

        unless command_template
          return render(json: { error: "No editor configured. Select an editor from the dropdown in the nav bar." }, status: :unprocessable_entity)
        end

        escaped_file = Shellwords.escape(file)
        escaped_project = Shellwords.escape(source_root)

        # On macOS, resolve full path to CLI binary inside .app bundle
        # since CLI tools (code, subl, mine) are often not in the server process PATH
        resolved_template = command_template
        if Configuration.mac? && editor_sym
          mac_binary = Configuration.mac_cli_path(editor_sym)
          if mac_binary
            short_binary = Configuration::EDITOR_BINARIES[editor_sym]
            resolved_template = command_template.sub(short_binary, Shellwords.escape(mac_binary))
          end
        end

        base_command = resolved_template
          .gsub("{project}", escaped_project)
          .gsub("{file}", escaped_file)
          .gsub("{line}", line.to_s)

        begin
          launch_editor(editor_sym, base_command, source_root)
        rescue Errno::ENOENT
          return render(json: { error: "Editor command not found. Make sure the editor is installed and in your PATH." }, status: :unprocessable_entity)
        end

        render json: { ok: true, editor: editor_key.presence || Tailscope.configuration.editor_name }
      end

      def check
        editor_key = params[:editor].to_s.strip
        editor_sym = editor_key.present? ? editor_key.to_sym : nil

        unless editor_sym && Configuration::EDITOR_COMMANDS[editor_sym]
          return render(json: { available: false, error: "Unknown editor" }, status: :unprocessable_entity)
        end

        binary = Configuration::EDITOR_BINARIES[editor_sym]
        binary_found = binary && system("which #{Shellwords.escape(binary)} > /dev/null 2>&1")

        terminal_app = Configuration::TERMINAL_WRAPPERS[editor_sym]
        if terminal_app
          unless binary_found
            return render(json: { available: false, error: "Neovim is not installed" }, status: :unprocessable_entity)
          end

          if editor_sym == :nvim_terminal
            if Configuration.mac? || Configuration.linux?
              return render(json: { available: true, editor: editor_key })
            else
              return render(json: { available: false, error: "Not supported on this platform" }, status: :unprocessable_entity)
            end
          end

          if editor_sym == :nvim_iterm
            if Configuration.mac? && Configuration.mac_app_installed?(:nvim_iterm)
              return render(json: { available: true, editor: editor_key })
            else
              return render(json: { available: false, error: "iTerm2 is not installed" }, status: :unprocessable_entity)
            end
          end
        end

        if binary_found
          return render(json: { available: true, editor: editor_key })
        end

        if Configuration.mac? && Configuration.mac_app_installed?(editor_sym)
          return render(json: { available: true, editor: editor_key, via: "mac_app" })
        end

        label = EDITOR_LABELS[editor_sym] || editor_key
        render json: { available: false, error: "#{label} is not installed" }, status: :unprocessable_entity
      end

      private

      def launch_editor(editor_sym, base_command, source_root)
        terminal_app = editor_sym && Configuration::TERMINAL_WRAPPERS[editor_sym]
        escaped_project = Shellwords.escape(source_root)

        if terminal_app && Configuration.mac?
          launch_mac_terminal(terminal_app, base_command, escaped_project)
        elsif terminal_app && Configuration.linux?
          pid = spawn("x-terminal-emulator", "-e", "bash", "-c", "cd #{escaped_project} && #{base_command}", [:out, :err] => "/dev/null")
          Process.detach(pid)
        else
          pid = spawn(base_command, [:out, :err] => "/dev/null")
          Process.detach(pid)
        end
      end

      def launch_mac_terminal(terminal_app, nvim_cmd, escaped_project)
        shell_cmd = "cd #{escaped_project} && #{nvim_cmd}"

        if terminal_app == "iTerm"
          # iTerm2: create window then write command into the session
          script = <<~APPLESCRIPT
            tell application "iTerm2"
              create window with default profile
              tell current session of current window
                write text "#{shell_cmd}"
              end tell
            end tell
            tell application "iTerm2" to activate
          APPLESCRIPT
          pid = spawn("osascript", "-e", script, [:out, :err] => "/dev/null")
          Process.detach(pid)
        else
          # Terminal.app: do script runs the text in a new window's shell
          script = <<~APPLESCRIPT
            tell application "Terminal"
              do script "#{shell_cmd}"
              activate
            end tell
          APPLESCRIPT
          pid = spawn("osascript", "-e", script, [:out, :err] => "/dev/null")
          Process.detach(pid)
        end
      end

      EDITOR_LABELS = {
        vscode: "VS Code",
        sublime: "Sublime Text",
        rubymine: "RubyMine",
        nvim_terminal: "Neovim (Terminal)",
        nvim_iterm: "Neovim (iTerm)",
      }.freeze
    end
  end
end
