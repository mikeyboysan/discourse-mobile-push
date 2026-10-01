# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::Fcm::AccessTokenSource do
  subject(:source) { described_class.new(service_account:) }

  let(:service_account) { DiscourseMobilePush::Fcm::ServiceAccount.parse(fcm_service_account_json) }
  let(:auth_error) { described_class::AuthError }

  def base64url_decode(segment) = segment.tr("-_", "+/").unpack1("m")

  def decode_segment(segment) = JSON.parse(base64url_decode(segment))

  def stub_token_endpoint_capturing(assertions)
    stub_fcm_access_token.with do |request|
      assertions << URI.decode_www_form(request.body).to_h["assertion"]
    end
  end

  def cached_ttl
    Discourse.redis.ttl("#{described_class::CACHE_KEY_PREFIX}:#{service_account.fingerprint}")
  end

  describe "#token" do
    it "exchanges a signed JWT assertion for an access token" do
      stub =
        stub_fcm_access_token(access_token: "abc").with(
          body: hash_including("grant_type" => described_class::GRANT_TYPE),
        )

      expect(source.token).to eq("abc")
      expect(stub).to have_been_requested
    end

    it "signs the assertion with RS256 and the expected claims" do
      freeze_time
      assertions = []
      stub_token_endpoint_capturing(assertions)

      source.token

      header, claims, signature = assertions.sole.split(".")
      expect(decode_segment(header)).to eq("alg" => "RS256", "typ" => "JWT", "kid" => "key-id-1")
      expect(decode_segment(claims)).to eq(
        "iss" => "push@example-project.iam.gserviceaccount.com",
        "scope" => described_class::SCOPE,
        "aud" => MobilePushSpecHelpers::FCM_TOKEN_URL,
        "iat" => Time.zone.now.to_i,
        "exp" => Time.zone.now.to_i + 3600,
      )
      expect(
        fcm_private_key.public_key.verify(
          OpenSSL::Digest.new("SHA256"),
          base64url_decode(signature),
          "#{header}.#{claims}",
        ),
      ).to eq(true)
    end

    it "omits the key id header when the service account has none" do
      account =
        DiscourseMobilePush::Fcm::ServiceAccount.parse(
          fcm_service_account_json(private_key_id: nil),
        )
      assertions = []
      stub_token_endpoint_capturing(assertions)

      described_class.new(service_account: account).token

      expect(decode_segment(assertions.sole.split(".").first)).not_to have_key("kid")
    end

    it "uses unpadded base64url segments" do
      assertions = []
      stub_token_endpoint_capturing(assertions)

      source.token

      expect(assertions.sole).to match(/\A[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\z/)
    end

    it "reuses the cached access token" do
      stub = stub_fcm_access_token(access_token: "abc")
      source.token

      expect(source.token).to eq("abc")
      expect(stub).to have_been_requested.once
    end

    it "caches the access token until shortly before it expires" do
      stub_fcm_access_token(expires_in: 3599)

      source.token

      expect(cached_ttl).to be_within(5).of(3599 - described_class::EXPIRY_MARGIN_SECONDS)
    end

    it "caches short-lived tokens for a minimum period" do
      stub_fcm_access_token(expires_in: 10)

      source.token

      expect(cached_ttl).to be_within(5).of(described_class::MIN_CACHE_SECONDS)
    end

    it "raises a non-retryable AuthError when the grant is rejected" do
      stub_request(:post, MobilePushSpecHelpers::FCM_TOKEN_URL).to_return(
        status: 400,
        body: { error: "invalid_grant", error_description: "Invalid JWT Signature." }.to_json,
      )

      expect { source.token }.to raise_error(
        auth_error,
        /HTTP 400 invalid_grant: Invalid JWT/,
      ) do |error|
        expect(error).not_to be_retryable
      end
    end

    [429, 503].each do |status|
      it "raises a retryable AuthError on HTTP #{status}" do
        stub_request(:post, MobilePushSpecHelpers::FCM_TOKEN_URL).to_return(status:, body: "oops")

        expect { source.token }.to raise_error(auth_error, /HTTP #{status}/) do |error|
          expect(error).to be_retryable
        end
      end
    end

    it "raises a retryable AuthError on network failure" do
      stub_request(:post, MobilePushSpecHelpers::FCM_TOKEN_URL).to_timeout

      expect { source.token }.to raise_error(auth_error) { |error| expect(error).to be_retryable }
    end

    it "raises a retryable AuthError on an unexpected grant body" do
      stub_request(:post, MobilePushSpecHelpers::FCM_TOKEN_URL).to_return(status: 200, body: "{}")

      expect { source.token }.to raise_error(auth_error, /unexpected response/) do |error|
        expect(error).to be_retryable
      end
    end

    it "does not cache a blank access token" do
      stub_fcm_access_token(access_token: "")

      expect { source.token }.to raise_error(auth_error, /unexpected response/)
      expect(cached_ttl).to eq(-2)
    end
  end

  describe "#invalidate!" do
    it "forces the next call to fetch a new access token" do
      stub = stub_fcm_access_token
      source.token

      source.invalidate!
      source.token

      expect(stub).to have_been_requested.twice
    end
  end
end
