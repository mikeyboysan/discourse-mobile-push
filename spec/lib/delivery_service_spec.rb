# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::DeliveryService do
  fab!(:device, :mobile_push_device)

  let(:message) do
    DiscourseMobilePush::PushMessage.new(title: "T", body: "B", data: {}, priority: :normal)
  end
  let(:diagnostics) { DiscourseMobilePush::DiagnosticsStore.new }

  def deliver_with(provider)
    described_class.new(provider:, diagnostics:).deliver(message:, device:)
  end

  before { freeze_time }

  it "sends the message to the device token" do
    provider = MobilePushFakeProvider.new

    deliver_with(provider)

    expect(provider.deliveries).to contain_exactly({ message:, token: device.token })
  end

  it "returns the provider's result" do
    result = deliver_with(MobilePushFakeProvider.new(outcome: :rejected, detail: "HTTP 400"))

    expect(result).to have_attributes(outcome: :rejected, detail: "HTTP 400")
  end

  it "records the delivery time on success" do
    deliver_with(MobilePushFakeProvider.new)

    expect(device.reload.last_delivered_at).to eq_time(Time.zone.now)
  end

  it "removes the device when the provider reports it invalid" do
    deliver_with(MobilePushFakeProvider.new(outcome: :invalid_device))

    expect(DiscourseMobilePush::Device.exists?(device.id)).to eq(false)
  end

  %i[retryable config_error rejected].each do |outcome|
    it "records a #{outcome} failure on the device without removing it" do
      deliver_with(MobilePushFakeProvider.new(outcome:, detail: "HTTP 500"))

      device.reload
      expect(device).to have_attributes(last_failure_reason: "HTTP 500")
      expect(device.last_failure_at).to eq_time(Time.zone.now)
    end
  end

  it "records the outcome in the diagnostics summary" do
    deliver_with(MobilePushFakeProvider.new(outcome: :config_error, detail: "HTTP 403"))

    expect(diagnostics.summary.last_config_error_detail).to eq("HTTP 403")
  end

  it "attributes configuration errors to the device in diagnostics" do
    deliver_with(MobilePushFakeProvider.new(outcome: :config_error))

    expect(diagnostics.config_error_device_count(since: 1.minute.ago)).to eq(1)
  end
end
