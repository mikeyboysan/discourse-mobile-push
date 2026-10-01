# frozen_string_literal: true

module DiscourseMobilePush
  PushMessage = Data.define(:title, :body, :data, :priority)

  class PushMessage
    PRIORITIES = %i[normal high].freeze

    def initialize(title:, body:, data:, priority:)
      raise ArgumentError, "unknown priority: #{priority.inspect}" if PRIORITIES.exclude?(priority)
      if !data.all? { |key, value| key.is_a?(String) && value.is_a?(String) }
        raise ArgumentError, "data keys and values must be strings"
      end

      super(title:, body:, data: data.freeze, priority:)
    end

    def high_priority? = priority == :high
  end
end
