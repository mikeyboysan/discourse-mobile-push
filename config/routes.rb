# frozen_string_literal: true

DiscourseMobilePush::Engine.routes.draw do
  scope "/v1", defaults: { format: :json } do
    get "/devices" => "devices#index"
    post "/devices" => "devices#create"
    delete "/devices/:id" => "devices#destroy", :constraints => { id: /\d+/ }
    delete "/devices" => "devices#destroy_by_token"
  end
end

Discourse::Application.routes.draw do
  mount ::DiscourseMobilePush::Engine, at: "/mobile-push"

  scope "/admin/mobile-push", constraints: AdminConstraint.new, defaults: { format: :json } do
    get "/status" => "discourse_mobile_push/admin/status#show"
    get "/devices" => "discourse_mobile_push/admin/devices#index"
    post "/devices/:id/test" => "discourse_mobile_push/admin/devices#send_test",
         :constraints => {
           id: /\d+/,
         }
  end
end
