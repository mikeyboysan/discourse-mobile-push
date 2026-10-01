# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::DeviceRegistry do
  subject(:registry) { described_class.new }

  fab!(:user)
  fab!(:other_user, :user)

  def registration(token: "token-1", app_id: "com.example.app", device_identifier: nil, **attrs)
    described_class::Registration.new(
      platform: attrs.fetch(:platform, "android"),
      app_id:,
      token:,
      app_version: attrs.fetch(:app_version, "1.0.0"),
      device_identifier:,
    )
  end

  describe "#register" do
    it "creates a device owned by the user" do
      result = registry.register(user:, registration: registration)

      expect(result.created).to eq(true)
      expect(result.device).to be_persisted
      expect(result.device).to have_attributes(user:, token: "token-1", app_version: "1.0.0")
    end

    it "updates the existing device when the same token is registered again" do
      first = registry.register(user:, registration: registration(app_version: "1.0.0")).device

      result = registry.register(user:, registration: registration(app_version: "2.0.0"))

      expect(result.created).to eq(false)
      expect(result.device.id).to eq(first.id)
      expect(result.device.reload.app_version).to eq("2.0.0")
    end

    it "refreshes last_seen_at on re-registration" do
      device = Fabricate(:mobile_push_device, user:, token: "token-1", last_seen_at: 3.days.ago)
      freeze_time

      registry.register(user:, registration: registration)

      expect(device.reload.last_seen_at).to eq_time(Time.zone.now)
    end

    it "transfers a token registered by another user to the new user" do
      device = Fabricate(:mobile_push_device, user: other_user, token: "token-1")

      result = registry.register(user:, registration: registration)

      expect(result.device.id).to eq(device.id)
      expect(device.reload.user).to eq(user)
    end

    it "replaces the token of the device matching the same app and device identifier" do
      device =
        Fabricate(:mobile_push_device, user:, token: "old-token", device_identifier: "install-1")

      result =
        registry.register(
          user:,
          registration: registration(token: "new-token", device_identifier: "install-1"),
        )

      expect(result.created).to eq(false)
      expect(device.reload.token).to eq("new-token")
    end

    it "removes the new owner's stale device when a transferred token collides with it" do
      transferred =
        Fabricate(
          :mobile_push_device,
          user: other_user,
          token: "token-1",
          device_identifier: "install-1",
        )
      stale =
        Fabricate(:mobile_push_device, user:, token: "stale-token", device_identifier: "install-1")

      registry.register(user:, registration: registration(device_identifier: "install-1"))

      expect(DiscourseMobilePush::Device.exists?(stale.id)).to eq(false)
      expect(transferred.reload.user).to eq(user)
    end

    it "keeps separate devices for registrations without a device identifier" do
      registry.register(user:, registration: registration(token: "token-1"))
      registry.register(user:, registration: registration(token: "token-2"))

      expect(DiscourseMobilePush::Device.where(user:).count).to eq(2)
    end

    it "evicts the least recently seen devices beyond the per-user cap" do
      SiteSetting.mobile_push_max_devices_per_user = 2
      oldest = Fabricate(:mobile_push_device, user:, last_seen_at: 3.days.ago)
      newer = Fabricate(:mobile_push_device, user:, last_seen_at: 1.day.ago)

      registry.register(user:, registration: registration(token: "token-new"))

      expect(DiscourseMobilePush::Device.where(user:).pluck(:id)).to contain_exactly(
        newer.id,
        DiscourseMobilePush::Device.find_by(token: "token-new").id,
      )
      expect(DiscourseMobilePush::Device.exists?(oldest.id)).to eq(false)
    end

    it "rejects an app id that is not in the allowlist" do
      SiteSetting.mobile_push_allowed_app_ids = "com.example.allowed"

      expect {
        registry.register(user:, registration: registration(app_id: "com.example.other"))
      }.to raise_error(ActiveRecord::RecordInvalid)
      expect(DiscourseMobilePush::Device.count).to eq(0)
    end

    it "accepts an app id that is in the allowlist" do
      SiteSetting.mobile_push_allowed_app_ids = "com.example.app"

      result = registry.register(user:, registration: registration)

      expect(result.device).to be_persisted
    end

    it "rejects invalid attributes" do
      expect {
        registry.register(user:, registration: registration(platform: "windows"))
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "updates the winning row when a concurrent registration inserted the same token first" do
      concurrent = Fabricate(:mobile_push_device, user: other_user, token: "token-1")
      registry.stubs(:find_existing).returns(nil).then.returns(concurrent)

      result = registry.register(user:, registration: registration)

      expect(result.device.id).to eq(concurrent.id)
      expect(concurrent.reload.user).to eq(user)
      expect(DiscourseMobilePush::Device.count).to eq(1)
    end

    it "raises when the retry also hits a uniqueness conflict" do
      Fabricate(:mobile_push_device, user: other_user, token: "token-1")
      registry.stubs(:find_existing).returns(nil)

      expect { registry.register(user:, registration: registration) }.to raise_error(
        ActiveRecord::RecordNotUnique,
      )
    end
  end

  describe "#devices_for" do
    it "returns only the user's devices, most recently seen first" do
      older = Fabricate(:mobile_push_device, user:, last_seen_at: 2.days.ago)
      newer = Fabricate(:mobile_push_device, user:, last_seen_at: 1.hour.ago)
      Fabricate(:mobile_push_device, user: other_user)

      expect(registry.devices_for(user:).to_a).to eq([newer, older])
    end
  end

  describe "#unregister_by_id" do
    it "removes the user's own device" do
      device = Fabricate(:mobile_push_device, user:)

      expect(registry.unregister_by_id(user:, device_id: device.id)).to eq(true)
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
    end

    it "does not remove another user's device" do
      device = Fabricate(:mobile_push_device, user: other_user)

      expect(registry.unregister_by_id(user:, device_id: device.id)).to eq(false)
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(true)
    end
  end

  describe "#unregister_by_token" do
    it "removes the user's own device" do
      device = Fabricate(:mobile_push_device, user:, token: "token-1")

      expect(registry.unregister_by_token(user:, token: "token-1")).to eq(true)
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
    end

    it "does not remove another user's device" do
      device = Fabricate(:mobile_push_device, user: other_user, token: "token-1")

      expect(registry.unregister_by_token(user:, token: "token-1")).to eq(false)
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(true)
    end
  end

  describe "#remove_all_for" do
    it "removes every device of the user and nothing else" do
      Fabricate.times(2, :mobile_push_device, user:)
      kept = Fabricate(:mobile_push_device, user: other_user)

      registry.remove_all_for(user:)

      expect(DiscourseMobilePush::Device.pluck(:id)).to eq([kept.id])
    end
  end

  describe "#invalidate" do
    it "removes the device" do
      device = Fabricate(:mobile_push_device)

      registry.invalidate(device:)

      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
    end
  end
end
