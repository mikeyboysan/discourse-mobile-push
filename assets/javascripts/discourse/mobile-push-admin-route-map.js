export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("discourse-mobile-push-diagnostics", { path: "diagnostics" });
  },
};
