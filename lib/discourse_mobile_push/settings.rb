# frozen_string_literal: true

module DiscourseMobilePush
  class Settings
    def self.current = new

    def enabled? = SiteSetting.mobile_push_enabled

    def privacy_mode = SiteSetting.mobile_push_privacy_mode.to_sym

    def high_priority_notification_types =
      SiteSetting.mobile_push_high_priority_notification_types_map

    def max_devices_per_user = SiteSetting.mobile_push_max_devices_per_user

    def allowed_app_ids = SiteSetting.mobile_push_allowed_app_ids_map

    def stale_device_days = SiteSetting.mobile_push_stale_device_days

    def firebase_service_account_json = SiteSetting.mobile_push_firebase_service_account_json

    def firebase_project_id_override = SiteSetting.mobile_push_firebase_project_id.presence

    def base_url = Discourse.base_url

    def site_title = SiteSetting.title
  end
end
