# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::Admin::StatusController do
  fab!(:admin)

  before do
    enable_current_plugin
    SiteSetting.mobile_push_firebase_service_account_json = fcm_service_account_json
  end

  def perform_request = get "/admin/mobile-push/status.json"

  include_examples "a mobile push admin-only endpoint"

  context "as an admin" do
    before { sign_in(admin) }

    it "reports configuration, health, diagnostics, and device counts" do
      Fabricate(:mobile_push_device, platform: "ios", app_version: "2.0.0")
      DiscourseMobilePush::DiagnosticsStore.new.record(
        result: DiscourseMobilePush::DeliveryResult.new(outcome: :rejected, detail: "HTTP 400"),
      )

      perform_request

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json).to include(
        "enabled" => true,
        "configured" => true,
        "project_id" => MobilePushSpecHelpers::FCM_PROJECT_ID,
        "configuration_error" => nil,
        "problem" => nil,
      )
      expect(json["summary"]).to include("last_failure_detail" => "HTTP 400")
      expect(json["counts"]).to eq(
        "total" => 1,
        "stale" => 0,
        "by_platform" => {
          "ios" => 1,
        },
        "by_app_version" => [
          { "app_id" => "com.example.app", "app_version" => "2.0.0", "count" => 1 },
        ],
      )
    end

    it "reports invalid credentials" do
      SiteSetting.mobile_push_firebase_service_account_json = "{}"

      perform_request

      json = response.parsed_body
      expect(json).to include(
        "configured" => false,
        "project_id" => nil,
        "problem" => "not_configured",
      )
      expect(json["configuration_error"]).to be_present
    end
  end
end
