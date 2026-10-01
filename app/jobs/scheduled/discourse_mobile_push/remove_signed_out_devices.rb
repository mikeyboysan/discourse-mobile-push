# frozen_string_literal: true

module Jobs
  module DiscourseMobilePush
    class RemoveSignedOutDevices < ::Jobs::Scheduled
      every 1.day

      def execute(_args)
        return if !::DiscourseMobilePush.settings.enabled?

        ::DiscourseMobilePush::DeviceRegistry.new.remove_signed_out
      end
    end
  end
end
