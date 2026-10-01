# frozen_string_literal: true

RSpec.describe "Delivering a Discourse notification to a mobile device" do
  fab!(:topic_owner, :user)
  fab!(:replier, :user)
  fab!(:topic) { Fabricate(:topic, user: topic_owner) }
  fab!(:first_post) { Fabricate(:post, topic:, user: topic_owner) }
  let!(:device) { Fabricate(:mobile_push_device, user: topic_owner, token: "owner-device-token") }

  before do
    Jobs.run_immediately!
    SiteSetting.mobile_push_enabled = true
    SiteSetting.mobile_push_firebase_service_account_json = fcm_service_account_json
    stub_fcm_access_token
  end

  it "sends a reply notification to the topic owner's device through FCM" do
    send_stub =
      stub_request(:post, fcm_send_url).with(
        body:
          hash_including(
            "message" =>
              hash_including(
                "token" => "owner-device-token",
                "data" =>
                  hash_including(
                    "type" => "notification",
                    "notification_type" => "replied",
                    "topic_id" => topic.id.to_s,
                  ),
              ),
          ),
      ).to_return(status: 200, body: '{"name":"projects/example-project/messages/1"}')

    PostCreator.create!(
      replier,
      topic_id: topic.id,
      raw: "This is a reply to your topic",
      reply_to_post_number: 1,
    )

    expect(send_stub).to have_been_requested.once
    expect(device.reload.last_delivered_at).to be_present
  end

  it "removes the device when FCM reports the token unregistered" do
    stub_request(:post, fcm_send_url).to_return(
      status: 404,
      body: fcm_error_body(status: "NOT_FOUND", http_status: 404, error_code: "UNREGISTERED"),
    )

    PostCreator.create!(
      replier,
      topic_id: topic.id,
      raw: "This is a reply to your topic",
      reply_to_post_number: 1,
    )

    expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
  end
end
