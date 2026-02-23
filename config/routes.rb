Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # WebFinger endpoint for ActivityPub discovery
  get "/.well-known/webfinger", to: "well_known/webfinger#show"

  # ActivityPub Actor endpoint
  get "/actor", to: "activitypub/actors#show"
  get "/u/:username", to: "activitypub/actors#show"

  # ActivityPub Inbox endpoint
  post "/users/:username/inbox", to: "activitypub/inbox#create"

  # ActivityPub Inbox endpoint
  post "/users/:username/inbox", to: "activitypub/inbox#create"

  # Authentication routes
  get "signup", to: "registrations#new"
  post "signup", to: "registrations#create"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Posts routes (scoped to webstead via TenantScoped concern)
  resources :posts, only: [ :index, :show, :new, :create, :edit, :update ]

  # Defines the root path route ("/")
  root "posts#index"
end
