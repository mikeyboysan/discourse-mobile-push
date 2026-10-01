import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import { sendTestNotification } from "../lib/mobile-push-admin-api";
import MobilePushTimestamp from "./mobile-push-timestamp";

export default class MobilePushDeviceRow extends Component {
  @service dialog;

  @tracked result = null;
  @tracked sending = false;

  get removed() {
    return this.result?.outcome === "invalid_device";
  }

  get resultLabel() {
    return i18n(
      `discourse_mobile_push.admin.browser.outcome.${this.result.outcome}`
    );
  }

  get userPath() {
    const { user_id, username } = this.args.device;
    return getURL(`/admin/users/${user_id}/${encodeURIComponent(username)}`);
  }

  @action
  confirmSendTest() {
    this.dialog.yesNoConfirm({
      message: i18n("discourse_mobile_push.admin.browser.confirm_test", {
        username: this.args.device.username,
      }),
      didConfirm: () => this.sendTest(),
    });
  }

  async sendTest() {
    this.sending = true;
    try {
      const result = await sendTestNotification(this.args.device.id);
      if (!this.isDestroying) {
        this.result = result;
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      if (!this.isDestroying) {
        this.sending = false;
      }
    }
  }

  <template>
    <tr
      class={{dConcatClass
        "d-table__row mobile-push-device-row"
        (if this.removed "--removed")
      }}
      data-device-id={{@device.id}}
    >
      <td class="d-table__cell --overview mobile-push-device-row__user">
        <a href={{this.userPath}}>{{@device.username}}</a>
      </td>
      <td class="d-table__cell --detail">
        {{i18n
          (concat "discourse_mobile_push.admin.devices.platforms." @device.platform)
        }}
      </td>
      <td class="d-table__cell --detail">
        {{@device.app_id}}
        {{#if @device.app_version}}
          <span class="mobile-push-device-row__version">
            {{@device.app_version}}
          </span>
        {{/if}}
      </td>
      <td class="d-table__cell --detail">
        <code class="mobile-push-device-row__fingerprint">
          {{@device.token_fingerprint}}
        </code>
      </td>
      <td class="d-table__cell --detail">
        <MobilePushTimestamp @value={{@device.last_seen_at}} />
        {{#if @device.stale}}
          <span class="mobile-push-device-row__stale">
            {{i18n "discourse_mobile_push.admin.browser.stale"}}
          </span>
        {{/if}}
      </td>
      <td class="d-table__cell --detail">
        <MobilePushTimestamp @value={{@device.last_delivered_at}} />
      </td>
      <td class="d-table__cell --detail mobile-push-device-row__failure">
        <MobilePushTimestamp @value={{@device.last_failure_at}} />
        {{#if @device.last_failure_reason}}
          <span class="mobile-push-device-row__failure-reason">
            {{@device.last_failure_reason}}
          </span>
        {{/if}}
      </td>
      <td class="d-table__cell --controls">
        {{#if this.result}}
          <span
            class={{dConcatClass
              "mobile-push-device-row__test-result"
              (concat "--" this.result.outcome)
            }}
          >
            {{this.resultLabel}}
            {{#if this.result.detail}}
              ({{this.result.detail}})
            {{/if}}
          </span>
        {{/if}}
        {{#unless this.removed}}
          <DButton
            class="btn-default mobile-push-device-row__send-test"
            @action={{this.confirmSendTest}}
            @disabled={{this.sending}}
            @label="discourse_mobile_push.admin.browser.send_test"
          />
        {{/unless}}
      </td>
    </tr>
  </template>
}
