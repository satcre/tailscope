# frozen_string_literal: true

require "net/http"

module Tailscope
  module Instrumentors
    module NetHttp
      def request(req, body = nil, &block)
        return super unless Tailscope.enabled?

        uri = URI::HTTP.build(
          host: address,
          port: port,
          path: req.path.split("?").first
        )

        payload = { method: req.method, uri: uri.to_s }

        ActiveSupport::Notifications.instrument("request.net_http", payload) do
          response = super
          payload[:status] = response.code.to_i
          response
        end
      end
    end
  end
end

Net::HTTP.prepend(Tailscope::Instrumentors::NetHttp)
