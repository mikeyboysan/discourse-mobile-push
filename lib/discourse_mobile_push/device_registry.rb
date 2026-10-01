# frozen_string_literal: true

module DiscourseMobilePush
  class DeviceRegistry
    Registration = Data.define(:platform, :app_id, :token, :app_version, :device_identifier)
    Result = Data.define(:device, :created)

    def initialize(settings: DiscourseMobilePush.settings)
      @settings = settings
    end

    def register(user:, registration:)
      write_registration(user, registration)
    rescue ActiveRecord::RecordNotUnique
      write_registration(user, registration)
    end

    def devices_for(user:) = Device.where(user:).order(last_seen_at: :desc, id: :desc)

    def unregister_by_id(user:, device_id:) = Device.where(user:, id: device_id).delete_all > 0

    def unregister_by_token(user:, token:) = Device.where(user:, token:).delete_all > 0

    def remove_all_for(user:) = Device.where(user:).delete_all

    def invalidate(device:) = Device.where(id: device.id).delete_all

    private

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
      surplus_ids = devices_for(user:).offset(@settings.max_devices_per_user).pluck(:id)
      Device.where(id: surplus_ids).delete_all if surplus_ids.any?
    end
  end
end
