# frozen_string_literal: true

RSpec.describe ProblemCheck::MobilePushConfiguration do
  subject(:check) { described_class.new }

  let(:settings_link) { "/admin/site_settings/category/discourse_mobile_push" }

  before do
    enable_current_plugin
    SiteSetting.mobile_push_firebase_service_account_json = fcm_service_account_json
  end

  it "is registered with core" do
    expect(ProblemCheck.checks).to include(described_class)
  end

  it "reports no problem when push is healthy" do
    expect(check.call).to be_nil
  end

  it "reports invalid credentials" do
    SiteSetting.mobile_push_firebase_service_account_json = "{}"

    problem = check.call

    expect(problem.message).to include("service account key is missing or invalid", settings_link)
  end

  it "reports widespread configuration errors with their own message" do
    diagnostics = DiscourseMobilePush::DiagnosticsStore.new
    Fabricate
      .times(2, :mobile_push_device)
      .each do |device|
        diagnostics.record(
          result: DiscourseMobilePush::DeliveryResult.new(outcome: :config_error),
          device_id: device.id,
        )
      end

    problem = check.call

    expect(problem.message).to include("Firebase rejected", settings_link)
  end
end
