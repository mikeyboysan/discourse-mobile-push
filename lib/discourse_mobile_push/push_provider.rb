# frozen_string_literal: true

module DiscourseMobilePush
  class PushProvider
    def status = raise NotImplementedError

    def configured? = status.configured

    def deliver(message:, token:) = raise NotImplementedError
  end
end
