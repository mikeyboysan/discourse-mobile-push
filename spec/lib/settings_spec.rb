# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::Settings do
  subject(:settings) { described_class.current }

  it "returns the allowed app ids as an array" do
    SiteSetting.mobile_push_allowed_app_ids = "com.example.one|com.example.two"

    expect(settings.allowed_app_ids).to eq(%w[com.example.one com.example.two])
  end

  it "returns no allowed app ids when the setting is empty" do
    SiteSetting.mobile_push_allowed_app_ids = ""

    expect(settings.allowed_app_ids).to eq([])
  end

  it "returns the high priority notification types as an array" do
    SiteSetting.mobile_push_high_priority_notification_types = "private_message|chat_mention"

    expect(settings.high_priority_notification_types).to eq(%w[private_message chat_mention])
  end

  it "returns the privacy mode as a symbol" do
    SiteSetting.mobile_push_privacy_mode = "generic"

    expect(settings.privacy_mode).to eq(:generic)
  end

  it "returns nil for a blank project id override" do
    SiteSetting.mobile_push_firebase_project_id = ""

    expect(settings.firebase_project_id_override).to be_nil
  end
end
