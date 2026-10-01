# frozen_string_literal: true

module DiscourseMobilePush
  class DeviceSerializer < ::ApplicationSerializer
    attributes :id,
               :platform,
               :app_id,
               :app_version,
               :device_identifier,
               :token_fingerprint,
               :last_seen_at,
               :created_at
  end
end
