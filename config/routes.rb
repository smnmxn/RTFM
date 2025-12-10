require "sidekiq/web"

Rails.application.routes.draw do
  # Sidekiq Web UI (authenticated users only)
  authenticate_sidekiq = ->(request) {
    session = request.session
    session[:user_id].present?
  }
  constraints authenticate_sidekiq do
    mount Sidekiq::Web => "/sidekiq"
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Webhooks
  namespace :webhooks do
    post "github", to: "github#create"
  end

  # Authentication
  get  "/login",  to: "sessions#new",     as: :login
  get  "/logout", to: "sessions#destroy", as: :logout
  delete "/logout", to: "sessions#destroy"

  # OmniAuth callbacks
  get "/auth/github/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"

  # Dashboard
  get "/dashboard", to: "dashboard#show", as: :dashboard

  # Projects
  resources :projects, only: [ :new, :create, :show, :destroy ] do
    collection do
      get :repositories
    end
    member do
      get :pull_requests
      post :analyze
    end
  end

  # Root
  root to: "sessions#new"
end
