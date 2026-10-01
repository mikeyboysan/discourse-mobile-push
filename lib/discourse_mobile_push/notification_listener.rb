# frozen_string_literal: true

module DiscourseMobilePush
  class NotificationListener
    def self.call(user, payload) = new.call(user, payload)

    def initialize(
      settings: DiscourseMobilePush.settings,
      registry: DeviceRegistry.new(settings:),
      provider: DiscourseMobilePush.provider,
      push_filters: DiscoursePluginRegistry.push_notification_filters
    )
      @settings = settings
      @registry = registry
      @provider = provider
      @push_filters = push_filters
    end

    def call(user, payload)
      return if !@settings.enabled?

      device_ids = @registry.devices_for(user:).pluck(:id)
      return if device_ids.empty? || filtered_out?(user, payload) || !@provider.configured?

      job_payload = AlertMapper.relevant_fields(payload)
      device_ids.each do |device_id|
        ::Jobs.enqueue(
          ::Jobs::DiscourseMobilePush::DeliverToDevice,
          user_id: user.id,
          device_id:,
          payload: job_payload,
          attempt: 1,
        )
      end
    end

    private

    def filtered_out?(user, payload) = @push_filters.any? { |filter| !filter.call(user, payload) }
  end
end
