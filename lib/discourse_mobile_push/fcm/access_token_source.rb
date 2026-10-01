# frozen_string_literal: true

module DiscourseMobilePush
  module Fcm
    class AccessTokenSource
      class AuthError < Error
        def initialize(message, retryable:)
          super(message)
          @retryable = retryable
        end

        def retryable? = @retryable
      end

      SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
      GRANT_TYPE = "urn:ietf:params:oauth:grant-type:jwt-bearer"
      ASSERTION_LIFETIME_SECONDS = 3600
      EXPIRY_MARGIN_SECONDS = 300
      MIN_CACHE_SECONDS = 60
      MAX_ERROR_DETAIL_LENGTH = 200
      CACHE_KEY_PREFIX = "discourse_mobile_push:fcm_access_token"

      def initialize(service_account:, http: HttpClient.new, cache: Discourse.redis)
        @service_account = service_account
        @http = http
        @cache = cache
      end

      def token = @cache.get(cache_key) || fetch_and_cache

      def invalidate! = @cache.del(cache_key)

      private

      def cache_key = "#{CACHE_KEY_PREFIX}:#{@service_account.fingerprint}"

      def fetch_and_cache
        access_token, expires_in = parse_grant(request_grant)
        @cache.setex(
          cache_key,
          [expires_in - EXPIRY_MARGIN_SECONDS, MIN_CACHE_SECONDS].max,
          access_token,
        )
        access_token
      end

      def request_grant
        @http.post_form(
          url: @service_account.token_uri,
          form: {
            grant_type: GRANT_TYPE,
            assertion: signed_assertion,
          },
        )
      rescue HttpClient::NetworkError => e
        raise AuthError.new("token request failed: #{e.message}", retryable: true)
      end

      def parse_grant(response)
        if response.status != 200
          raise AuthError.new(
                  grant_failure_detail(response),
                  retryable: retryable_status?(response.status),
                )
        end

        body = JSON.parse(response.body)
        access_token = body.fetch("access_token")
        raise unexpected_grant_error if !access_token.is_a?(String) || access_token.blank?
        [access_token, body.fetch("expires_in").to_i]
      rescue JSON::ParserError, KeyError, TypeError
        raise unexpected_grant_error
      end

      def unexpected_grant_error
        AuthError.new("token endpoint returned an unexpected response", retryable: true)
      end

      def grant_failure_detail(response)
        error = JSON.parse(response.body)
        reason =
          error.values_at("error", "error_description").grep(String).join(": ") if error.is_a?(Hash)
        "token request failed: HTTP #{response.status} #{reason}".strip.truncate(
          MAX_ERROR_DETAIL_LENGTH,
        )
      rescue JSON::ParserError
        "token request failed: HTTP #{response.status}"
      end

      def retryable_status?(status) = status == 429 || status >= 500

      def signed_assertion
        issued_at = Time.zone.now.to_i
        header = { alg: "RS256", typ: "JWT", kid: @service_account.private_key_id }.compact
        claims = {
          iss: @service_account.client_email,
          scope: SCOPE,
          aud: @service_account.token_uri,
          iat: issued_at,
          exp: issued_at + ASSERTION_LIFETIME_SECONDS,
        }
        signing_input = [header, claims].map { |part| base64url(part.to_json) }.join(".")
        signature = @service_account.private_key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
        "#{signing_input}.#{base64url(signature)}"
      end

      def base64url(bytes) = [bytes].pack("m0").tr("+/", "-_").delete("=")
    end
  end
end
