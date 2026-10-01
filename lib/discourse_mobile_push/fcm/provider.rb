# frozen_string_literal: true

module DiscourseMobilePush
  module Fcm
    class Provider < PushProvider
      SEND_URL_TEMPLATE = "https://fcm.googleapis.com/v1/projects/%<project_id>s/messages:send"
      TOKEN_PLACEHOLDER = "[device token]"

      def initialize(settings: DiscourseMobilePush.settings, http: HttpClient.new)
        @settings = settings
        @http = http
      end

      def configured?
        service_account
        true
      rescue InvalidCredentials
        false
      end

      def deliver(message:, token:)
        response = send_with_reauthentication(service_account, message, token)
        scrub_token(ErrorClassifier.classify(response:), token)
      rescue InvalidCredentials => e
        DeliveryResult.new(outcome: :config_error, detail: e.message)
      rescue AccessTokenSource::AuthError => e
        DeliveryResult.new(outcome: e.retryable? ? :retryable : :config_error, detail: e.message)
      rescue HttpClient::NetworkError => e
        DeliveryResult.new(outcome: :retryable, detail: e.message)
      end

      private

      def service_account
        ServiceAccount.parse(
          @settings.firebase_service_account_json,
          project_id_override: @settings.firebase_project_id_override,
        )
      end

      def send_with_reauthentication(account, message, token)
        access_tokens = AccessTokenSource.new(service_account: account, http: @http)
        response = send_message(account, access_tokens.token, message, token)
        return response if response.status != 401

        access_tokens.invalidate!
        send_message(account, access_tokens.token, message, token)
      end

      def send_message(account, access_token, message, token)
        @http.post_json(
          url: format(SEND_URL_TEMPLATE, project_id: ERB::Util.url_encode(account.project_id)),
          body: RequestBuilder.build(message:, token:),
          headers: {
            "Authorization" => "Bearer #{access_token}",
          },
        )
      end

      def scrub_token(result, token)
        return result if result.detail.nil?

        result.with(detail: result.detail.gsub(token, TOKEN_PLACEHOLDER))
      end
    end
  end
end
