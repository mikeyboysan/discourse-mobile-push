# frozen_string_literal: true

module DiscourseMobilePush
  module Fcm
    ServiceAccount =
      Data.define(:project_id, :client_email, :private_key, :private_key_id, :token_uri)

    class ServiceAccount
      DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token"
      TOKEN_HOST_SUFFIX = ".googleapis.com"
      FINGERPRINT_LENGTH = 16

      class << self
        def parse(json, project_id_override: nil)
          fields = parse_fields(json)
          new(
            project_id: project_id_override.presence || required(fields, "project_id"),
            client_email: required(fields, "client_email"),
            private_key: parse_private_key(required(fields, "private_key")),
            private_key_id: fields["private_key_id"].presence,
            token_uri: validated_token_uri(fields["token_uri"].presence || DEFAULT_TOKEN_URI),
          )
        end

        private

        def parse_fields(json)
          raise InvalidCredentials, "service account JSON is missing" if json.blank?

          fields = JSON.parse(json)
          raise InvalidCredentials, "service account JSON must be an object" if !fields.is_a?(Hash)
          fields
        rescue JSON::ParserError
          raise InvalidCredentials, "service account JSON is not valid JSON"
        end

        def required(fields, key)
          value = fields[key]
          if !value.is_a?(String) || value.blank?
            raise InvalidCredentials, "service account JSON is missing #{key}"
          end
          value
        end

        def parse_private_key(pem)
          key = OpenSSL::PKey::RSA.new(pem)
          if !key.private?
            raise InvalidCredentials, "service account private_key is not a private key"
          end
          key
        rescue OpenSSL::PKey::PKeyError
          raise InvalidCredentials, "service account private_key is not a valid RSA key"
        end

        def validated_token_uri(token_uri)
          uri = URI.parse(token_uri)
          if uri.scheme != "https" || !uri.host.to_s.end_with?(TOKEN_HOST_SUFFIX)
            raise InvalidCredentials,
                  "service account token_uri must be an https googleapis.com URL"
          end
          token_uri
        rescue URI::InvalidURIError
          raise InvalidCredentials, "service account token_uri is not a valid URL"
        end
      end

      def fingerprint
        Digest::SHA256.hexdigest("#{client_email}\n#{private_key.public_to_der}").first(
          FINGERPRINT_LENGTH,
        )
      end
    end
  end
end
