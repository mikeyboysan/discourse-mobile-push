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
      user_api_key_id: attrs[:user_api_key_id],
      user_auth_token_id: attrs[:user_auth_token_id],
    )
  end

  def signed_out_devices
    revoked_key = Fabricate(:user_api_key, user:, revoked_at: 1.minute.ago)
    expired_key = Fabricate(:user_api_key, user:, expires_at: 1.minute.ago)
    expired_session = UserAuthToken.generate!(user_id: user.id)
    expired_session.update_columns(rotated_at: (SiteSetting.maximum_session_age + 1).hours.ago)
    [
      Fabricate(:mobile_push_device, user:, user_api_key_id: revoked_key.id),
      Fabricate(:mobile_push_device, user:, user_api_key_id: expired_key.id),
      Fabricate(:mobile_push_device, user:, user_api_key_id: -1),
      Fabricate(:mobile_push_device, user:, user_auth_token_id: expired_session.id),
      Fabricate(:mobile_push_device, user:, user_auth_token_id: -1),
    ]
  end

  def signed_in_devices
    active_key = Fabricate(:user_api_key, user:)
    session = UserAuthToken.generate!(user_id: user.id)
    [
      Fabricate(:mobile_push_device, user:),
      Fabricate(:mobile_push_device, user:, user_api_key_id: active_key.id),
      Fabricate(:mobile_push_device, user:, user_auth_token_id: session.id),
    ]
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

    it "records the credential the device was registered with" do
      result =
        registry.register(
          user:,
          registration: registration(user_api_key_id: 11, user_auth_token_id: 22),
        )

      expect(result.device).to have_attributes(user_api_key_id: 11, user_auth_token_id: 22)
    end

    it "links an existing device to the credential of its latest registration" do
      device = Fabricate(:mobile_push_device, user:, token: "token-1", user_api_key_id: 11)

      registry.register(user:, registration: registration(user_auth_token_id: 22))

      expect(device.reload).to have_attributes(user_api_key_id: nil, user_auth_token_id: 22)
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

    it "leaves out devices whose credential was revoked, expired, or deleted" do
      signed_out_devices
      live = signed_in_devices

      expect(registry.devices_for(user:)).to match_array(live)
    end
  end

  describe "#remove_signed_out" do
    it "removes only devices whose credential was revoked, expired, or deleted" do
      signed_out_devices
      live = signed_in_devices

      expect(registry.remove_signed_out).to eq(5)
      expect(DiscourseMobilePush::Device.all).to match_array(live)
    end
  end

  describe "#remove" do
    it "removes the device and reports whether it existed" do
      device = Fabricate(:mobile_push_device)

      expect(registry.remove(device:)).to eq(true)
      expect(registry.remove(device:)).to eq(false)
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
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

  describe "#find" do
    it "finds any user's device by id" do
      device = Fabricate(:mobile_push_device, user: other_user)

      expect(registry.find(device_id: device.id)).to eq(device)
    end

    it "returns nil for an unknown id" do
      expect(registry.find(device_id: -1)).to be_nil
    end
  end

  describe "#counts" do
    before { SiteSetting.mobile_push_stale_device_days = 30 }

    it "counts devices by platform, app version, and staleness" do
      Fabricate(:mobile_push_device, platform: "android", app_version: "1.0.0")
      Fabricate(:mobile_push_device, platform: "android", app_version: "1.1.0")
      Fabricate(
        :mobile_push_device,
        platform: "ios",
        app_version: "1.1.0",
        last_seen_at: 31.days.ago,
      )

      counts = registry.counts

      expect(counts).to have_attributes(total: 3, stale: 1)
      expect(counts.by_platform).to eq("android" => 2, "ios" => 1)
      expect(counts.by_app_version.map(&:to_h)).to eq(
        [
          { app_id: "com.example.app", app_version: "1.0.0", count: 1 },
          { app_id: "com.example.app", app_version: "1.1.0", count: 2 },
        ],
      )
    end

    it "reports zeros without devices" do
      expect(registry.counts).to have_attributes(
        total: 0,
        stale: 0,
        by_platform: {
        },
        by_app_version: [],
      )
    end
  end

  describe "#search" do
    it "lists all devices, most recently seen first" do
      older = Fabricate(:mobile_push_device, user:, last_seen_at: 2.days.ago)
      newer = Fabricate(:mobile_push_device, user: other_user, last_seen_at: 1.day.ago)

      page = registry.search

      expect(page.devices).to eq([newer, older])
      expect(page).to have_attributes(total_rows: 2, page: 0)
    end

    it "filters by owners" do
      own = Fabricate(:mobile_push_device, user:)
      Fabricate(:mobile_push_device, user: other_user)

      page = registry.search(owners: User.where(id: user.id))

      expect(page.devices).to eq([own])
      expect(page.total_rows).to eq(1)
    end

    it "finds nothing when no owner matches" do
      Fabricate(:mobile_push_device, user:)

      expect(registry.search(owners: User.none)).to have_attributes(devices: [], total_rows: 0)
    end

    it "pages through the results" do
      stub_const(described_class, :PAGE_SIZE, 2) do
        devices =
          3.times.map { |i| Fabricate(:mobile_push_device, user:, last_seen_at: i.days.ago) }

        page = registry.search(page: 1)

        expect(page.devices).to eq([devices.last])
        expect(page).to have_attributes(total_rows: 3, page: 1)
      end
    end
  end
end
