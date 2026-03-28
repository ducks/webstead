Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root domain routes (no subdomain) - marketing and auth
  # Authentication routes
  get "signup", to: "registrations#new"
  post "signup", to: "registrations#create"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Webstead creation and management
  resources :websteads, only: [ :new, :create ] do
    member do
      get :provisioning
    end
    collection do
      get :check_availability
    end
  end
  get "dashboard", to: "websteads#dashboard"

  # WebFinger endpoint for ActivityPub discovery
  # Must be outside subdomain constraints - queries come to the root domain
  # (e.g., GET https://webstead.dev/.well-known/webfinger?resource=acct:alice@webstead.dev)
  get "/.well-known/webfinger", to: "well_known/webfinger#show", as: :well_known_webfinger

  # Subdomain-scoped routes (tenant content)
  constraints subdomain: /.+/ do
    # ActivityPub Actor endpoint
    get "/actor", to: "activitypub/actors#show"
    get "/u/:username", to: "activitypub/actors#show"

    # ActivityPub Inbox endpoint
    post "/users/:username/inbox", to: "activitypub/inbox#create"

    # ActivityPub Outbox endpoint
    get "/@:username/outbox", to: "activitypub/outbox#show"

    # Posts routes (scoped to webstead via TenantScoped concern)
    resources :posts, only: [ :index, :show, :new, :create, :edit, :update ]
    resources :comments, only: [ :create ]

    root "posts#index", as: :subdomain_root
  end

  # Root domain landing page
  root "marketing#index"
end
