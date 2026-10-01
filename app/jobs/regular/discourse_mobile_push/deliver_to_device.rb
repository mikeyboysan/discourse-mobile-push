# frozen_string_literal: true

module Jobs
  module DiscourseMobilePush
    class DeliverToDevice < ::Jobs::Base
      sidekiq_options retry: false

      MAX_ATTEMPTS = 5
      BASE_BACKOFF_SECONDS = 30
      MAX_BACKOFF_SECONDS = 3600

      def execute(args)
        settings = ::DiscourseMobilePush.settings
        return if !settings.enabled?

        user = ::User.find_by(id: args[:user_id])
        device = find_device(user, args[:device_id], settings)
        return if device.nil?

        result = deliver(args[:payload], user, device, settings)
        retry_later(args, result) if result.retryable?
      end

      private

      def find_device(user, device_id, settings)
        return if user.nil?

        ::DiscourseMobilePush::DeviceRegistry
          .new(settings:)
          .devices_for(user:)
          .find_by(id: device_id)
      end

      def deliver(payload, user, device, settings)
        alert =
          ::DiscourseMobilePush::AlertMapper.from_payload(payload, base_url: settings.base_url)
        message =
          ::DiscourseMobilePush::PayloadBuilder.new(settings:).build(
            alert:,
            locale: user.effective_locale,
          )
        ::DiscourseMobilePush::DeliveryService.new.deliver(message:, device:)
      end

      def retry_later(args, result)
        attempt = [args[:attempt].to_i, 1].max
        if attempt >= MAX_ATTEMPTS
          Rails.logger.warn(
            "[discourse-mobile-push] Giving up on device #{args[:device_id]} after #{attempt} attempts: #{result.detail}",
          )
          return
        end

        ::Jobs.enqueue_in(
          backoff_seconds(attempt, result.retry_after),
          self.class,
          user_id: args[:user_id],
          device_id: args[:device_id],
          payload: args[:payload],
          attempt: attempt + 1,
        )
      end

      def backoff_seconds(attempt, retry_after)
        exponential = BASE_BACKOFF_SECONDS * (2**(attempt - 1))
        [[exponential, retry_after.to_i].max, MAX_BACKOFF_SECONDS].min
      end
    end
  end
end
