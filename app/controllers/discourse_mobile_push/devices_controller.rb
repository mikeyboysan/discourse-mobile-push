# frozen_string_literal: true

module DiscourseMobilePush
  class DevicesController < ::ApplicationController
    include StringParams

    requires_plugin PLUGIN_NAME

    REGISTRATIONS_PER_MINUTE = 20
    REGISTRATION_RATE_LIMIT_KEY = "mobile-push-register"

    before_action :ensure_logged_in
    before_action :reject_token_in_query_string, only: %i[create destroy_by_token]

    def index
      render_serialized(registry.devices_for(user: current_user), DeviceSerializer, root: "devices")
    end

    def create
      rate_limit_registration!

      result = registry.register(user: current_user, registration: registration_from_params)
      render_serialized(
        result.device,
        DeviceSerializer,
        root: "device",
        status: result.created ? :created : :ok,
      )
    end

    def destroy
      removed = registry.unregister_by_id(user: current_user, device_id: params.require(:id))
      raise Discourse::NotFound unless removed

      head :no_content
    end

    def destroy_by_token
      removed =
        registry.unregister_by_token(
          user: current_user,
          token: string_param(:token, required: true),
        )
      raise Discourse::NotFound unless removed

      head :no_content
    end

    private

    def registry = DeviceRegistry.new

    def rate_limit_registration!
      RateLimiter.new(
        current_user,
        REGISTRATION_RATE_LIMIT_KEY,
        REGISTRATIONS_PER_MINUTE,
        1.minute,
      ).performed!
    end

    def reject_token_in_query_string
      raise Discourse::InvalidParameters.new(:token) if request.query_parameters.key?("token")
    end

    def registration_from_params
      DeviceRegistry::Registration.new(
        platform: string_param(:platform, required: true),
        app_id: string_param(:app_id, required: true),
        token: string_param(:token, required: true),
        app_version: string_param(:app_version),
        device_identifier: string_param(:device_identifier),
        user_api_key_id: current_user_api_key_id,
        user_auth_token_id: current_user_auth_token_id,
      )
    end

    def current_user_auth_token_id
      request.env[Auth::DefaultCurrentUserProvider::USER_TOKEN_KEY]&.id
    end

    def current_user_api_key_id
      return if !request.env[Auth::DefaultCurrentUserProvider::USER_API_KEY_ENV]

      key = request.env[Auth::DefaultCurrentUserProvider::USER_API_KEY]
      UserApiKey.active.with_key(key).where(user: current_user).pick(:id) if key.present?
    end
  end
end
