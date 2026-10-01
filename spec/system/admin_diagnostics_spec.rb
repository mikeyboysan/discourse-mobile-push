# frozen_string_literal: true

RSpec.describe "Mobile push admin diagnostics" do
  fab!(:admin)
  fab!(:user)

  let(:diagnostics_page) { PageObjects::Pages::AdminMobilePushDiagnostics.new }

  before do
    enable_current_plugin
    SiteSetting.mobile_push_firebase_service_account_json = fcm_service_account_json
    sign_in(admin)
  end

  it "is reachable from the plugin's admin navigation" do
    visit("/admin/plugins/discourse-mobile-push/settings")

    click_link(I18n.t("admin_js.discourse_mobile_push.admin.diagnostics.title"))

    expect(diagnostics_page).to have_project_id(MobilePushSpecHelpers::FCM_PROJECT_ID)
  end

  it "shows configuration and devices without exposing tokens" do
    device = Fabricate(:mobile_push_device, user:, platform: "ios", app_version: "1.2.0")

    diagnostics_page.visit_page

    expect(diagnostics_page).to have_project_id(MobilePushSpecHelpers::FCM_PROJECT_ID)
    expect(diagnostics_page).to have_no_problem
    expect(diagnostics_page.device_row(device)).to have_text(user.username)
    expect(diagnostics_page.device_row(device)).to have_text(device.token_fingerprint)
    expect(page).to have_no_text(device.token)
  end

  it "reports missing credentials" do
    SiteSetting.mobile_push_firebase_service_account_json = ""

    diagnostics_page.visit_page

    expect(diagnostics_page).to have_problem("service account key is missing or invalid")
  end

  it "filters devices by username" do
    own = Fabricate(:mobile_push_device, user:)
    other = Fabricate(:mobile_push_device)

    diagnostics_page.visit_page.filter_by_username(user.username)

    expect(diagnostics_page).to have_no_device(other)
    expect(diagnostics_page).to have_device(own)
  end

  it "says so when no devices match the filter" do
    device = Fabricate(:mobile_push_device)

    diagnostics_page.visit_page.filter_by_username(user.username)

    expect(diagnostics_page).to have_no_device(device)
    expect(diagnostics_page).to have_empty_notice
  end

  it "loads more devices" do
    stub_const(DiscourseMobilePush::DeviceRegistry, :PAGE_SIZE, 1) do
      older = Fabricate(:mobile_push_device, last_seen_at: 2.days.ago)
      newer = Fabricate(:mobile_push_device, last_seen_at: 1.day.ago)

      diagnostics_page.visit_page

      expect(diagnostics_page).to have_device(newer)
      expect(diagnostics_page).to have_no_device(older)

      diagnostics_page.load_more

      expect(diagnostics_page).to have_device(older)
    end
  end

  context "when sending a test notification" do
    let!(:device) { Fabricate(:mobile_push_device, user:) }

    it "delivers it after confirmation and shows the outcome" do
      provider = MobilePushFakeProvider.new
      DiscourseMobilePush.stubs(:interactive_provider).returns(provider)

      diagnostics_page.visit_page.send_test(device)

      expect(diagnostics_page).to have_test_result(device, "Test notification delivered")
      expect(provider.deliveries.size).to eq(1)
    end

    it "reports an invalid token and the device's removal" do
      DiscourseMobilePush.stubs(:interactive_provider).returns(
        MobilePushFakeProvider.new(outcome: :invalid_device),
      )

      diagnostics_page.visit_page.send_test(device)

      expect(diagnostics_page).to have_test_result(device, "the device was removed")
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
    end
  end
end
