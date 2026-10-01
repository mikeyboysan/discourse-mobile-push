# frozen_string_literal: true

module DiscourseMobilePush
  class PushProvider
    def configured? = raise NotImplementedError

    def deliver(message:, token:) = raise NotImplementedError
  end
end
