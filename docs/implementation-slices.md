# Implementation slices

discourse-mobile-push v1.0 is built in six vertical slices. Each slice is usable on its own, passes the verification gate (`.lattice/verification.yaml`: lint and the plugin RSpec suite in the Discourse test image), is reviewed, and is committed separately.

The design these slices implement, and every decision taken while building them, live in [`.lattice/context/mobile-push-v1.md`](../.lattice/context/mobile-push-v1.md) (Decisions Log rows tagged `[Impl slice N]` and `[Review slice N]`). Review results are in [`.lattice/reviews/review-log.md`](../.lattice/reviews/review-log.md). The source requirements are in [`proposal.md`](proposal.md).

| # | Slice | Status | Commit |
|---|---|---|---|
| 1 | Skeleton, settings, device registry and device API | Done | `7258353` |
| 2 | FCM HTTP v1 push provider | Done | `3f809f6` |
| 3 | Notification dispatch (first end-to-end milestone) | Done | `99f4d5f` |
| 4 | Admin diagnostics API and dashboard problem check | Done | `48767d3` |
| 5 | Admin page (Ember) | Done | `112acfe` |
| 6 | Documentation and release files | Planned | -- |

Supporting commits outside the slices: `3eb3f52` (migrated-database snapshot for faster spec runs) and `a2a7ac4` (schema annotation on the `Device` model).

---

## Slice 1: Skeleton, settings, device registry and device API

**Goal**: a signed-in app user can register, list and remove their devices.

**Scope**
- Plugin skeleton (`plugin.rb`, engine, `mobile_push_enabled` setting) and the verification gate (`bin/docker-test`, `.lattice/verification.yaml`).
- `mobile_push_*` site settings, read only through `Settings` (privacy mode, high-priority types, per-user device cap, app ID allowlist, stale-device days, Firebase credentials).
- `mobile_push_devices` table and `Device` model: token unique site-wide, cascading delete with the user, token fingerprint (first 12 hex characters of SHA-256).
- `DeviceRegistry`: idempotent register (match by token, then by user + app + device identifier), ownership transfer, per-user cap eviction, race-safe retry on `RecordNotUnique`, listing, removal.
- Device API `/mobile-push/v1/devices` (`GET`, `POST`, `DELETE /:id`, `DELETE` by token), the `discourse-mobile-push:devices` User API key scope, a registration rate limit of 20 per minute.
- Devices removed when their user is deleted or anonymised.

**Security**: tokens only in request bodies, filtered from logs, masked in `inspect`, never returned (fingerprint only); ownership always from the authenticated user.

**Result**: 56 specs green. Review: 0 critical, 3 warnings, 5 suggestions.

## Slice 2: FCM HTTP v1 push provider

**Goal**: send a provider-neutral message to one device token through Firebase, and get back a neutral outcome.

**Scope**
- Core value objects `PushMessage` (title, body, string data, priority) and `DeliveryResult` (`delivered`, `invalid_device`, `retryable`, `config_error`, `rejected`).
- `PushProvider` port, wired in the composition root as `DiscourseMobilePush.provider`.
- FCM adapter in `lib/discourse_mobile_push/fcm/`, with no Google gems:
  - `ServiceAccount` parsing and validation (token URI must be `https` on `*.googleapis.com`);
  - `AccessTokenSource` (RS256 JWT signed with OpenSSL, token cached in Redis per credential fingerprint);
  - `RequestBuilder`;
  - `HttpClient` (`Net::HTTP` with timeouts);
  - `ErrorClassifier` (FCM responses mapped to neutral outcomes);
  - `Provider` (one re-authentication on 401, device token scrubbed from error details).

**Rule**: only an explicit `UNREGISTERED` or invalid-token error yields `invalid_device`; configuration errors never delete devices.

**Result**: 148 specs green. Review: 0 critical, 1 warning, 5 suggestions.

## Slice 3: Notification dispatch (first end-to-end milestone)

**Goal**: every Discourse push notification (posts and chat) reaches the user's registered devices.

**Scope**
- `NotificationListener` on `:push_notification`: honours the enabled setting, do-not-disturb, push notification filters and provider configuration, then enqueues one job per device with minimised payload fields.
- `AlertMapper` (the only reader of Discourse alert payload keys; same-site absolute URLs only) and the `Alert` value object.
- `PayloadBuilder`: `full` / `generic` privacy modes, Discourse's push titles, truncation (title 150, body 500), the string `data` contract, priority per notification type.
- `DeliveryService`: sends through the port and applies the outcome (record delivery, remove invalid device, record failure).
- `DiagnosticsStore`: per-site Redis summary (last success, last failure, last config error, invalidated count).
- `Jobs::DiscourseMobilePush::DeliverToDevice`: quiet re-enqueue with exponential backoff honouring `Retry-After`, up to 5 attempts.
- Push payload documented in [`mobile-api.md`](mobile-api.md#push-payload).

**Result**: 215 specs green (217 after review fixes). Review: 0 critical, 3 warnings, 2 suggestions.

## Slice 4: Admin diagnostics API and dashboard problem check

**Goal**: an administrator can see whether push is healthy, browse devices, and send a test notification; the dashboard warns about broken configuration.

**Scope**
- `PushProvider#status` returning `ProviderStatus` (configured, project ID, sanitised error).
- `Fcm::HttpClient.interactive` (2 s open, 4 s read timeouts), wired as `DiscourseMobilePush.interactive_provider` for the synchronous test send.
- `DiagnosticsStore` tracks which devices had configuration errors in the last day (Redis sorted set).
- `DeviceRegistry` admin queries: `find`, `device_count`, `counts` (total, stale, by platform, by app version), `search` (paged, filter by owner).
- `PayloadBuilder#build_test` (`data.type = "test"`, high priority).
- Core `HealthCheck#problem` returning `nil`, `:not_configured` or `:config_errors` (at least min(2, registered devices) devices with configuration errors in the last day).
- Admin-only JSON endpoints, each returning 404 for non-admins and while the plugin is disabled:
  - `GET /admin/mobile-push/status.json`: configuration, health problem, summary, device counts;
  - `GET /admin/mobile-push/devices.json?username=&page=`: device browser with masked tokens;
  - `POST /admin/mobile-push/devices/:id/test.json`: bounded test send, rate limited to 10 per minute per admin, recorded in the staff action log.
- `ProblemCheck::MobilePushConfiguration` with one dashboard message per cause.

**Result**: verification green. Review: 0 critical, 3 warnings, 4 suggestions, all fixed.

## Slice 5: Admin page (Ember)

**Goal**: the slice 4 diagnostics available in the Discourse admin UI.

**Scope**
- A "Diagnostics" tab on the plugin's admin page at `/admin/plugins/discourse-mobile-push/diagnostics` (`add_admin_route` with the new show route, `addAdminPluginConfigurationNav`, plugin icon), kept separate from the `/admin/mobile-push` JSON paths; a server route serves the page on a full page load.
- Health summary from `status.json`: health problem notice, device counts (total, stale, per platform), Firebase configuration (credentials, project ID, sanitised error), delivery (last success, last failure, last configuration error, invalidated count) and app versions.
- Device browser from `devices.json`: username filter, "Load more" paging, token fingerprints only, last seen (with stale flag), last delivered, last failure.
- Test send per device after a confirmation dialog, showing the outcome inline; a device removed for an invalid token is marked as removed.
- Admin-only locale strings (`admin_js`) and an admin stylesheet.
- Verification gate extended: ESLint and Prettier in the lint stage, system specs in the spec stage.

**Result**: verification green (278 examples plus 26 system examples).

## Slice 6: Documentation and release files -- planned

**Goal**: the plugin ready for public release (proposal section 35).

**Planned scope**
- `README.md` explaining what the plugin does and doesn't do, the architecture, how the mobile API and authentication work, Firebase setup, and how to develop and test.
- `CONTRIBUTING.md` and `SECURITY.md`; review `LICENSE`.
- `.discourse-compatibility`, `meta_topic_id` in `plugin.rb`, and the first versioned `CHANGELOG.md` release section.
- Final pass over `docs/mobile-api.md`.
- Set the context document status to `complete`.
