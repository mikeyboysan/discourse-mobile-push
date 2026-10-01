# frozen_string_literal: true

module DiscourseMobilePush
  module Fcm
    class RequestBuilder
      def self.build(message:, token:)
        {
          message: {
            token:,
            notification: {
              title: message.title,
              body: message.body,
            },
            data: message.data,
            android: {
              priority: message.high_priority? ? "high" : "normal",
            },
          },
        }
      end
    end
  end
end
