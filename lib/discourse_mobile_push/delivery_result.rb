# frozen_string_literal: true

module DiscourseMobilePush
  DeliveryResult = Data.define(:outcome, :detail, :retry_after)

  class DeliveryResult
    OUTCOMES = %i[delivered invalid_device retryable config_error rejected].freeze

    def initialize(outcome:, detail: nil, retry_after: nil)
      raise ArgumentError, "unknown outcome: #{outcome.inspect}" if OUTCOMES.exclude?(outcome)

      super(outcome:, detail:, retry_after:)
    end

    OUTCOMES.each { |name| define_method(:"#{name}?") { outcome == name } }
  end
end
