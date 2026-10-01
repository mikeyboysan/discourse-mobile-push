# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::Fcm::ErrorClassifier do
  def response(status:, body: "", headers: {})
    DiscourseMobilePush::Fcm::HttpClient::Response.new(status:, body:, headers:)
  end

  def classify(**attrs) = described_class.classify(response: response(**attrs))

  it "classifies 200 as delivered" do
    expect(classify(status: 200, body: '{"name":"projects/p/messages/1"}')).to be_delivered
  end

  it "classifies UNREGISTERED as an invalid device" do
    body =
      fcm_error_body(
        status: "NOT_FOUND",
        http_status: 404,
        message: "Requested entity was not found.",
        error_code: "UNREGISTERED",
      )

    result = classify(status: 404, body:)

    expect(result).to be_invalid_device
    expect(result.detail).to eq("HTTP 404 UNREGISTERED: Requested entity was not found.")
  end

  it "classifies INVALID_ARGUMENT naming the token field as an invalid device" do
    body =
      fcm_error_body(
        status: "INVALID_ARGUMENT",
        http_status: 400,
        error_code: "INVALID_ARGUMENT",
        field: "message.token",
      )

    expect(classify(status: 400, body:)).to be_invalid_device
  end

  it "classifies other INVALID_ARGUMENT errors as rejected" do
    body =
      fcm_error_body(
        status: "INVALID_ARGUMENT",
        http_status: 400,
        error_code: "INVALID_ARGUMENT",
        field: "message.data",
      )

    expect(classify(status: 400, body:)).to be_rejected
  end

  it "classifies a 404 without UNREGISTERED as a configuration error" do
    body = fcm_error_body(status: "NOT_FOUND", http_status: 404)

    expect(classify(status: 404, body:)).to be_config_error
  end

  it "classifies 401 as a configuration error" do
    body = fcm_error_body(status: "UNAUTHENTICATED", http_status: 401)

    expect(classify(status: 401, body:)).to be_config_error
  end

  %w[PERMISSION_DENIED SENDER_ID_MISMATCH THIRD_PARTY_AUTH_ERROR].each do |code|
    it "classifies 403 #{code} as a configuration error" do
      body = fcm_error_body(status: "PERMISSION_DENIED", http_status: 403, error_code: code)

      expect(classify(status: 403, body:)).to be_config_error
    end
  end

  it "classifies 429 as retryable with the Retry-After delay" do
    body =
      fcm_error_body(status: "RESOURCE_EXHAUSTED", http_status: 429, error_code: "QUOTA_EXCEEDED")

    result = classify(status: 429, body:, headers: { "retry-after" => "30" })

    expect(result).to be_retryable
    expect(result.retry_after).to eq(30)
  end

  [500, 503].each do |status|
    it "classifies #{status} as retryable" do
      expect(classify(status:, body: "Service Unavailable")).to be_retryable
    end
  end

  it "ignores a Retry-After that is not a number of seconds" do
    result = classify(status: 503, headers: { "retry-after" => "Wed, 21 Oct 2026 07:28:00 GMT" })

    expect(result.retry_after).to be_nil
  end

  it "does not set retry_after on non-retryable outcomes" do
    result = classify(status: 400, headers: { "retry-after" => "30" })

    expect(result.retry_after).to be_nil
  end

  it "classifies unexpected statuses as rejected" do
    expect(classify(status: 413, body: "too large")).to be_rejected
  end

  it "falls back to the HTTP status when the body is not JSON" do
    expect(classify(status: 502, body: "<html>").detail).to eq("HTTP 502")
  end

  it "truncates long error messages" do
    body = fcm_error_body(status: "INVALID_ARGUMENT", http_status: 400, message: "x" * 500)

    expect(classify(status: 400, body:).detail.length).to eq(described_class::MAX_DETAIL_LENGTH)
  end
end
