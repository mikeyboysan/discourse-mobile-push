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

    # Credential columns reference core tables without foreign keys; a device registered with a
    # User API key or session stops receiving pushes once that credential is revoked or gone.
    def self.with_live_credential
      where(user_api_key_id: nil).or(where(user_api_key_id: UserApiKey.active.select(:id))).and(
        where(user_auth_token_id: nil).or(
          where(user_auth_token_id: UserAuthToken.unexpired.select(:id)),
        ),
      )
    end

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

# == Schema Information
#
# Table name: mobile_push_devices
#
#  id                  :bigint           not null, primary key
#  app_version         :string
#  device_identifier   :string
#  last_delivered_at   :datetime
#  last_failure_at     :datetime
#  last_failure_reason :string
#  last_seen_at        :datetime         not null
#  platform            :string           not null
#  token               :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  app_id              :string           not null
#  user_api_key_id     :bigint
#  user_auth_token_id  :bigint
#  user_id             :integer          not null
#
# Indexes
#
#  idx_mobile_push_devices_on_user_app_device             (user_id,app_id,device_identifier) UNIQUE WHERE (device_identifier IS NOT NULL)
#  index_mobile_push_devices_on_token                     (token) UNIQUE
#  index_mobile_push_devices_on_user_id_and_last_seen_at  (user_id,last_seen_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
