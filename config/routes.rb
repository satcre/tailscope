# frozen_string_literal: true

Tailscope::Engine.routes.draw do
  namespace :api do
    resources :issues, only: [:index]
    post "issues/:fingerprint/ignore", to: "issues#ignore", as: :ignore_issue
    post "issues/:fingerprint/unignore", to: "issues#unignore", as: :unignore_issue

    resources :queries, only: [:index, :show]
    delete "queries", to: "queries#destroy_all"
    resources :requests, only: [:index, :show]
    delete "requests", to: "requests#destroy_all"
    resources :errors, only: [:index, :show]
    delete "errors", to: "errors#destroy_all"
    resources :jobs, only: [:index, :show]
    delete "jobs", to: "jobs#destroy_all"

    get "source", to: "source#show", as: :source
    post "editor/open", to: "editor#open", as: :editor_open
    post "editor/check", to: "editor#check", as: :editor_check

    get "debugger", to: "debugger#index", as: :debugger_index
    post "debugger/breakpoints", to: "debugger#create_breakpoint", as: :debugger_breakpoints
    delete "debugger/breakpoints/:id", to: "debugger#remove_breakpoint", as: :debugger_remove_breakpoint
    get "debugger/sessions/:id", to: "debugger#show_session", as: :debugger_session
    post "debugger/sessions/:id/evaluate", to: "debugger#evaluate", as: :debugger_evaluate
    post "debugger/sessions/:id/continue", to: "debugger#continue_session", as: :debugger_continue_session
    post "debugger/sessions/:id/step_into", to: "debugger#step_into", as: :debugger_step_into
    post "debugger/sessions/:id/step_over", to: "debugger#step_over", as: :debugger_step_over
    post "debugger/sessions/:id/step_out", to: "debugger#step_out", as: :debugger_step_out
    get "debugger/poll", to: "debugger#poll", as: :debugger_poll
    get "debugger/browse", to: "debugger#browse", as: :debugger_browse
  end

  # SPA catch-all
  root to: "spa#index"
  get "*path", to: "spa#index", constraints: ->(req) { !req.path.start_with?("/api") }
end
