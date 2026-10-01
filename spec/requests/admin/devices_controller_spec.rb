# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::Admin::DevicesController do
  fab!(:admin)
  fab!(:user)

  before do
    enable_current_plugin
    SiteSetting.mobile_push_firebase_service_account_json = fcm_service_account_json
  end

  describe "GET /admin/mobile-push/devices.json" do
    def perform_request(params = {}) = get "/admin/mobile-push/devices.json", params: params

    include_examples "a mobile push admin-only endpoint"

    context "as an admin" do
      before { sign_in(admin) }

      it "lists devices with their owner and masked token" do
        device = Fabricate(:mobile_push_device, user:)

        perform_request

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json).to include("total_rows" => 1, "page" => 0)
        expect(json["devices"].sole).to include(
          "id" => device.id,
          "user_id" => user.id,
          "username" => user.username,
          "token_fingerprint" => device.token_fingerprint,
          "stale" => false,
        )
        expect(response.body).not_to include(device.token)
      end

      it "filters by username, case-insensitively" do
        own = Fabricate(:mobile_push_device, user:)
        Fabricate(:mobile_push_device)

        perform_request(username: user.username.upcase)

        expect(response.parsed_body["devices"].map { |d| d["id"] }).to eq([own.id])
      end

      it "matches Unicode usernames" do
        SiteSetting.unicode_usernames = true
        owner = Fabricate(:user, username: "Lörens")
        own = Fabricate(:mobile_push_device, user: owner)

        perform_request(username: "LÖRENS")

        expect(response.parsed_body["devices"].map { |d| d["id"] }).to eq([own.id])
      end

      it "returns no devices for an unknown username" do
        Fabricate(:mobile_push_device, user:)

        perform_request(username: "nobody")

        expect(response.parsed_body).to include("devices" => [], "total_rows" => 0)
      end

      it "returns the requested page" do
        Fabricate(:mobile_push_device, user:)

        perform_request(page: "1")

        expect(response.parsed_body).to include("devices" => [], "total_rows" => 1, "page" => 1)
      end

      [{ username: %w[a b] }, { page: %w[1 2] }, { page: "-1" }, { page: "x" }].each do |params|
        it "rejects invalid parameters #{params.inspect}" do
          perform_request(params)

          expect(response.status).to eq(400)
        end
      end
    end
  end

  describe "POST /admin/mobile-push/devices/:id/test.json" do
    let!(:device) { Fabricate(:mobile_push_device, user:) }
    let(:provider) { MobilePushFakeProvider.new }

    def perform_request(id: device.id) = post "/admin/mobile-push/devices/#{id}/test.json"

    before { DiscourseMobilePush.stubs(:interactive_provider).returns(provider) }

    include_examples "a mobile push admin-only endpoint"

    context "as an admin" do
      before { sign_in(admin) }

      it "sends a test notification to the device and reports the outcome" do
        perform_request

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq("outcome" => "delivered", "detail" => nil)
        expect(provider.deliveries.sole).to include(token: device.token)
        expect(provider.deliveries.sole[:message].data["type"]).to eq("test")
      end

      it "records the test send in the staff action log without the token" do
        perform_request

        log = UserHistory.where(custom_type: "mobile_push_test_send").sole
        expect(log.acting_user_id).to eq(admin.id)
        expect(log.details).to include(user.username, device.token_fingerprint, "delivered")
        expect(log.details).not_to include(device.token)
      end

      it "reports failures with their detail" do
        DiscourseMobilePush.stubs(:interactive_provider).returns(
          MobilePushFakeProvider.new(outcome: :config_error, detail: "HTTP 403"),
        )

        perform_request

        expect(response.parsed_body).to eq("outcome" => "config_error", "detail" => "HTTP 403")
      end

      it "removes the device when the token is invalid" do
        DiscourseMobilePush.stubs(:interactive_provider).returns(
          MobilePushFakeProvider.new(outcome: :invalid_device),
        )

        perform_request

        expect(response.parsed_body["outcome"]).to eq("invalid_device")
        expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
      end

      it "is not found for an unknown device" do
        perform_request(id: device.id + 1000)

        expect(response.status).to eq(404)
        expect(provider.deliveries).to be_empty
      end

      it "rate limits test sends" do
        RateLimiter.enable
        stub_const(described_class, :TEST_SENDS_PER_MINUTE, 1) do
          perform_request
          perform_request
        end

        expect(response.status).to eq(429)
        expect(provider.deliveries.size).to eq(1)
      end
    end
  end

  describe "test send through Firebase" do
    let!(:device) { Fabricate(:mobile_push_device, user:) }

    before { sign_in(admin) }

    it "delivers using the bounded interactive provider" do
      stub_fcm_access_token
      send_stub =
        stub_request(:post, fcm_send_url).with(
          body: hash_including("message" => hash_including("token" => device.token)),
        ).to_return(status: 200, body: '{"name":"projects/example-project/messages/1"}')

      post "/admin/mobile-push/devices/#{device.id}/test.json"

      expect(response.parsed_body["outcome"]).to eq("delivered")
      expect(send_stub).to have_been_requested
    end
  end
end
