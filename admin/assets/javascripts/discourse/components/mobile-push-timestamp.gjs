import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

const MobilePushTimestamp = <template>
  {{#if @value}}
    {{dFormatDate @value leaveAgo="true"}}
  {{else}}
    {{i18n "discourse_mobile_push.admin.never"}}
  {{/if}}
</template>;

export default MobilePushTimestamp;
