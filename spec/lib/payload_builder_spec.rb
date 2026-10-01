# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::PayloadBuilder do
  subject(:builder) { described_class.new }

  let(:generic_body) { "You have a new notification" }

  before { SiteSetting.title = "Test Forum" }

  def alert(**overrides)
    DiscourseMobilePush::Alert.new(
      **{
        notification_type: "replied",
        notification_type_id: Notification.types[:replied],
        url: "http://test.localhost/t/hello/10/2",
        topic_id: 10,
        topic_title: "Hello",
        post_number: 2,
        post_id: 20,
        channel_id: nil,
        username: "jane",
        group_name: nil,
        excerpt: "A reply",
        translated_title: nil,
      }.merge(overrides),
    )
  end

  def build(locale: "en", **overrides) = builder.build(alert: alert(**overrides), locale:)

  context "with full privacy mode" do
    it "uses Discourse's push title for the notification type" do
      expect(build.title).to eq('jane replied to you in "Hello" - Test Forum')
    end

    it "uses the new-topic title for a first post in a watched category or tag" do
      message = build(notification_type: "watching_category_or_tag", post_number: 1)

      expect(message.title).to eq('jane created a new topic "Hello" - Test Forum')
    end

    it "uses the posted title for a reply in a watched category or tag" do
      message = build(notification_type: "watching_category_or_tag", post_number: 3)

      expect(message.title).to eq('jane posted in "Hello" - Test Forum')
    end

    it "prefers a pre-translated title" do
      expect(build(translated_title: "Jane mentioned you").title).to eq("Jane mentioned you")
    end

    it "falls back to the site title for types without a push title" do
      expect(build(notification_type: "unknown").title).to eq("Test Forum")
    end

    it "falls back to the site title when the push title translation is nested" do
      expect(build(notification_type: "chat_mention").title).to eq("Test Forum")
    end

    it "uses the excerpt as the body" do
      expect(build.body).to eq("A reply")
    end

    it "falls back to the generic body without an excerpt" do
      expect(build(excerpt: nil).body).to eq(generic_body)
    end
  end

  context "with generic privacy mode" do
    before { SiteSetting.mobile_push_privacy_mode = "generic" }

    it "hides the title and body text" do
      message = build(translated_title: "Jane mentioned you")

      expect(message).to have_attributes(title: "Test Forum", body: generic_body)
    end

    it "keeps the navigation data" do
      expect(build.data["url"]).to eq("http://test.localhost/t/hello/10/2")
    end
  end

  it "truncates long titles and bodies" do
    message = build(translated_title: "t" * 1000, excerpt: "b" * 2000)

    expect(message.title.length).to eq(described_class::MAX_TITLE_LENGTH)
    expect(message.body.length).to eq(described_class::MAX_BODY_LENGTH)
  end

  it "translates into the given locale" do
    TranslationOverride.upsert!("de", described_class::GENERIC_BODY_TRANSLATION, "Neu")

    expect(build(locale: "de", excerpt: nil).body).to eq("Neu")
  end

  describe "data" do
    it "carries identifiers and the URL as strings" do
      expect(build.data).to eq(
        "type" => "notification",
        "notification_type" => "replied",
        "notification_type_id" => Notification.types[:replied].to_s,
        "url" => "http://test.localhost/t/hello/10/2",
        "topic_id" => "10",
        "post_number" => "2",
        "post_id" => "20",
      )
    end

    it "includes the chat channel for chat alerts" do
      message =
        build(
          notification_type: "chat_mention",
          topic_id: nil,
          post_number: nil,
          post_id: nil,
          channel_id: 5,
        )

      expect(message.data).to include("channel_id" => "5")
      expect(message.data.keys).not_to include("topic_id", "post_number", "post_id")
    end

    it "falls back to the site URL when the alert has none" do
      expect(build(url: nil).data["url"]).to eq(Discourse.base_url)
    end
  end

  describe "priority" do
    it "is high for configured notification types" do
      expect(build(notification_type: "private_message").priority).to eq(:high)
    end

    it "is normal for other notification types" do
      expect(build.priority).to eq(:normal)
    end
  end

  describe "#build_test" do
    it "builds a high-priority test message that opens the site" do
      message = builder.build_test(locale: "en")

      expect(message).to have_attributes(
        title: "Test Forum",
        body: "This is a test notification. Push notifications are working.",
        data: {
          "type" => "test",
          "url" => Discourse.base_url,
        },
        priority: :high,
      )
    end

    it "uses the same text in generic privacy mode" do
      SiteSetting.mobile_push_privacy_mode = "generic"

      expect(builder.build_test(locale: "en").body).to eq(
        "This is a test notification. Push notifications are working.",
      )
    end

    it "translates into the given locale" do
      TranslationOverride.upsert!("de", described_class::TEST_BODY_TRANSLATION, "Test")

      expect(builder.build_test(locale: "de").body).to eq("Test")
    end
  end
end
