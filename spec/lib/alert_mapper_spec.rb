# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::AlertMapper do
  let(:base_url) { "http://test.localhost" }
  let(:payload) do
    {
      notification_type: Notification.types[:replied],
      post_number: 2,
      topic_title: "Hello world",
      topic_id: 10,
      post_id: 20,
      excerpt: "A reply",
      username: "jane",
      post_url: "/t/hello-world/10/2",
      actions: [{ action: "reply" }],
    }
  end

  def alert_for(base: base_url, **overrides)
    described_class.from_payload(payload.merge(overrides), base_url: base)
  end

  describe ".from_payload" do
    it "maps a post alert payload" do
      expect(alert_for).to have_attributes(
        notification_type: "replied",
        notification_type_id: Notification.types[:replied],
        url: "http://test.localhost/t/hello-world/10/2",
        slug_free_url: "http://test.localhost/t/10/2",
        topic_id: 10,
        topic_title: "Hello world",
        post_number: 2,
        post_id: 20,
        channel_id: nil,
        username: "jane",
        group_name: nil,
        excerpt: "A reply",
        translated_title: nil,
      )
    end

    it "accepts string keys, as after a job round-trip" do
      alert = described_class.from_payload(payload.deep_stringify_keys, base_url:)

      expect(alert).to have_attributes(notification_type: "replied", topic_id: 10)
    end

    it "maps a chat alert payload" do
      chat_payload = {
        notification_type: Notification.types[:chat_mention],
        channel_id: 5,
        post_url: "/chat/c/secret-plans/5/99",
        translated_title: "Jane mentioned you in #general",
      }

      alert = described_class.from_payload(chat_payload, base_url:)

      expect(alert).to have_attributes(
        notification_type: "chat_mention",
        channel_id: 5,
        url: "http://test.localhost/chat/c/secret-plans/5/99",
        slug_free_url: "http://test.localhost/chat/c/-/5/99",
        translated_title: "Jane mentioned you in #general",
      )
    end

    it "links to a topic without its slug when there is no post number" do
      expect(alert_for(post_number: nil).slug_free_url).to eq("http://test.localhost/t/10")
    end

    it "keeps the site's path prefix in the slug-free link" do
      alert = alert_for(post_url: "/forum/t/x/10/2", base: "http://test.localhost/forum")

      expect(alert.slug_free_url).to eq("http://test.localhost/forum/t/10/2")
    end

    it "has no slug-free link for other notifications" do
      alert = alert_for(topic_id: nil, post_url: "/badges/1/first-like")

      expect(alert.slug_free_url).to be_nil
    end

    it "names unknown notification types 'unknown'" do
      expect(alert_for(notification_type: 9999).notification_type).to eq("unknown")
    end

    it "keeps the site's path prefix in subfolder installs" do
      alert = alert_for(post_url: "/forum/t/x/10/2", base: "http://test.localhost/forum")

      expect(alert.url).to eq("http://test.localhost/forum/t/x/10/2")
    end

    it "keeps absolute URLs on the site's host" do
      expect(alert_for(post_url: "http://test.localhost/t/x/1").url).to eq(
        "http://test.localhost/t/x/1",
      )
    end

    [
      "https://evil.example.com/t/1",
      "//evil.example.com/t/1",
      "javascript:alert(1)",
      "",
    ].each do |url|
      it "drops the URL #{url.inspect}" do
        expect(alert_for(post_url: url).url).to be_nil
      end
    end

    it "drops a URL on the same host but a different port" do
      expect(alert_for(post_url: "http://test.localhost:8080/t/1").url).to be_nil
    end
  end

  describe ".relevant_fields" do
    it "keeps only the fields the mapper reads, with string keys" do
      fields = described_class.relevant_fields(payload)

      expect(fields.keys).to match_array(
        %w[notification_type post_number topic_title topic_id post_id excerpt username post_url],
      )
    end
  end
end
