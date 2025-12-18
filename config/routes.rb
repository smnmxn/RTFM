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

  # Onboarding Wizard
  namespace :onboarding do
    resources :projects, only: [ :new, :create ] do
      member do
        get :repository
        post :connect
        get :analyze
        post :start_analysis
        get :sections
        post :complete_sections
      end
    end
  end

  # Projects
  resources :projects, only: [ :new, :create, :show, :destroy ] do
    collection do
      get :repositories
    end
    member do
      get :pull_requests
      post :analyze
      post :generate_recommendations
      post "pull_requests/:pr_number/analyze", to: "projects#analyze_pull_request", as: :analyze_pull_request
      # Inbox actions (article review)
      get :select_article
      post :approve_article
      post :reject_article
      post :undo_reject_article
      # Inbox actions (recommendations)
      get :select_recommendation
      post :accept_recommendation
      post :reject_recommendation
    end
    resources :recommendations, only: [] do
      member do
        post :reject
        post :generate
      end
    end
    resources :articles, only: [ :show ] do
      member do
        post :regenerate
        patch :update_field
        post :add_array_item
        delete :remove_array_item
        post :publish
        post :unpublish
      end
    end
    resources :sections do
      member do
        post :move
        post :generate_recommendations
        post :accept
        post :reject
      end
      collection do
        post :suggest_sections
      end
    end
  end

  # Public Help Centre (unauthenticated)
  scope "/:project_slug" do
    get "help", to: "help_centre#index", as: :help_centre
    get "help/section/:section_slug", to: "help_centre#section", as: :help_centre_section
    get "help/:id", to: "help_centre#show", as: :help_centre_article
  end

  # Root
  root to: "sessions#new"
end
