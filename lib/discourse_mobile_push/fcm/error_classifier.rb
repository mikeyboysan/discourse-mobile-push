# frozen_string_literal: true

module DiscourseMobilePush
  module Fcm
    class ErrorClassifier
      UNREGISTERED_CODE = "UNREGISTERED"
      TOKEN_FIELD = "message.token"
      MAX_DETAIL_LENGTH = 200
      RETRY_AFTER_FORMAT = /\A\d+\z/

      def self.classify(response:) = new(response).classify

      def initialize(response)
        @response = response
        @error = parse_error(response.body)
      end

      def classify
        return DeliveryResult.new(outcome: :delivered) if @response.status == 200

        outcome = failure_outcome
        DeliveryResult.new(outcome:, detail:, retry_after: (retry_after if outcome == :retryable))
      end

      private

      def failure_outcome
        return :invalid_device if fcm_error_code == UNREGISTERED_CODE

        case @response.status
        when 400
          token_field_violation? ? :invalid_device : :rejected
        when 401, 403, 404
          :config_error
        when 429, 500..599
          :retryable
        else
          :rejected
        end
      end

      def parse_error(body)
        error = JSON.parse(body)["error"]
        error.is_a?(Hash) ? error : {}
      rescue JSON::ParserError, TypeError
        {}
      end

      def details = Array(@error["details"]).grep(Hash)

      def fcm_error_code = details.filter_map { |item| item["errorCode"] }.first

      def token_field_violation?
        details.any? do |item|
          Array(item["fieldViolations"])
            .grep(Hash)
            .any? { |violation| violation["field"] == TOKEN_FIELD }
        end
      end

      def detail
        code = fcm_error_code || @error["status"]
        summary = ["HTTP #{@response.status}", code].compact.join(" ")
        message = @error["message"]
        (message.is_a?(String) ? "#{summary}: #{message}" : summary).truncate(MAX_DETAIL_LENGTH)
      end

      def retry_after
        value = @response.headers["retry-after"].to_s.strip
        value.to_i if value.match?(RETRY_AFTER_FORMAT)
      end
    end
  end
end
