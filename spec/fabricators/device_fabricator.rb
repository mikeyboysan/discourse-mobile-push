# frozen_string_literal: true

Fabricator(:mobile_push_device, class_name: "DiscourseMobilePush::Device") do
  user
  platform "android"
  app_id "com.example.app"
  token { sequence(:mobile_push_token) { |i| "push-token-#{i}" } }
  last_seen_at { Time.zone.now }
end
