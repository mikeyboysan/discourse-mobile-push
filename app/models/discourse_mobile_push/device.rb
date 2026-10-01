# frozen_string_literal: true

module DiscourseMobilePush
  class Device < ActiveRecord::Base
    self.table_name = "mobile_push_devices"
    self.filter_attributes += [:token]

    PLATFORMS = %w[android ios].freeze
    MAX_TOKEN_LENGTH = 1024
    MAX_APP_VERSION_LENGTH = 50
    MAX_DEVICE_IDENTIFIER_LENGTH = 255
    MAX_FAILURE_REASON_LENGTH = 255
    APP_ID_FORMAT = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,254}\z/
    TOKEN_FORMAT = /\A\S+\z/
    FINGERPRINT_LENGTH = 12

    belongs_to :user

    validates :platform, inclusion: { in: PLATFORMS }
    validates :app_id, format: { with: APP_ID_FORMAT }
    validates :token,
              presence: true,
              length: {
                maximum: MAX_TOKEN_LENGTH,
              },
              format: {
                with: TOKEN_FORMAT,
                allow_blank: true,
              }
    validates :app_version, length: { maximum: MAX_APP_VERSION_LENGTH }
    validates :device_identifier, length: { maximum: MAX_DEVICE_IDENTIFIER_LENGTH }
    validates :last_seen_at, presence: true

    def token_fingerprint = Digest::SHA256.hexdigest(token).first(FINGERPRINT_LENGTH)

    def stale?(days:) = last_seen_at < days.days.ago

    def record_delivery!(at:) = update_columns(last_delivered_at: at)

    def record_failure!(reason:, at:)
      update_columns(
        last_failure_at: at,
        last_failure_reason: reason.to_s.truncate(MAX_FAILURE_REASON_LENGTH),
      )
    end
  end
end
