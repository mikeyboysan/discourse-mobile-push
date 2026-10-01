# frozen_string_literal: true

DiscourseMobilePush::Engine.routes.draw do
  scope "/v1", defaults: { format: :json } do
    get "/devices" => "devices#index"
    post "/devices" => "devices#create"
    delete "/devices/:id" => "devices#destroy", :constraints => { id: /\d+/ }
    delete "/devices" => "devices#destroy_by_token"
  end
end

Discourse::Application.routes.draw { mount ::DiscourseMobilePush::Engine, at: "/mobile-push" }
