# frozen_string_literal: true

module DiscourseMobilePush
  module Admin
    class StatusController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      def show
        provider = DiscourseMobilePush.provider
        provider_status = provider.status
        render json: {
                 enabled: DiscourseMobilePush.settings.enabled?,
                 configured: provider_status.configured,
                 project_id: provider_status.project_id,
                 configuration_error: provider_status.error,
                 problem: HealthCheck.new(provider:).problem,
                 summary: DiagnosticsStore.new.summary.to_h,
                 counts: counts_json(DeviceRegistry.new.counts),
               }
      end

      private

      def counts_json(counts)
        {
          total: counts.total,
          stale: counts.stale,
          by_platform: counts.by_platform,
          by_app_version: counts.by_app_version.map(&:to_h),
        }
      end
    end
  end
end
