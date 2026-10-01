# frozen_string_literal: true

module DiscourseMobilePush
  class PayloadBuilder
    MAX_TITLE_LENGTH = 150
    MAX_BODY_LENGTH = 500
    TITLE_TRANSLATION_PREFIX = "discourse_push_notifications.popup"
    GENERIC_BODY_TRANSLATION = "discourse_mobile_push.notification.generic_body"
    TEST_TITLE_TRANSLATION = "discourse_mobile_push.test_notification.title"
    TEST_BODY_TRANSLATION = "discourse_mobile_push.test_notification.body"
    WATCHING_CATEGORY_OR_TAG = "watching_category_or_tag"
    CHAT_CHANNEL_SLUG = %r{(/chat/c/)[^/]+/}

    def initialize(settings: DiscourseMobilePush.settings)
      @settings = settings
    end

    def build(alert:, locale:)
      I18n.with_locale(locale) do
        PushMessage.new(
          title: title_for(alert).truncate(MAX_TITLE_LENGTH),
          body: body_for(alert).truncate(MAX_BODY_LENGTH),
          data: data_for(alert),
          priority: priority_for(alert),
        )
      end
    end

    def build_test(locale:)
      I18n.with_locale(locale) do
        PushMessage.new(
          title:
            I18n.t(TEST_TITLE_TRANSLATION, site_title: @settings.site_title).truncate(
              MAX_TITLE_LENGTH,
            ),
          body: I18n.t(TEST_BODY_TRANSLATION).truncate(MAX_BODY_LENGTH),
          data: {
            "type" => "test",
            "url" => @settings.base_url,
          },
          priority: :high,
        )
      end
    end

    private

    def generic? = @settings.privacy_mode == :generic

    def title_for(alert)
      return @settings.site_title if generic?

      alert.translated_title.presence || popup_title(alert) || @settings.site_title
    end

    def body_for(alert)
      return generic_body if generic?

      alert.excerpt.presence || generic_body
    end

    def generic_body = I18n.t(GENERIC_BODY_TRANSLATION)

    def popup_title(alert)
      key = "#{TITLE_TRANSLATION_PREFIX}.#{popup_type(alert)}"
      return if !I18n.exists?(key)

      title =
        I18n.t(
          key,
          site_title: @settings.site_title,
          topic: alert.topic_title,
          username: alert.username,
          group_name: alert.group_name,
        )
      title if title.is_a?(String)
    end

    def popup_type(alert)
      return alert.notification_type if alert.notification_type != WATCHING_CATEGORY_OR_TAG

      alert.post_number.to_i == 1 ? "watching_first_post" : "posted"
    end

    def data_for(alert)
      {
        "type" => "notification",
        "notification_type" => alert.notification_type,
        "notification_type_id" => alert.notification_type_id,
        "url" => url_for(alert),
        "topic_id" => alert.topic_id,
        "post_number" => alert.post_number,
        "post_id" => alert.post_id,
        "channel_id" => alert.channel_id,
      }.compact.transform_values(&:to_s)
    end

    def url_for(alert)
      return alert.url || @settings.base_url if !generic?

      slug_free_url(alert)
    end

    # Slugs carry topic and channel titles, which generic mode keeps off the push services.
    def slug_free_url(alert)
      if alert.topic_id.present?
        "#{@settings.base_url}/t/#{[alert.topic_id, alert.post_number.presence].compact.join("/")}"
      elsif alert.url&.match?(CHAT_CHANNEL_SLUG)
        alert.url.sub(CHAT_CHANNEL_SLUG, '\1-/')
      else
        @settings.base_url
      end
    end

    def priority_for(alert)
      high = @settings.high_priority_notification_types.include?(alert.notification_type)
      high ? :high : :normal
    end
  end
end
