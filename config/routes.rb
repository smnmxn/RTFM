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

  # Email preview UI (development only)
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
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

  # Invites
  get "/invite/:token", to: "invites#show", as: :invite

  # Waitlist
  post "/waitlist", to: "waitlist#create", as: :waitlist

  # OmniAuth callbacks
  get "/auth/github/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"

  # GitHub App installation
  get "/github_app/install", to: "github_app#install", as: :github_app_install
  get "/github_app/callback", to: "github_app#callback", as: :github_app_callback

  # Projects (list)
  get "/projects", to: "projects#index", as: :projects

  # Onboarding Wizard
  namespace :onboarding do
    resources :projects, only: [ :new, :create ], param: :slug do
      member do
        get :repository
        post :connect
        get :setup
        post :save_setup
        get :analyze
        post :start_analysis
        post :retry_sections
        patch :save_context
        get :sections
        post :complete_sections
        get :generating
      end
    end
  end

  # Projects
  resources :projects, only: [ :new, :create, :show, :destroy ], param: :slug do
    collection do
      get :repositories
    end
    member do
      get :pull_requests
      get :code_history
      post :analyze
      post :generate_recommendations
      post "pull_requests/:pr_number/analyze", to: "projects#analyze_pull_request", as: :analyze_pull_request
      post "commits/:commit_sha/analyze", to: "projects#analyze_commit", as: :analyze_commit
      # Inbox actions (article review)
      get :inbox_articles
      get :select_article
      post :approve_article
      post :reject_article
      post :undo_reject_article
      # Inbox actions (recommendations)
      get :select_recommendation
      post :accept_recommendation
      post :reject_recommendation
      # Articles tab actions
      get :select_articles_article
      # Settings actions
      post :start_over
      post :test_toast
      # Branding settings
      patch :update_branding
      post :upload_logo
      delete :remove_logo
      # AI settings
      patch :update_ai_settings
      # Notification preferences
      patch :update_notification_preferences
      get :preview_notification_email
      # Update strategy
      patch :update_strategy
      # Repository management
      post :add_repository
      delete :remove_repository
      patch :set_primary_repository
      # Maintenance / Article updates
      post :create_article_update_check
      get :article_update_check
    end
    resources :article_update_suggestions, only: [] do
      member do
        post :accept
        post :dismiss
      end
    end
    resources :recommendations, only: [] do
      member do
        post :reject
        post :generate
      end
    end
    resources :articles, only: [ :show, :destroy ] do
      collection do
        post :create_article
        patch :bulk_reorder
      end
      member do
        get :preview
        post :regenerate
        patch :update_field
        post :add_array_item
        delete :remove_array_item
        patch :reorder_array_item
        post :publish
        post :unpublish
        patch :move_to_section
        patch :reorder
        post :duplicate
        post :upload_step_image
        delete :remove_step_image
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

  # Public Help Centre (subdomain-based, e.g., acme.supportpages.io)
  # URL structure: /:section_slug/:article_slug
  constraints SubdomainConstraint do
    root "help_centre#index", as: :help_centre
    get "ask", to: "help_centre#ask", as: :help_centre_ask
    get ":section_slug/:article_slug", to: "help_centre#show", as: :help_centre_article
    get ":section_slug", to: "help_centre#section", as: :help_centre_section
  end

  # Root
  root to: "sessions#new"
end
