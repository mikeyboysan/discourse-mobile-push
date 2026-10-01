# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::DevicesController do
  fab!(:user)
  fab!(:other_user, :user)

  let(:devices_scope) { "discourse-mobile-push:devices" }
  let(:device_params) do
    { platform: "android", app_id: "com.example.app", token: "push-token-1", app_version: "1.2.3" }
  end

  before { enable_current_plugin }

  def user_api_key_headers(scope)
    api_key =
      Fabricate(:user_api_key, user:, scopes: [Fabricate.build(:user_api_key_scope, name: scope)])
    { "User-Api-Key" => api_key.key }
  end

  shared_examples "an authenticated devices endpoint" do |success_status:|
    it "requires a logged-in user" do
      perform_request

      expect(response.status).to eq(403)
    end

    it "accepts a user API key with the devices scope" do
      perform_request(headers: user_api_key_headers(devices_scope))

      expect(response.status).to eq(success_status)
    end

    it "rejects a user API key without the devices scope" do
      perform_request(headers: user_api_key_headers("notifications"))

      expect(response.status).to eq(403)
    end
  end

  describe "POST /mobile-push/v1/devices" do
    def perform_request(headers: {})
      post "/mobile-push/v1/devices.json", params: device_params, headers:
    end

    it_behaves_like "an authenticated devices endpoint", success_status: 201

    it "is unavailable when the plugin is disabled" do
      SiteSetting.mobile_push_enabled = false
      sign_in(user)

      perform_request

      expect(response.status).to eq(404)
    end

    context "when signed in" do
      before { sign_in(user) }

      it "registers a device and returns it without the token" do
        perform_request

        expect(response.status).to eq(201)
        expect(response.parsed_body["device"]).to include(
          "platform" => "android",
          "app_id" => "com.example.app",
          "app_version" => "1.2.3",
          "token_fingerprint" => DiscourseMobilePush::Device.last.token_fingerprint,
        )
        expect(response.body).not_to include("push-token-1")
      end

      it "returns 200 when the device was already registered" do
        Fabricate(:mobile_push_device, user:, token: "push-token-1")

        perform_request

        expect(response.status).to eq(200)
      end

      it "rejects a token sent in the query string" do
        post "/mobile-push/v1/devices.json?token=push-token-1", params: device_params.except(:token)

        expect(response.status).to eq(400)
        expect(DiscourseMobilePush::Device.count).to eq(0)
      end

      it "rejects a missing token" do
        post "/mobile-push/v1/devices.json", params: device_params.except(:token)

        expect(response.status).to eq(400)
      end

      it "rejects a token that is not a string" do
        post "/mobile-push/v1/devices.json", params: device_params.merge(token: %w[a b])

        expect(response.status).to eq(400)
      end

      it "returns validation errors for an unknown platform" do
        post "/mobile-push/v1/devices.json", params: device_params.merge(platform: "windows")

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns validation errors for an app id outside the allowlist" do
        SiteSetting.mobile_push_allowed_app_ids = "com.example.other"

        perform_request

        expect(response.status).to eq(422)
      end

      context "with rate limiting enabled" do
        use_redis_snapshotting

        before { RateLimiter.enable }

        it "rejects registrations beyond the per-minute limit" do
          stub_const(described_class, "REGISTRATIONS_PER_MINUTE", 1) do
            post "/mobile-push/v1/devices.json", params: device_params
            post "/mobile-push/v1/devices.json", params: device_params.merge(token: "push-token-2")
          end

          expect(response.status).to eq(429)
        end
      end
    end
  end

  describe "GET /mobile-push/v1/devices" do
    def perform_request(headers: {})
      get "/mobile-push/v1/devices.json", headers:
    end

    it_behaves_like "an authenticated devices endpoint", success_status: 200

    it "lists only the current user's devices without tokens" do
      own = Fabricate(:mobile_push_device, user:, token: "own-token")
      Fabricate(:mobile_push_device, user: other_user)
      sign_in(user)

      perform_request

      expect(response.status).to eq(200)
      expect(response.parsed_body["devices"].map { |d| d["id"] }).to eq([own.id])
      expect(response.body).not_to include("own-token")
    end
  end

  describe "DELETE /mobile-push/v1/devices/:id" do
    let!(:device) { Fabricate(:mobile_push_device, user:) }

    def perform_request(headers: {})
      delete "/mobile-push/v1/devices/#{device.id}.json", headers:
    end

    it_behaves_like "an authenticated devices endpoint", success_status: 204

    it "removes the user's own device" do
      sign_in(user)

      perform_request

      expect(response.status).to eq(204)
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
    end

    it "returns 404 for another user's device and keeps it" do
      sign_in(other_user)

      perform_request

      expect(response.status).to eq(404)
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(true)
    end
  end

  describe "DELETE /mobile-push/v1/devices" do
    let!(:device) { Fabricate(:mobile_push_device, user:, token: "push-token-1") }

    def perform_request(headers: {})
      delete "/mobile-push/v1/devices.json", params: { token: "push-token-1" }, headers:
    end

    it_behaves_like "an authenticated devices endpoint", success_status: 204

    it "removes the user's device identified by the token in the body" do
      sign_in(user)

      perform_request

      expect(response.status).to eq(204)
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
    end

    it "rejects a token sent in the query string" do
      sign_in(user)

      delete "/mobile-push/v1/devices.json?token=push-token-1"

      expect(response.status).to eq(400)
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(true)
    end

    it "returns 404 for a token the user does not own" do
      sign_in(other_user)

      perform_request

      expect(response.status).to eq(404)
      expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(true)
    end
  end
end
