# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::Fcm::HttpClient do
  subject(:client) { described_class.new }

  let(:url) { "https://fcm.googleapis.com/v1/projects/p/messages:send" }

  describe "#post_json" do
    it "posts a JSON body with the given headers" do
      stub =
        stub_request(:post, url).with(
          body: { "a" => 1 }.to_json,
          headers: {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer abc",
          },
        ).to_return(status: 200, body: "{}", headers: { "Retry-After" => "5" })

      response =
        client.post_json(url:, body: { a: 1 }, headers: { "Authorization" => "Bearer abc" })

      expect(stub).to have_been_requested
      expect(response).to have_attributes(status: 200, body: "{}")
      expect(response.headers["retry-after"]).to eq("5")
    end
  end

  describe "#post_form" do
    it "posts a form-encoded body" do
      stub =
        stub_request(:post, url).with(
          body: "grant_type=x&assertion=y",
          headers: {
            "Content-Type" => "application/x-www-form-urlencoded",
          },
        ).to_return(status: 400, body: "bad")

      response = client.post_form(url:, form: { grant_type: "x", assertion: "y" })

      expect(stub).to have_been_requested
      expect(response).to have_attributes(status: 400, body: "bad")
    end
  end

  describe ".interactive" do
    it "uses the short timeouts meant for synchronous requests" do
      Net::HTTP
        .expects(:start)
        .with(
          "fcm.googleapis.com",
          443,
          use_ssl: true,
          open_timeout: described_class::INTERACTIVE_OPEN_TIMEOUT_SECONDS,
          read_timeout: described_class::INTERACTIVE_READ_TIMEOUT_SECONDS,
          write_timeout: described_class::INTERACTIVE_READ_TIMEOUT_SECONDS,
        )
        .raises(Net::OpenTimeout)

      expect { described_class.interactive.post_json(url:, body: {}) }.to raise_error(
        described_class::NetworkError,
      )
    end
  end

  describe "network failures" do
    it "raises NetworkError on timeout" do
      stub_request(:post, url).to_timeout

      expect { client.post_json(url:, body: {}) }.to raise_error(
        described_class::NetworkError,
        /fcm\.googleapis\.com/,
      )
    end

    [
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      SocketError,
      OpenSSL::SSL::SSLError,
      EOFError,
    ].each do |error|
      it "raises NetworkError on #{error.name}" do
        stub_request(:post, url).to_raise(error)

        expect { client.post_form(url:, form: {}) }.to raise_error(described_class::NetworkError)
      end
    end
  end
end
