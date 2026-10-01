# frozen_string_literal: true

# name: discourse-mobile-push
# about: Delivers Discourse notifications to native mobile apps through Firebase Cloud Messaging.
# version: 1.1.1
# authors: Michael Sandler
# url: https://github.com/mikeyboysan/discourse-mobile-push
# required_version: 2026.9.0

enabled_site_setting :mobile_push_enabled

register_asset "stylesheets/admin/mobile-push-admin.scss", :admin

add_admin_route "discourse_mobile_push.admin.title",
                "discourse-mobile-push",
                use_new_show_route: true

module ::DiscourseMobilePush
  PLUGIN_NAME = "discourse-mobile-push"

  def self.settings = Settings.current

  def self.provider = Fcm::Provider.new

  def self.interactive_provider = Fcm::Provider.new(http: Fcm::HttpClient.interactive)
end

require_relative "lib/discourse_mobile_push/engine"

Rails.application.config.filter_parameters << /\Atoken\z/

after_initialize do
  require_relative "app/services/problem_check/mobile_push_configuration"

  register_problem_check ProblemCheck::MobilePushConfiguration

  add_user_api_key_scope(
    :devices,
    methods: %i[get post delete],
    actions: %w[
      discourse_mobile_push/devices#index
      discourse_mobile_push/devices#create
      discourse_mobile_push/devices#destroy
      discourse_mobile_push/devices#destroy_by_token
    ],
  )

  on(:push_notification) do |user, payload|
    DiscourseMobilePush::NotificationListener.call(user, payload)
  end

  # Registered directly (not via `on`) so anonymised users lose their push tokens
  # even while the plugin is disabled.
  # rubocop:disable Discourse/Plugins/UsePluginInstanceOn
  DiscourseEvent.on(:user_anonymized) do |args|
    DiscourseMobilePush::DeviceRegistry.new.remove_all_for(user: args[:user])
  end
  # rubocop:enable Discourse/Plugins/UsePluginInstanceOn
end
