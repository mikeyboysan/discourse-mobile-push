import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import MobilePushDeviceBrowser from "discourse/plugins/discourse-mobile-push/discourse/components/mobile-push-device-browser";
import MobilePushHealth from "discourse/plugins/discourse-mobile-push/discourse/components/mobile-push-health";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "discourse_mobile_push.admin.diagnostics.title"}}
    @path="/admin/plugins/discourse-mobile-push/diagnostics"
  />

  <section class="admin-detail mobile-push-diagnostics">
    <DPageSubheader
      @descriptionLabel={{i18n
        "discourse_mobile_push.admin.diagnostics.description"
      }}
      @titleLabel={{i18n "discourse_mobile_push.admin.diagnostics.title"}}
    />

    <MobilePushHealth @status={{@model}} />
    <MobilePushDeviceBrowser />
  </section>
</template>
