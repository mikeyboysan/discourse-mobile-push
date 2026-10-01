# discourse-mobile-push

A generic Discourse plugin that delivers Discourse notifications to native mobile apps through Firebase Cloud Messaging (FCM HTTP v1).

The plugin is a delivery channel, not a notification engine: Discourse still decides who is notified (including do-not-disturb and push filters), and the plugin routes those notifications to each user's registered devices.

> **Status: early development.** The device registration API is implemented. Notification delivery, the FCM adapter and admin diagnostics are designed but not built yet. See [`docs/proposal.md`](docs/proposal.md) for the full proposal.

## Installation

Follow [Install plugins in Discourse](https://meta.discourse.org/t/install-plugins-in-discourse/19157) using this repository's URL. Requires Discourse `2026.9.0` or later.

## Configuration

All settings are under **Admin > Settings**, prefixed `mobile_push_`.

| Setting | Purpose |
|---|---|
| `mobile_push_enabled` | Turns the plugin on |
| `mobile_push_firebase_service_account_json` | Firebase service account key (secret; can be supplied via a global/env setting) |
| `mobile_push_firebase_project_id` | Optional override for the project ID in the key |
| `mobile_push_privacy_mode` | `full` shows title and excerpt; `generic` shows a neutral message |
| `mobile_push_high_priority_notification_types` | Notification types sent with high priority |
| `mobile_push_max_devices_per_user` | Per-user device cap; the least recently seen device is evicted |
| `mobile_push_allowed_app_ids` | Allowlist of app IDs that may register (empty allows any) |
| `mobile_push_stale_device_days` | Days without activity before a device counts as stale |

## Mobile API

Apps register devices for the signed-in user. Any standard Discourse authentication works: a session cookie with CSRF token, an admin API key, or a User API key with the `discourse-mobile-push:devices` scope.

| Method | Path | Body |
|---|---|---|
| `POST` | `/mobile-push/v1/devices` | `platform` (`android`/`ios`), `app_id`, `token`, optional `app_version`, `device_identifier` |
| `GET` | `/mobile-push/v1/devices` | |
| `DELETE` | `/mobile-push/v1/devices/:id` | |
| `DELETE` | `/mobile-push/v1/devices` | `token` |

Push tokens must be sent in the request body, never in the query string. Responses show only a token fingerprint, never the full token.

Full reference, including request and response examples, matching rules and status codes: [`docs/mobile-api.md`](docs/mobile-api.md).

## Development

Tests and linters run inside the official `discourse/discourse_test` Docker image, so no local Ruby is needed:

```sh
bin/docker-test lint   # rubocop, syntax_tree, i18n lint
bin/docker-test spec   # plugin RSpec suite
```

Frontend linting uses pnpm (`pnpm install`, then `pnpm lint`).

## License

[MIT](LICENSE)
