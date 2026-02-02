# frozen_string_literal: true

Tailscope::Engine.routes.draw do
  root to: "issues#index"

  resources :issues, only: [:index]
  resources :queries, only: [:index, :show]
  resources :requests, only: [:index, :show]
  resources :errors, only: [:index, :show]

  get "source", to: "source#show", as: :source

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
