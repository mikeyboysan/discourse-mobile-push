# frozen_string_literal: true

module DiscourseMobilePush
  Alert =
    Data.define(
      :notification_type,
      :notification_type_id,
      :url,
      :slug_free_url,
      :topic_id,
      :topic_title,
      :post_number,
      :post_id,
      :channel_id,
      :username,
      :group_name,
      :excerpt,
      :translated_title,
    )
end
