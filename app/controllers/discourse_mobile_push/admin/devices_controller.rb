# frozen_string_literal: true

module DiscourseMobilePush
  module Admin
    class DevicesController < ::Admin::AdminController
      include StringParams

      requires_plugin PLUGIN_NAME

      TEST_SENDS_PER_MINUTE = 10
      TEST_SEND_RATE_LIMIT_KEY = "mobile-push-test-send"
      TEST_SEND_LOG_TYPE = "mobile_push_test_send"
      PAGE_FORMAT = /\A\d{1,6}\z/

      def index
        page = registry.search(owners: owners_param, page: page_param)
        render json: {
                 devices: serialize_data(page.devices, AdminDeviceSerializer),
                 total_rows: page.total_rows,
                 page: page.page,
               }
      end

      def send_test
        device = registry.find(device_id: params.require(:id))
        raise Discourse::NotFound if device.nil?

        rate_limit_test_send!
        result = deliver_test(device)
        log_test_send(device, result)
        render json: { outcome: result.outcome, detail: result.detail }
      end

      private

      def registry = DeviceRegistry.new

      def owners_param
        username = string_param(:username)
        User.where(username_lower: User.normalize_username(username)) if username
      end

      def page_param
        page = string_param(:page)
        return 0 if page.nil?
        raise Discourse::InvalidParameters.new(:page) if !page.match?(PAGE_FORMAT)

        page.to_i
      end

      def rate_limit_test_send!
        RateLimiter.new(
          current_user,
          TEST_SEND_RATE_LIMIT_KEY,
          TEST_SENDS_PER_MINUTE,
          1.minute,
          apply_limit_to_staff: true,
        ).performed!
      end

      def deliver_test(device)
        message = PayloadBuilder.new.build_test(locale: device.user.effective_locale)
        DeliveryService.new(provider: DiscourseMobilePush.interactive_provider).deliver(
          message:,
          device:,
        )
      end

      def log_test_send(device, result)
        StaffActionLogger.new(current_user).log_custom(
          TEST_SEND_LOG_TYPE,
          username: device.user.username,
          device_id: device.id,
          platform: device.platform,
          app_id: device.app_id,
          token_fingerprint: device.token_fingerprint,
          outcome: result.outcome,
        )
      end
    end
  end
end
