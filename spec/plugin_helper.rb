# frozen_string_literal: true

module MobilePushSpecHelpers
  FCM_TOKEN_URL = "https://oauth2.googleapis.com/token"
  FCM_PROJECT_ID = "example-project"

  def self.rsa_key = @rsa_key ||= OpenSSL::PKey::RSA.new(2048)

  def fcm_private_key = MobilePushSpecHelpers.rsa_key

  def fcm_service_account_fields(**overrides)
    {
      type: "service_account",
      project_id: FCM_PROJECT_ID,
      private_key_id: "key-id-1",
      private_key: fcm_private_key.to_pem,
      client_email: "push@example-project.iam.gserviceaccount.com",
      token_uri: FCM_TOKEN_URL,
    }.merge(overrides).compact
  end

  def fcm_service_account_json(**overrides) = fcm_service_account_fields(**overrides).to_json

  def fcm_send_url(project_id = FCM_PROJECT_ID)
    "https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send"
  end

  def stub_fcm_access_token(access_token: "access-token", expires_in: 3599)
    stub_request(:post, FCM_TOKEN_URL).to_return(
      status: 200,
      body: { access_token:, expires_in:, token_type: "Bearer" }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  def fcm_error_body(status:, http_status:, message: "error", error_code: nil, field: nil)
    details = []
    if error_code
      details << {
        "@type" => "type.googleapis.com/google.firebase.fcm.v1.FcmError",
        "errorCode" => error_code,
      }
    end
    if field
      details << {
        "@type" => "type.googleapis.com/google.rpc.BadRequest",
        "fieldViolations" => [{ field:, description: "invalid" }],
      }
    end
    { error: { code: http_status, message:, status:, details: } }.to_json
  end
end

class MobilePushFakeProvider < DiscourseMobilePush::PushProvider
  attr_reader :deliveries

  def initialize(outcome: :delivered, detail: nil, retry_after: nil, configured: true)
    @result = DiscourseMobilePush::DeliveryResult.new(outcome:, detail:, retry_after:)
    @configured = configured
    @deliveries = []
  end

  def configured? = @configured

  def deliver(message:, token:)
    @deliveries << { message:, token: }
    @result
  end
end

RSpec.configure { |config| config.include MobilePushSpecHelpers }
