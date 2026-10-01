# discourse-mobile-push

A generic Discourse plugin that delivers Discourse notifications to native mobile apps through Firebase Cloud Messaging (FCM HTTP v1).

The plugin is a delivery channel, not a notification engine. Discourse still decides who is notified and when, including do-not-disturb and push notification filters from other plugins. The plugin takes each push notification Discourse produces and sends it to every device the user has registered from your app.

## What it does

- **Device registration API** (`/mobile-push/v1/devices`): your app registers the signed-in user's FCM token, refreshes it when it rotates, and removes it on logout. A user can have several devices.
- **Delivery** of every Discourse push notification (posts and chat) to the user's devices, in background jobs, with a deep-link `url` and IDs in the payload.
- **Signing out stops pushes**: a device registered with a User API key stops receiving notifications when the key is revoked or expires, and one registered with a session stops when that session ends (logout, logging out of all devices, a password change). Admins can also remove any device.
- **Self-healing**: temporary Firebase failures are retried with backoff; devices whose tokens Firebase reports as unregistered or invalid are removed automatically. Configuration errors never delete devices.
- **Privacy modes**: `full` sends the notification title and excerpt; `generic` sends a neutral message and links without topic or channel names. See [Data sent to Google and Apple](#data-sent-to-google-and-apple).
- **Admin diagnostics** (Admin > Plugins > Mobile Push > Diagnostics): Firebase configuration, delivery health, device counts and app versions, a device browser with masked tokens, a test notification to any device, and device removal. The admin dashboard warns when credentials are missing or invalid, or when Firebase rejects pushes for several devices because of a configuration problem.

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

## Data sent to Google and Apple

Every push goes through Google's Firebase Cloud Messaging and, for iOS devices, Apple's Push Notification service. What they receive depends on `mobile_push_privacy_mode`:

| | `full` (default) | `generic` |
|---|---|---|
| Notification title | The title Discourse uses for browser push, e.g. `jane replied to you in "Topic title" - Site` | The site title |
| Notification body | The post or chat excerpt, up to 500 characters | "You have a new notification" |
| `data.url` | The link Discourse gives the notification, including the topic or channel slug | A link without topic or channel names (`/t/<topic_id>/<post_number>`, `/chat/c/-/<channel_id>/...`), or the site URL |
| IDs and type | Notification type and topic, post or chat channel IDs | The same |

In `full` mode this includes personal messages, posts in restricted categories and private chat channels, sent to Google (and Apple) as notification text. Choose `generic` if that content must not leave your server. Both modes also send the device's push token. The plugin sends nothing else to any third party and has no telemetry.

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
| `mobile_push_privacy_mode` | `full` | `full` sends the notification title and excerpt; `generic` sends the site title, a neutral message and slug-free links (see [Data sent to Google and Apple](#data-sent-to-google-and-apple)) |
| `mobile_push_high_priority_notification_types` | personal messages, mentions, chat mentions | Notification types sent with Android high priority |
| `mobile_push_max_devices_per_user` | 10 | Per-user device cap; the least recently seen device is removed when it is exceeded |
| `mobile_push_allowed_app_ids` | empty | App IDs that may register devices (empty allows any) |
| `mobile_push_stale_device_days` | 60 | Days without activity before the diagnostics show a device as stale |

## Disabling, removing and backups

**Disabling** (`mobile_push_enabled` off) stops all delivery, and every plugin endpoint returns 404. Registered devices, settings and the diagnostics summary are kept, and delivery resumes when you enable it again. Anonymising a user still deletes their devices while the plugin is disabled.

**Removing the plugin** leaves its data in place: the `mobile_push_devices` table (with push tokens), the `mobile_push_*` site settings and the diagnostics summary in Redis. Reinstalling picks up where it left off. To delete the devices before removing the plugin, roll back its migrations, newest first, from inside the container:

```sh
cd /var/www/discourse
LOAD_PLUGINS=1 bin/rake db:migrate:down VERSION=20261001150000
LOAD_PLUGINS=1 bin/rake db:migrate:down VERSION=20261001100000
```

The second command drops the table and every registered device. Apps register again on their next start if you reinstall the plugin later.

**Backups** contain the registered push tokens and, unless it is supplied through the environment, the Firebase service account key. A production backup restored onto a staging site with the plugin enabled would send the staging site's notifications to real users' phones. To prevent that, supply the key through `DISCOURSE_MOBILE_PUSH_FIREBASE_SERVICE_ACCOUNT_JSON` in production (backups then carry no credentials), or clear `mobile_push_firebase_service_account_json` on the restored site straight after restoring. Use a separate Firebase project for staging.

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

A registration lasts as long as the credential that made it: revoking the User API key, or ending the session, stops delivery to that device, and the device is deleted within a day. Registrations made with an admin API key aren't tied to a credential.

Each push carries a `notification` (title and body) and a `data` map with the notification type, an absolute `url` on the forum's own host, and topic, post or chat channel IDs. `data` never contains post text.

The full reference, with request and response examples, matching rules, status codes and the push payload, is in [`docs/mobile-api.md`](docs/mobile-api.md). The API is versioned in its path: breaking changes ship under `/mobile-push/v2`, and v1 keeps working.

## Security

- Push tokens are treated as secrets: filtered from request logs, masked in model inspection, never returned by the API or shown in the admin UI (a 12-character fingerprint is used instead), and scrubbed from Firebase error details.
- The service account key is a secret setting and is never logged.
- Device registration is rate limited to 20 requests per minute per user (staff are exempt); admin test sends to 10 per minute per admin. Test sends and device removals are recorded in the staff action log.
- A device stops receiving pushes when the User API key or session it was registered with is revoked, expires or ends. Signed-out devices are hidden from the admin diagnostics and can't receive test sends.
- Removing a device in the admin diagnostics only lasts until the app registers again with a valid key or session. To cut off a lost or stolen phone, also end its sign-in: **Log Out** on the user's admin page ends all their sessions, and **Revoke Access** under **Apps** in the user's preferences revokes an app's User API key.
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
