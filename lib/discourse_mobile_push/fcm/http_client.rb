# frozen_string_literal: true

module DiscourseMobilePush
  module Fcm
    class HttpClient
      Response = Data.define(:status, :body, :headers)

      class NetworkError < Error
      end

      OPEN_TIMEOUT_SECONDS = 5
      READ_TIMEOUT_SECONDS = 10
      WRITE_TIMEOUT_SECONDS = 10
      NETWORK_ERRORS = [
        Net::OpenTimeout,
        Net::ReadTimeout,
        Net::WriteTimeout,
        Net::HTTPBadResponse,
        OpenSSL::SSL::SSLError,
        SocketError,
        SystemCallError,
        IOError,
      ].freeze

      def post_json(url:, body:, headers: {})
        post(url, body.to_json, headers.merge("Content-Type" => "application/json"))
      end

      def post_form(url:, form:)
        post(
          url,
          URI.encode_www_form(form),
          { "Content-Type" => "application/x-www-form-urlencoded" },
        )
      end

      private

      def post(url, payload, headers)
        uri = URI.parse(url)
        response =
          Net::HTTP.start(
            uri.host,
            uri.port,
            use_ssl: uri.scheme == "https",
            open_timeout: OPEN_TIMEOUT_SECONDS,
            read_timeout: READ_TIMEOUT_SECONDS,
            write_timeout: WRITE_TIMEOUT_SECONDS,
          ) { |http| http.post(uri.request_uri, payload, headers) }

        Response.new(
          status: response.code.to_i,
          body: response.body.to_s,
          headers: response.each_header.to_h,
        )
      rescue *NETWORK_ERRORS => e
        raise NetworkError, "#{e.class.name} while contacting #{uri&.host}"
      end
    end
  end
end
