# frozen_string_literal: true

module Tailscope
  class Configuration
    attr_accessor :enabled,
                  :slow_query_threshold_ms,
                  :slow_request_threshold_ms,
                  :n_plus_one_threshold,
                  :storage_retention_days,
                  :database_path,
                  :source_root,
                  :debugger_enabled,
                  :debugger_timeout,
                  :editor

    EDITOR_COMMANDS = {
      vscode: "code -g {file}:{line}",
      sublime: "subl {project} {file}:{line}",
      rubymine: "mine {project} --line {line} {file}",
      nvim_terminal: "nvim +{line} {file}",
      nvim_iterm: "nvim +{line} {file}",
    }.freeze

    # GUI editors that should open the project folder first
    PROJECT_EDITORS = Set[:vscode].freeze

    MAC_FALLBACK_COMMANDS = {
      vscode: 'open -a "Visual Studio Code" --args {project} -g {file}:{line}',
      sublime: 'open -a "Sublime Text" --args {project} {file}:{line}',
      rubymine: 'open -a "RubyMine" --args {project} --line {line} {file}',
    }.freeze

    # Maps terminal editor keys to their terminal app
    TERMINAL_WRAPPERS = {
      nvim_terminal: "Terminal",
      nvim_iterm: "iTerm",
    }.freeze

    EDITOR_EXECUTABLES = {
      "code" => :vscode,
      "subl" => :sublime,
      "mine" => :rubymine,
      "nvim" => :nvim_terminal,
    }.freeze

    EDITOR_BINARIES = {
      vscode: "code",
      sublime: "subl",
      rubymine: "mine",
      nvim_terminal: "nvim",
      nvim_iterm: "nvim",
    }.freeze

    MAC_APP_PATHS = {
      vscode: ["Visual Studio Code.app"],
      sublime: ["Sublime Text.app"],
      rubymine: ["RubyMine.app"],
      nvim_iterm: ["iTerm.app"],
    }.freeze

    def self.mac?
      RUBY_PLATFORM.include?("darwin")
    end

    def self.linux?
      RUBY_PLATFORM.include?("linux")
    end

    def self.windows?
      RUBY_PLATFORM =~ /mswin|mingw|cygwin/
    end

    def self.mac_app_installed?(editor_sym)
      paths = MAC_APP_PATHS[editor_sym]
      return false unless paths

      paths.any? do |app|
        File.directory?("/Applications/#{app}") ||
          File.directory?(File.join(Dir.home, "Applications", app))
      end
    end

    def initialize
      @enabled = defined?(Rails) ? Rails.env.development? : true
      @slow_query_threshold_ms = 100
      @slow_request_threshold_ms = 500
      @n_plus_one_threshold = 3
      @storage_retention_days = 7
      @database_path = defined?(Rails) ? Rails.root.join("db", "tailscope.sqlite3").to_s : "db/tailscope.sqlite3"
      @source_root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
      @debugger_enabled = false
      @debugger_timeout = 60
      @editor = nil
    end

    def resolve_editor
      return EDITOR_COMMANDS[@editor] if @editor.is_a?(Symbol) && EDITOR_COMMANDS[@editor]
      return @editor if @editor.is_a?(String)
      detect_editor
    end

    def editor_name
      return @editor.to_s if @editor.is_a?(Symbol) && EDITOR_COMMANDS[@editor]
      return "custom" if @editor.is_a?(String)
      detected = detect_editor_name
      detected || "none"
    end

    private

    def detect_editor
      env_editor = ENV["EDITOR"].to_s.strip
      unless env_editor.empty?
        base = File.basename(env_editor.split(/\s/).first.to_s)
        preset = EDITOR_EXECUTABLES[base]
        return EDITOR_COMMANDS[preset] if preset
        return "#{env_editor} +{line} {file}"
      end

      EDITOR_EXECUTABLES.each do |exe, preset|
        return EDITOR_COMMANDS[preset] if command_exists?(exe)
      end

      nil
    end

    def detect_editor_name
      env_editor = ENV["EDITOR"].to_s.strip
      unless env_editor.empty?
        base = File.basename(env_editor.split(/\s/).first.to_s)
        preset = EDITOR_EXECUTABLES[base]
        return preset.to_s if preset
        return base
      end

      EDITOR_EXECUTABLES.each do |exe, preset|
        return preset.to_s if command_exists?(exe)
      end

      nil
    end

    def command_exists?(cmd)
      system("which #{cmd} > /dev/null 2>&1")
    end
  end
end
