# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::Device do
  subject(:device) { Fabricate.build(:mobile_push_device, token: "abc123token") }

  describe "validations" do
    it "accepts a well-formed device" do
      expect(device).to be_valid
    end

    it "rejects an unknown platform" do
      device.platform = "windows"

      expect(device).not_to be_valid
      expect(device.errors[:platform]).to be_present
    end

    it "rejects an app id with characters outside the allowed set" do
      device.app_id = "com.example/app"

      expect(device).not_to be_valid
      expect(device.errors[:app_id]).to be_present
    end

    it "requires a token" do
      device.token = ""

      expect(device).not_to be_valid
      expect(device.errors[:token]).to be_present
    end

    it "rejects a token containing whitespace" do
      device.token = "abc def"

      expect(device).not_to be_valid
      expect(device.errors[:token]).to be_present
    end

    it "rejects a token longer than the maximum length" do
      device.token = "a" * (described_class::MAX_TOKEN_LENGTH + 1)

      expect(device).not_to be_valid
      expect(device.errors[:token]).to be_present
    end

    it "rejects an app version longer than the maximum length" do
      device.app_version = "1" * (described_class::MAX_APP_VERSION_LENGTH + 1)

      expect(device).not_to be_valid
      expect(device.errors[:app_version]).to be_present
    end

    it "rejects a device identifier longer than the maximum length" do
      device.device_identifier = "d" * (described_class::MAX_DEVICE_IDENTIFIER_LENGTH + 1)

      expect(device).not_to be_valid
      expect(device.errors[:device_identifier]).to be_present
    end
  end

  describe "#token_fingerprint" do
    it "is a short digest that does not reveal the token" do
      fingerprint = device.token_fingerprint

      expect(fingerprint).to match(/\A\h{#{described_class::FINGERPRINT_LENGTH}}\z/)
      expect(fingerprint).to eq(Digest::SHA256.hexdigest("abc123token").first(12))
      expect(fingerprint).not_to include("abc123")
    end
  end

  describe "#inspect" do
    it "masks the token" do
      expect(device.inspect).not_to include("abc123token")
    end
  end

  describe "#stale?" do
    before { freeze_time }

    it "is true when the device was last seen before the threshold" do
      device.last_seen_at = 61.days.ago

      expect(device.stale?(days: 60)).to eq(true)
    end

    it "is false when the device was seen within the threshold" do
      device.last_seen_at = 59.days.ago

      expect(device.stale?(days: 60)).to eq(false)
    end
  end

  describe "delivery tracking" do
    fab!(:persisted_device, :mobile_push_device)

    before { freeze_time }

    it "records the last delivery time" do
      persisted_device.record_delivery!(at: Time.zone.now)

      expect(persisted_device.reload.last_delivered_at).to eq_time(Time.zone.now)
    end

    it "records the failure time and a truncated reason" do
      persisted_device.record_failure!(reason: "x" * 300, at: Time.zone.now)

      persisted_device.reload
      expect(persisted_device.last_failure_at).to eq_time(Time.zone.now)
      expect(persisted_device.last_failure_reason.length).to eq(
        described_class::MAX_FAILURE_REASON_LENGTH,
      )
    end
  end
end
