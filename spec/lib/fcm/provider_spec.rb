# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::Fcm::Provider do
  subject(:provider) { described_class.new }

  let(:message) do
    DiscourseMobilePush::PushMessage.new(
      title: "New reply",
      body: "Someone replied",
      data: {
        "url" => "/t/1",
      },
      priority: :high,
    )
  end
  let(:device_token) { "device-token-123" }

  before { SiteSetting.mobile_push_firebase_service_account_json = fcm_service_account_json }

  def deliver = provider.deliver(message:, token: device_token)

  describe "#configured?" do
    it "is true with valid credentials" do
      expect(provider).to be_configured
    end

    it "is false without credentials" do
      SiteSetting.mobile_push_firebase_service_account_json = ""

      expect(provider).not_to be_configured
    end

    it "is false with invalid credentials" do
      SiteSetting.mobile_push_firebase_service_account_json = "{}"

      expect(provider).not_to be_configured
    end
  end

  describe "#status" do
    it "reports the project id when the credentials are valid" do
      expect(provider.status).to have_attributes(
        configured: true,
        project_id: MobilePushSpecHelpers::FCM_PROJECT_ID,
        error: nil,
      )
    end

    it "prefers the project id override" do
      SiteSetting.mobile_push_firebase_project_id = "override-project"

      expect(provider.status.project_id).to eq("override-project")
    end

    it "reports the credential error without exposing the key" do
      SiteSetting.mobile_push_firebase_service_account_json =
        fcm_service_account_json(private_key: "not a key")

      status = provider.status

      expect(status).to have_attributes(configured: false, project_id: nil)
      expect(status.error).to be_present
      expect(status.error).not_to include("not a key")
    end
  end

  describe "#deliver" do
    it "sends the message to FCM with a bearer access token" do
      stub_fcm_access_token(access_token: "abc")
      send_stub =
        stub_request(:post, fcm_send_url).with(
          headers: {
            "Authorization" => "Bearer abc",
          },
          body: hash_including("message" => hash_including("token" => device_token)),
        ).to_return(status: 200, body: '{"name":"projects/example-project/messages/1"}')

      expect(deliver).to be_delivered
      expect(send_stub).to have_been_requested
    end

    it "sends to the overridden project id" do
      SiteSetting.mobile_push_firebase_project_id = "override-project"
      stub_fcm_access_token
      send_stub =
        stub_request(:post, fcm_send_url("override-project")).to_return(status: 200, body: "{}")

      deliver

      expect(send_stub).to have_been_requested
    end

    it "refreshes the access token and retries once on 401" do
      token_stub =
        stub_request(:post, MobilePushSpecHelpers::FCM_TOKEN_URL).to_return(
          { status: 200, body: { access_token: "stale", expires_in: 3599 }.to_json },
          { status: 200, body: { access_token: "fresh", expires_in: 3599 }.to_json },
        )
      stub_request(:post, fcm_send_url).with(
        headers: {
          "Authorization" => "Bearer stale",
        },
      ).to_return(status: 401, body: fcm_error_body(status: "UNAUTHENTICATED", http_status: 401))
      fresh_send =
        stub_request(:post, fcm_send_url).with(
          headers: {
            "Authorization" => "Bearer fresh",
          },
        ).to_return(status: 200, body: "{}")

      expect(deliver).to be_delivered
      expect(token_stub).to have_been_requested.twice
      expect(fresh_send).to have_been_requested.once
    end

    it "reports a configuration error when 401 persists after refreshing" do
      stub_fcm_access_token
      send_stub =
        stub_request(:post, fcm_send_url).to_return(
          status: 401,
          body: fcm_error_body(status: "UNAUTHENTICATED", http_status: 401),
        )

      expect(deliver).to be_config_error
      expect(send_stub).to have_been_requested.twice
    end

    it "classifies FCM errors" do
      stub_fcm_access_token
      stub_request(:post, fcm_send_url).to_return(
        status: 404,
        body: fcm_error_body(status: "NOT_FOUND", http_status: 404, error_code: "UNREGISTERED"),
      )

      expect(deliver).to be_invalid_device
    end

    it "scrubs the device token from the failure detail" do
      stub_fcm_access_token
      stub_request(:post, fcm_send_url).to_return(
        status: 400,
        body:
          fcm_error_body(
            status: "INVALID_ARGUMENT",
            http_status: 400,
            message: "Bad token #{device_token}",
          ),
      )

      detail = deliver.detail

      expect(detail).not_to include(device_token)
      expect(detail).to include(described_class::TOKEN_PLACEHOLDER)
    end

    it "reports a configuration error for invalid credentials without contacting Google" do
      SiteSetting.mobile_push_firebase_service_account_json = "not json"

      result = deliver

      expect(result).to be_config_error
      expect(result.detail).to eq("service account JSON is not valid JSON")
      expect(a_request(:any, /googleapis\.com/)).not_to have_been_made
    end

    it "reports a configuration error when the token grant is rejected" do
      stub_request(:post, MobilePushSpecHelpers::FCM_TOKEN_URL).to_return(
        status: 400,
        body: { error: "invalid_grant" }.to_json,
      )

      expect(deliver).to be_config_error
    end

    it "reports a retryable failure when the token endpoint is unavailable" do
      stub_request(:post, MobilePushSpecHelpers::FCM_TOKEN_URL).to_return(status: 503)

      expect(deliver).to be_retryable
    end

    it "reports a retryable failure on network errors" do
      stub_fcm_access_token
      stub_request(:post, fcm_send_url).to_timeout

      expect(deliver).to be_retryable
    end
  end

  it "implements the PushProvider port" do
    expect(provider).to be_a(DiscourseMobilePush::PushProvider)
  end
end
