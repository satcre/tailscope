# frozen_string_literal: true

Rails.application.routes.draw do
  mount Tailscope::Engine, at: "/tailscope"

  get "/test", to: "test#index"
  get "/error_test", to: "test#error_test"
end
