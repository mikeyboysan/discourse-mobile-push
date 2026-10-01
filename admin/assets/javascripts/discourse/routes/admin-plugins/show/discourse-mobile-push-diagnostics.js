import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import { fetchStatus } from "../../../lib/mobile-push-admin-api";

export default class AdminPluginsShowDiscourseMobilePushDiagnosticsRoute extends DiscourseRoute {
  model() {
    return fetchStatus();
  }

  titleToken() {
    return i18n("discourse_mobile_push.admin.diagnostics.title");
  }
}
