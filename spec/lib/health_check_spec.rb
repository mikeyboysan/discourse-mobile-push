# frozen_string_literal: true

RSpec.describe DiscourseMobilePush::HealthCheck do
  let(:diagnostics) { DiscourseMobilePush::DiagnosticsStore.new }

  before { enable_current_plugin }

  def problem(configured: true)
    provider = MobilePushFakeProvider.new(configured:)
    described_class.new(provider:, diagnostics:).problem
  end

  def config_error_on(device, at: Time.zone.now)
    diagnostics.record(
      result: DiscourseMobilePush::DeliveryResult.new(outcome: :config_error, detail: "HTTP 403"),
      device_id: device.id,
      at:,
    )
  end

  it "reports no problem when push is healthy" do
    expect(problem).to be_nil
  end

  it "reports no problem while push is disabled, even without credentials" do
    SiteSetting.mobile_push_enabled = false

    expect(problem(configured: false)).to be_nil
  end

  it "reports missing or invalid credentials" do
    expect(problem(configured: false)).to eq(:not_configured)
  end

  context "with configuration errors reported by the provider" do
    fab!(:devices) { Fabricate.times(3, :mobile_push_device) }

    it "reports them when several devices had one in the last day" do
      devices.first(2).each { |device| config_error_on(device) }

      expect(problem).to eq(:config_errors)
    end

    it "ignores a single device with configuration errors" do
      config_error_on(devices.first)

      expect(problem).to be_nil
    end

    it "ignores configuration errors older than a day" do
      devices.first(2).each { |device| config_error_on(device, at: 25.hours.ago) }

      expect(problem).to be_nil
    end
  end

  it "reports configuration errors on the only registered device" do
    config_error_on(Fabricate(:mobile_push_device))

    expect(problem).to eq(:config_errors)
  end

  it "reports no problem once no devices are registered" do
    device = Fabricate(:mobile_push_device)
    config_error_on(device)
    device.destroy!

    expect(problem).to be_nil
  end
end
