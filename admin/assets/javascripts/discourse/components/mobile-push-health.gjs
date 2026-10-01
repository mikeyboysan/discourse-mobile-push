import { concat } from "@ember/helper";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import DStatTiles from "discourse/ui-kit/d-stat-tiles";
import { i18n } from "discourse-i18n";
import MobilePushTimestamp from "./mobile-push-timestamp";

const MobilePushHealth = <template>
  <div class="mobile-push-health">
    {{#if @status.problem}}
      <div class="alert alert-error mobile-push-health__problem">
        {{i18n (concat "discourse_mobile_push.admin.problem." @status.problem)}}
      </div>
    {{/if}}

    <DStatTiles class="mobile-push-health__counts" as |tiles|>
      <tiles.Tile
        @label={{i18n "discourse_mobile_push.admin.devices.total"}}
        @value={{@status.counts.total}}
      />
      <tiles.Tile
        @label={{i18n "discourse_mobile_push.admin.devices.stale"}}
        @tooltip={{i18n "discourse_mobile_push.admin.devices.stale_tooltip"}}
        @value={{@status.counts.stale}}
      />
      {{#each-in @status.counts.by_platform as |platform count|}}
        <tiles.Tile
          @label={{i18n
            (concat "discourse_mobile_push.admin.devices.platforms." platform)
          }}
          @value={{count}}
        />
      {{/each-in}}
    </DStatTiles>

    <AdminConfigAreaCard
      class="mobile-push-health__configuration"
      @heading="discourse_mobile_push.admin.configuration.heading"
    >
      <:content>
        <dl class="mobile-push-health__facts">
          <dt>{{i18n
              "discourse_mobile_push.admin.configuration.credentials"
            }}</dt>
          <dd class="mobile-push-health__credentials">
            {{#if @status.configured}}
              {{i18n "discourse_mobile_push.admin.configuration.configured"}}
            {{else}}
              {{i18n
                "discourse_mobile_push.admin.configuration.not_configured"
              }}
              {{#if @status.configuration_error}}
                <span class="mobile-push-health__error">
                  {{@status.configuration_error}}
                </span>
              {{/if}}
            {{/if}}
          </dd>
          {{#if @status.project_id}}
            <dt>{{i18n
                "discourse_mobile_push.admin.configuration.project_id"
              }}</dt>
            <dd class="mobile-push-health__project-id">
              {{@status.project_id}}
            </dd>
          {{/if}}
        </dl>
      </:content>
    </AdminConfigAreaCard>

    <AdminConfigAreaCard
      class="mobile-push-health__delivery"
      @heading="discourse_mobile_push.admin.delivery.heading"
    >
      <:content>
        <dl class="mobile-push-health__facts">
          <dt>{{i18n "discourse_mobile_push.admin.delivery.last_success"}}</dt>
          <dd class="mobile-push-health__last-success">
            <MobilePushTimestamp @value={{@status.summary.last_success_at}} />
          </dd>
          <dt>{{i18n "discourse_mobile_push.admin.delivery.last_failure"}}</dt>
          <dd class="mobile-push-health__last-failure">
            <MobilePushTimestamp @value={{@status.summary.last_failure_at}} />
            {{#if @status.summary.last_failure_detail}}
              <span class="mobile-push-health__error">
                {{@status.summary.last_failure_detail}}
              </span>
            {{/if}}
          </dd>
          <dt>{{i18n
              "discourse_mobile_push.admin.delivery.last_config_error"
            }}</dt>
          <dd class="mobile-push-health__last-config-error">
            <MobilePushTimestamp
              @value={{@status.summary.last_config_error_at}}
            />
            {{#if @status.summary.last_config_error_detail}}
              <span class="mobile-push-health__error">
                {{@status.summary.last_config_error_detail}}
              </span>
            {{/if}}
          </dd>
          <dt>{{i18n
              "discourse_mobile_push.admin.delivery.invalidated_count"
            }}</dt>
          <dd class="mobile-push-health__invalidated-count">
            {{@status.summary.invalidated_count}}
          </dd>
        </dl>
      </:content>
    </AdminConfigAreaCard>

    {{#if @status.counts.by_app_version.length}}
      <AdminConfigAreaCard
        class="mobile-push-health__app-versions"
        @heading="discourse_mobile_push.admin.app_versions.heading"
      >
        <:content>
          <table class="d-table">
            <thead class="d-table__header">
              <tr class="d-table__row">
                <th class="d-table__header-cell">
                  {{i18n "discourse_mobile_push.admin.app_versions.app"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_mobile_push.admin.app_versions.version"}}
                </th>
                <th class="d-table__header-cell">
                  {{i18n "discourse_mobile_push.admin.app_versions.count"}}
                </th>
              </tr>
            </thead>
            <tbody class="d-table__body">
              {{#each @status.counts.by_app_version as |row|}}
                <tr class="d-table__row">
                  <td class="d-table__cell --overview">{{row.app_id}}</td>
                  <td class="d-table__cell --detail">
                    {{#if row.app_version}}
                      {{row.app_version}}
                    {{else}}
                      {{i18n
                        "discourse_mobile_push.admin.app_versions.unknown_version"
                      }}
                    {{/if}}
                  </td>
                  <td class="d-table__cell --detail">{{row.count}}</td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </:content>
      </AdminConfigAreaCard>
    {{/if}}
  </div>
</template>;

export default MobilePushHealth;
