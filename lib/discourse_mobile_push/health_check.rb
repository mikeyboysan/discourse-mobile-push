# frozen_string_literal: true

module DiscourseMobilePush
  class HealthCheck
    CONFIG_ERROR_WINDOW = 1.day
    # A single stray token (e.g. a debug build registered against production) can
    # produce configuration errors on its own; require more than one device.
    MIN_AFFECTED_DEVICES = 2

    def initialize(
      settings: DiscourseMobilePush.settings,
      provider: DiscourseMobilePush.provider,
      registry: DeviceRegistry.new(settings:),
      diagnostics: DiagnosticsStore.new
    )
      @settings = settings
      @provider = provider
      @registry = registry
      @diagnostics = diagnostics
    end

    # nil when healthy or disabled; otherwise :not_configured or :config_errors.
    def problem
      return if !@settings.enabled?
      return :not_configured if !@provider.configured?

      :config_errors if widespread_config_errors?
    end

    private

    def widespread_config_errors?
      threshold = [MIN_AFFECTED_DEVICES, @registry.device_count].min
      return false if threshold.zero?

      @diagnostics.config_error_device_count(since: CONFIG_ERROR_WINDOW.ago) >= threshold
    end
  end
end
