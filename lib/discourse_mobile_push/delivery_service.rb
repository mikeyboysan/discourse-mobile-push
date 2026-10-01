# frozen_string_literal: true

module DiscourseMobilePush
  class DeliveryService
    def initialize(
      provider: DiscourseMobilePush.provider,
      registry: DeviceRegistry.new,
      diagnostics: DiagnosticsStore.new
    )
      @provider = provider
      @registry = registry
      @diagnostics = diagnostics
    end

    def deliver(message:, device:)
      result = @provider.deliver(message:, token: device.token)
      now = Time.zone.now
      apply_outcome(result, device, now)
      @diagnostics.record(result:, device_id: device.id, at: now)
      result
    end

    private

    def apply_outcome(result, device, now)
      case result.outcome
      when :delivered
        device.record_delivery!(at: now)
      when :invalid_device
        @registry.invalidate(device:)
      else
        device.record_failure!(reason: result.detail || result.outcome.to_s, at: now)
      end
    end
  end
end
