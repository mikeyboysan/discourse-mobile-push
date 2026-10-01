# frozen_string_literal: true

module DiscourseMobilePush
  class DeviceRegistry
    Registration =
      Data.define(
        :platform,
        :app_id,
        :token,
        :app_version,
        :device_identifier,
        :user_api_key_id,
        :user_auth_token_id,
      ) { def initialize(user_api_key_id: nil, user_auth_token_id: nil, **) = super }
    Result = Data.define(:device, :created)
    Counts = Data.define(:total, :stale, :by_platform, :by_app_version)
    AppVersionCount = Data.define(:app_id, :app_version, :count)
    Page = Data.define(:devices, :total_rows, :page)

    PAGE_SIZE = 50

    def initialize(settings: DiscourseMobilePush.settings)
      @settings = settings
    end

    def register(user:, registration:)
      write_registration(user, registration)
    rescue ActiveRecord::RecordNotUnique
      write_registration(user, registration)
    end

    def devices_for(user:) = most_recent_first(live_devices.where(user:))

    def unregister_by_id(user:, device_id:) = Device.where(user:, id: device_id).delete_all > 0

    def unregister_by_token(user:, token:) = Device.where(user:, token:).delete_all > 0

    def remove_all_for(user:) = Device.where(user:).delete_all

    def remove(device:) = Device.where(id: device.id).delete_all > 0

    def remove_signed_out = Device.where.not(id: live_devices.select(:id)).delete_all

    def invalidate(device:) = remove(device:)

    def find(device_id:) = live_devices.includes(:user).find_by(id: device_id)

    def device_count = live_devices.count

    def counts
      Counts.new(
        total: live_devices.count,
        stale: live_devices.where(last_seen_at: ...@settings.stale_device_days.days.ago).count,
        by_platform: live_devices.group(:platform).count,
        by_app_version: app_version_counts,
      )
    end

    def search(owners: nil, page: 0)
      scope = owners ? live_devices.where(user: owners) : live_devices
      devices =
        most_recent_first(scope).includes(:user).offset(page * PAGE_SIZE).limit(PAGE_SIZE).to_a
      Page.new(devices:, total_rows: scope.count, page:)
    end

    private

    def live_devices = Device.with_live_credential

    def most_recent_first(scope) = scope.order(last_seen_at: :desc, id: :desc)

    def app_version_counts
      live_devices
        .group(:app_id, :app_version)
        .order(:app_id, :app_version)
        .count
        .map { |(app_id, app_version), count| AppVersionCount.new(app_id:, app_version:, count:) }
    end

    def write_registration(user, registration)
      Device.transaction(requires_new: true) do
        device = find_existing(user, registration) || Device.new
        created = device.new_record?
        device.assign_attributes(user:, last_seen_at: Time.zone.now, **registration.to_h)
        ensure_app_allowed!(device)
        release_device_identifier(device)
        device.save!
        evict_beyond_cap(user)
        Result.new(device:, created:)
      end
    end

    def find_existing(user, registration)
      Device.find_by(token: registration.token) || find_by_device_identifier(user, registration)
    end

    def find_by_device_identifier(user, registration)
      return if registration.device_identifier.blank?

      Device.find_by(
        user:,
        app_id: registration.app_id,
        device_identifier: registration.device_identifier,
      )
    end

    def ensure_app_allowed!(device)
      allowed_app_ids = @settings.allowed_app_ids
      return if allowed_app_ids.empty? || allowed_app_ids.include?(device.app_id)

      device.errors.add(:app_id, :inclusion)
      raise ActiveRecord::RecordInvalid, device
    end

    def release_device_identifier(device)
      return if device.device_identifier.blank?

      conflicting =
        Device.where(
          user_id: device.user_id,
          app_id: device.app_id,
          device_identifier: device.device_identifier,
        )
      conflicting = conflicting.where.not(id: device.id) if device.persisted?
      conflicting.delete_all
    end

    def evict_beyond_cap(user)
      live_ids = most_recent_first(live_devices.where(user:)).pluck(:id)
      signed_out_ids = most_recent_first(Device.where(user:).where.not(id: live_ids)).pluck(:id)
      surplus_ids = (live_ids + signed_out_ids).drop(@settings.max_devices_per_user)
      Device.where(id: surplus_ids).delete_all if surplus_ids.any?
    end
  end
end
