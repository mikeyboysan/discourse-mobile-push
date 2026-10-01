# frozen_string_literal: true

module DiscourseMobilePush
  class AdminDeviceSerializer < DeviceSerializer
    attributes :user_id,
               :username,
               :last_delivered_at,
               :last_failure_at,
               :last_failure_reason,
               :stale

    def username = object.user.username

    def stale = object.stale?(days: DiscourseMobilePush.settings.stale_device_days)
  end
end
