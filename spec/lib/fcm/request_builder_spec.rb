# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::Fcm::RequestBuilder do
  def message(priority:)
    DiscourseMobilePush::PushMessage.new(
      title: "New reply",
      body: "Someone replied",
      data: {
        "url" => "/t/1",
      },
      priority:,
    )
  end

  it "builds an FCM v1 message for the token" do
    request = described_class.build(message: message(priority: :normal), token: "device-token")

    expect(request).to eq(
      message: {
        token: "device-token",
        notification: {
          title: "New reply",
          body: "Someone replied",
        },
        data: {
          "url" => "/t/1",
        },
        android: {
          priority: "normal",
        },
      },
    )
  end

  it "sets high Android priority for high-priority messages" do
    request = described_class.build(message: message(priority: :high), token: "device-token")

    expect(request.dig(:message, :android, :priority)).to eq("high")
  end
end
