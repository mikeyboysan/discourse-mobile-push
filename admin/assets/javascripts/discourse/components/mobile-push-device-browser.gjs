import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";
import { fetchDevices } from "../lib/mobile-push-admin-api";
import MobilePushDeviceRow from "./mobile-push-device-row";

export default class MobilePushDeviceBrowser extends Component {
  @tracked devices = [];
  @tracked totalRows = 0;
  @tracked loading = false;
  @tracked username = "";

  page = 0;
  filteredUsername = null;
  latestRequest = 0;

  constructor() {
    super(...arguments);
    this.loadPage(0);
  }

  get canLoadMore() {
    return this.devices.length < this.totalRows;
  }

  get isEmpty() {
    return !this.loading && this.devices.length === 0;
  }

  async loadPage(page) {
    const request = ++this.latestRequest;
    const isCurrent = () =>
      !this.isDestroying && request === this.latestRequest;

    this.loading = true;
    try {
      const result = await fetchDevices({
        username: this.filteredUsername,
        page,
      });
      if (!isCurrent()) {
        return;
      }
      this.devices =
        page === 0 ? result.devices : [...this.devices, ...result.devices];
      this.totalRows = result.total_rows;
      this.page = result.page;
    } catch (error) {
      if (isCurrent()) {
        popupAjaxError(error);
      }
    } finally {
      if (isCurrent()) {
        this.loading = false;
      }
    }
  }

  @action
  updateUsername(event) {
    this.username = event.target.value;
  }

  @action
  filter(event) {
    event?.preventDefault();
    this.filteredUsername = this.username.trim() || null;
    this.loadPage(0);
  }

  @action
  loadMore() {
    this.loadPage(this.page + 1);
  }

  <template>
    <AdminConfigAreaCard
      class="mobile-push-devices"
      @heading="discourse_mobile_push.admin.browser.heading"
    >
      <:content>
        <form class="mobile-push-devices__filter" {{on "submit" this.filter}}>
          <input
            class="mobile-push-devices__username"
            placeholder={{i18n
              "discourse_mobile_push.admin.browser.username_placeholder"
            }}
            type="search"
            value={{this.username}}
            {{on "input" this.updateUsername}}
          />
          <DButton
            class="btn-default mobile-push-devices__filter-button"
            @action={{this.filter}}
            @label="discourse_mobile_push.admin.browser.filter"
          />
        </form>

        {{#if this.devices.length}}
          <table class="d-table mobile-push-devices__table">
            <thead class="d-table__header">
              <tr class="d-table__row">
                <th class="d-table__header-cell">
                  {{i18n "discourse_mobile_push.admin.browser.user"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_mobile_push.admin.browser.platform"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_mobile_push.admin.browser.app"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_mobile_push.admin.browser.token"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_mobile_push.admin.browser.last_seen"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_mobile_push.admin.browser.last_delivered"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_mobile_push.admin.browser.last_failure"}}
                </th>
                <th class="d-table__header-cell"></th>
              </tr>
            </thead>
            <tbody class="d-table__body">
              {{#each this.devices key="id" as |device|}}
                <MobilePushDeviceRow @device={{device}} />
              {{/each}}
            </tbody>
          </table>
        {{/if}}

        {{#if this.isEmpty}}
          <p class="mobile-push-devices__empty">
            {{i18n "discourse_mobile_push.admin.browser.empty"}}
          </p>
        {{/if}}

        {{#if this.canLoadMore}}
          <DButton
            class="btn-default mobile-push-devices__load-more"
            @action={{this.loadMore}}
            @disabled={{this.loading}}
            @label="discourse_mobile_push.admin.browser.load_more"
          />
        {{/if}}

        <DConditionalLoadingSpinner @condition={{this.loading}} />
      </:content>
    </AdminConfigAreaCard>
  </template>
}
