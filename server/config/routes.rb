Rails.application.routes.draw do
  root to: "static#index"

  get "/sign_in" =>"static#index"

  scope "api", defaults: { format: :json } do
    get "/status", to: "static#status"
    post "/graphql", to: "graphql#execute"
    get "/auth/:provider/callback" => "sessions#create"
    get "/sign_out" => "sessions#destroy", as: :signout
    post "/upload_profile_image" => "profile_images#upload"

    post "/download_table/:table_name" => "table_download#download"

    if Rails.env.development?
      post "/auth/:provider/callback" => "sessions#create"
    end
  end

  get "/links" => "links#redirect"
  get "links/:idtype/:id" => "links#redirect"
  get "/genes/:id" => "links#redirect_legacy_gene_id"

  get "/api/graphiql" => "graphiql#show"

  get "/curation-chat", to: "chats/chats#new", defaults: { chat_type: "curation" }, as: :curation_chat
  get "/mcp-chat", to: "chats/chats#new", defaults: { chat_type: "mcp" }, as: :mcp_chat

  get "/chats/shared/:public_id", to: "chats/shared_chats#show", as: :shared_chat

  namespace :chats, path: "chats" do
    root to: "chats#index"
    resources :chats, path: "" do
      member do
        post :share
        delete :unshare
      end
      resources :messages, only: [ :create ]
    end
    resources :models, only: [ :index, :show ] do
      collection do
        post :refresh
      end
    end
  end

  require "sidekiq/web"
  require "sidekiq/cron/web"
  mount Sidekiq::Web, at: "/jobs", constraints: UserLoggedInConstraint.new
  mount SolidErrors::Engine, at: "/errors", constraints: UserLoggedInConstraint.new

  # Catch-all for Angular client-side routes (e.g. /welcome after sign-in,
  # /evidence, /variants/123, ...). The real CIViC deploy has nginx fall back
  # to index.html for anything that isn't a known server route; this Docker
  # deploy has no nginx in front, so Rails needs to do that fallback itself.
  # Must stay last - only unmatched GETs reach it.
  get "*path", to: "static#index", constraints: lambda { |req|
    !req.path.start_with?("/api", "/jobs", "/errors", "/chats")
  }
end
