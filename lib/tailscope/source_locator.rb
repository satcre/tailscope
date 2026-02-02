# frozen_string_literal: true

module Tailscope
  module SourceLocator
    IGNORE_PATTERNS = [
      %r{/tailscope/},
      %r{/ruby/gems/},
      %r{/bundler/},
      %r{<internal:},
      %r{/lib/ruby/},
    ].freeze

    class << self
      def locate(backtrace_locations = nil)
        backtrace_locations ||= caller_locations(2)
        return {} unless backtrace_locations

        source_root = Tailscope.configuration.source_root

        location = backtrace_locations.find do |loc|
          path = loc.absolute_path || loc.path
          next false unless path

          in_app = path.start_with?(source_root) if source_root
          not_ignored = IGNORE_PATTERNS.none? { |pat| path.match?(pat) }
          in_app && not_ignored
        end

        return {} unless location

        {
          source_file: location.absolute_path || location.path,
          source_line: location.lineno,
          source_method: location.label,
        }
      end
    end
  end
end
