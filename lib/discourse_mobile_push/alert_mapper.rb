# frozen_string_literal: true

module DiscourseMobilePush
  class AlertMapper
    PAYLOAD_KEYS = %w[
      notification_type
      post_url
      topic_id
      topic_title
      post_number
      post_id
      channel_id
      username
      group_name
      excerpt
      translated_title
    ].freeze
    UNKNOWN_NOTIFICATION_TYPE = "unknown"
    URL_SCHEMES = %w[http https].freeze

    class << self
      def relevant_fields(payload) = payload.to_h.stringify_keys.slice(*PAYLOAD_KEYS)

      def from_payload(payload, base_url:)
        fields = relevant_fields(payload)
        Alert.new(
          notification_type: notification_type_name(fields["notification_type"]),
          notification_type_id: fields["notification_type"],
          url: same_site_url(fields["post_url"], base_url),
          topic_id: fields["topic_id"],
          topic_title: fields["topic_title"],
          post_number: fields["post_number"],
          post_id: fields["post_id"],
          channel_id: fields["channel_id"],
          username: fields["username"],
          group_name: fields["group_name"],
          excerpt: fields["excerpt"],
          translated_title: fields["translated_title"],
        )
      end

      private

      def notification_type_name(type_id)
        Notification.types[type_id]&.to_s || UNKNOWN_NOTIFICATION_TYPE
      end

      def same_site_url(url, base_url)
        return if !url.is_a?(String) || url.blank?

        site = URI.parse(base_url)
        absolute = URI.join(base_url, url)
        same_site =
          URL_SCHEMES.include?(absolute.scheme) && absolute.host == site.host &&
            absolute.port == site.port
        absolute.to_s if same_site
      rescue URI::Error
        nil
      end
    end
  end
end
