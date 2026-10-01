import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-mobile-push";

export default {
  name: "mobile-push-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "mobile-screen-button");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "discourse_mobile_push.admin.diagnostics.title",
          route: "adminPlugins.show.discourse-mobile-push-diagnostics",
        },
      ]);
    });
  },
};
