# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::DiagnosticsStore do
  subject(:store) { described_class.new }

  let(:now) { Time.zone.parse("2026-10-01 12:00:00") }

  def result(outcome, detail: nil) = DiscourseMobilePush::DeliveryResult.new(outcome:, detail:)

  it "reports an empty summary before any delivery" do
    expect(store.summary).to have_attributes(
      last_success_at: nil,
      last_failure_at: nil,
      last_failure_detail: nil,
      last_config_error_at: nil,
      last_config_error_detail: nil,
      invalidated_count: 0,
    )
  end

  it "records the last success" do
    store.record(result: result(:delivered), at: now)

    expect(store.summary.last_success_at).to eq_time(now)
  end

  it "counts invalidated devices" do
    2.times { store.record(result: result(:invalid_device), at: now) }

    expect(store.summary.invalidated_count).to eq(2)
  end

  %i[retryable rejected].each do |outcome|
    it "records a #{outcome} outcome as the last failure" do
      store.record(result: result(outcome, detail: "HTTP 503"), at: now)

      summary = store.summary
      expect(summary).to have_attributes(last_failure_detail: "HTTP 503", last_config_error_at: nil)
      expect(summary.last_failure_at).to eq_time(now)
    end
  end

  it "records a configuration error as both the last failure and the last config error" do
    store.record(result: result(:config_error, detail: "HTTP 403"), at: now)

    summary = store.summary
    expect(summary).to have_attributes(
      last_failure_detail: "HTTP 403",
      last_config_error_detail: "HTTP 403",
    )
    expect(summary.last_config_error_at).to eq_time(now)
  end

  it "falls back to the outcome name when a failure has no detail" do
    store.record(result: result(:rejected), at: now)

    expect(store.summary.last_failure_detail).to eq("rejected")
  end
end
