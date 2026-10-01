# discourse-mobile-push

A generic Discourse plugin that delivers Discourse notifications to native mobile apps through Firebase Cloud Messaging (FCM HTTP v1).

The plugin is a delivery channel, not a notification engine. Discourse still decides who is notified and when, including do-not-disturb and push notification filters from other plugins. The plugin takes each push notification Discourse produces and sends it to every device the user has registered from your app.

## What it does

- **Device registration API** (`/mobile-push/v1/devices`): your app registers the signed-in user's FCM token, refreshes it when it rotates, and removes it on logout. A user can have several devices.
- **Delivery** of every Discourse push notification (posts and chat) to the user's devices, in background jobs, with a deep-link `url` and IDs in the payload.
- **Self-healing**: temporary Firebase failures are retried with backoff; devices whose tokens Firebase reports as unregistered or invalid are removed automatically. Configuration errors never delete devices.
- **Privacy modes**: `full` sends the post excerpt; `generic` sends a neutral message.
- **Admin diagnostics** (Admin > Plugins > Mobile Push > Diagnostics): Firebase configuration, delivery health, device counts and app versions, a device browser with masked tokens, and a test notification to any device. The admin dashboard warns when credentials are missing or invalid, or when Firebase rejects pushes for several devices because of a configuration problem.

## What it doesn't do

- It is not a mobile app. You build the app (or use an existing one) and integrate it with the API below.
- It doesn't decide which events notify whom, and has no push preferences of its own: users control what reaches their phone through their normal Discourse notification settings (tracking levels, muting, do-not-disturb).
- It doesn't hold back pushes while the user is active on the website. Discourse's `push_notification_time_window_mins` delay applies only to browser push; mobile pushes are sent straight away.
- It doesn't group or collapse notifications, or keep delivery metrics beyond the diagnostics summary.
- It supports one Firebase project per site and FCM as the only provider.
- iOS devices can register and receive notifications through Firebase's APNs integration, but v1 sets no iOS-specific message options. Android is the primary target.
- It doesn't delete devices that are merely inactive; the diagnostics flag them as stale.

## Requirements

- Discourse `2026.9.0` or later.
- A Firebase project with the Firebase Cloud Messaging API enabled.
- Outbound HTTPS from the Discourse server to `oauth2.googleapis.com` and `fcm.googleapis.com`.

The plugin adds no gems: it signs its OAuth requests with Ruby's OpenSSL and talks to Firebase over `Net::HTTP`.

## Installation

Follow [Install plugins in Discourse](https://meta.discourse.org/t/install-plugins-in-discourse/19157) using this repository's URL, then rebuild the container.

## Firebase setup

1. **Create or choose a Firebase project** in the [Firebase console](https://console.firebase.google.com/) and add your Android app, using its package name. That package name is the `app_id` your app sends when registering. For iOS, add the iOS app too and upload an APNs authentication key under Project settings > Cloud Messaging.
2. **Check that the Firebase Cloud Messaging API is enabled** for the project in the Google Cloud console (APIs & Services). New projects have it enabled.
3. **Create a service account key with the least privilege needed.** In the Google Cloud console (IAM & Admin > Service accounts), create a service account with only the **Firebase Cloud Messaging API Admin** role, then create a JSON key for it. The key that Firebase console's "Generate new private key" button produces also works, but carries much broader permissions.
4. **Give the key to Discourse**, either:
   - by pasting the JSON into the `mobile_push_firebase_service_account_json` site setting (it is stored as a secret and never shown again in full), or
   - from the container environment, which hides the setting from the admin UI: set `DISCOURSE_MOBILE_PUSH_FIREBASE_SERVICE_ACCOUNT_JSON` in `app.yml`.
5. **Enable the plugin** with `mobile_push_enabled`. If your app authenticates with User API keys, add `discourse-mobile-push:devices` to the `allow_user_api_key_scopes` site setting. Consider listing your app's package name in `mobile_push_allowed_app_ids`.
6. **Open Admin > Plugins > Mobile Push > Diagnostics.** It should show the credentials as configured, with your project ID.
7. **Sign in from the app.** The device appears in the diagnostics device browser; use **Send test** to send a test notification to it.

## Configuration

All settings are under **Admin > Settings**, prefixed `mobile_push_`. The defaults suit most sites.

| Setting | Default | Purpose |
|---|---|---|
| `mobile_push_enabled` | off | Turns the plugin on |
| `mobile_push_firebase_service_account_json` | empty | Firebase service account key (secret; can be supplied through the environment) |
| `mobile_push_firebase_project_id` | empty | Optional override for the project ID in the key |
| `mobile_push_privacy_mode` | `full` | `full` shows the notification title and excerpt; `generic` shows the site title and a neutral message |
| `mobile_push_high_priority_notification_types` | private messages, mentions, chat mentions | Notification types sent with Android high priority |
| `mobile_push_max_devices_per_user` | 10 | Per-user device cap; the least recently seen device is removed when it is exceeded |
| `mobile_push_allowed_app_ids` | empty | App IDs that may register devices (empty allows any) |
| `mobile_push_stale_device_days` | 60 | Days without activity before the diagnostics show a device as stale |

## How it works

```text
Discourse notification
  -> Discourse's :push_notification event (after do-not-disturb and push filters)
  -> NotificationListener: one background job per registered device
  -> DeliverToDevice job -> DeliveryService -> PushProvider port -> FCM adapter -> Firebase
  -> outcome applied: delivered / retry later / remove invalid device / record config error
```

The code follows a ports-and-adapters layout:

- **Core** (`lib/discourse_mobile_push/`): device registry, payload builder, delivery service, health check and value objects. It knows nothing about Firebase or Discourse's site settings.
- **Push provider port** (`PushProvider`) with one adapter, `lib/discourse_mobile_push/fcm/`: service account parsing, OAuth access tokens (an RS256 JWT, cached per credential in Redis), the HTTP v1 request, and the mapping of FCM errors onto provider-neutral outcomes.
- **Discourse adapters**: the event listener, the delivery job, the API and admin controllers, the dashboard problem check, and `Settings`, the only reader of site settings. Each Discourse internal used is touched in one place, so Discourse upgrades have a small surface.

Delivery never happens inside a web request. The one exception is the admin test send, which runs synchronously with short timeouts (2 s connect, 4 s read).

## Mobile API and authentication

Every endpoint acts on the authenticated user's own devices; the server never accepts a user ID from the client. Apps can authenticate with:

- a **User API key** with the `discourse-mobile-push:devices` scope (recommended for native apps);
- a **session cookie** plus a CSRF token (WebView apps);
- an **admin API key** (server-side tooling).

| Method | Path | Body |
|---|---|---|
| `POST` | `/mobile-push/v1/devices` | `platform` (`android`/`ios`), `app_id`, `token`, optional `app_version` and `device_identifier` |
| `GET` | `/mobile-push/v1/devices` | |
| `DELETE` | `/mobile-push/v1/devices/:id` | |
| `DELETE` | `/mobile-push/v1/devices` | `token` |

Register on every app start and whenever the FCM token changes; registration is idempotent. Unregister on logout. Push tokens go in the request body, never in the query string, and responses only ever show a token fingerprint.

Each push carries a `notification` (title and body) and a `data` map with the notification type, an absolute `url` on the forum's own host, and topic, post or chat channel IDs. `data` never contains post text.

The full reference, with request and response examples, matching rules, status codes and the push payload, is in [`docs/mobile-api.md`](docs/mobile-api.md). The API is versioned in its path: breaking changes ship under `/mobile-push/v2`, and v1 keeps working.

## Security

- Push tokens are treated as secrets: filtered from request logs, masked in model inspection, never returned by the API or shown in the admin UI (a 12-character fingerprint is used instead), and scrubbed from Firebase error details.
- The service account key is a secret setting and is never logged.
- Device registration is rate limited to 20 requests per minute per user (staff are exempt); admin test sends to 10 per minute per admin, and each is recorded in the staff action log.
- Devices are deleted with their user, and when the user is anonymised.

See [`SECURITY.md`](SECURITY.md) to report a vulnerability.

## Development

Tests and linters run inside the official `discourse/discourse_test` Docker image, so you need Docker but no local Ruby:

```sh
bin/docker-test lint     # rubocop, syntax_tree, i18n lint, ESLint, Prettier
bin/docker-test spec     # plugin RSpec suite, including system (browser) specs
bin/docker-test prepare  # optional: snapshot a migrated core database
```

`prepare` saves a local `discourse-mobile-push-test:snapshot` image whose core database is already migrated, which makes `spec` start faster. `spec` uses the snapshot only when it was built from your current local test image; otherwise it migrates from scratch. Re-run `prepare` after pulling a newer `discourse/discourse_test` image.

Specs never call Firebase: the FCM adapter is tested against stubbed HTTP responses, and the rest of the plugin against a fake push provider. Pull requests also run Discourse's standard plugin CI workflow.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for conventions, and [`docs/proposal.md`](docs/proposal.md) for the original design proposal.

## License

[MIT](LICENSE)
