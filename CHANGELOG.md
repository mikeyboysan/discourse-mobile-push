# Changelog

All notable changes to this plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the plugin uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Device registration API at `/mobile-push/v1/devices`: register, list and unregister (by id or by token) the signed-in user's devices. See [docs/mobile-api.md](docs/mobile-api.md).
- `discourse-mobile-push:devices` User API key scope.
- `mobile_push_*` site settings, including a per-user device cap and an app ID allowlist.
- Devices are removed when their user is deleted or anonymised.
- Push tokens are filtered from request logs and never returned in API responses.
- Notification delivery through Firebase Cloud Messaging HTTP v1: every Discourse push notification (posts and chat) is sent to the user's registered devices, honouring do-not-disturb and push notification filters. The push payload is documented in [docs/mobile-api.md](docs/mobile-api.md#push-payload).
- `full` and `generic` privacy modes, and high priority for configurable notification types.
- Temporary Firebase failures are retried with backoff (up to 5 attempts, honouring `Retry-After`); devices whose tokens Firebase reports as unregistered or invalid are removed automatically.
- Admin diagnostics API (admins only) under `/admin/mobile-push`: configuration status, delivery summary and device counts; a device browser with tokens masked; and a test notification to a chosen device, recorded in the staff action log.
- Admin page (Plugins > Mobile Push > Diagnostics): Firebase configuration, delivery health, device counts and app versions, a device browser with username filter, and a confirmed test send per device.
- Admin dashboard warning when push is enabled but the Firebase credentials are missing or invalid, or Firebase reported configuration errors for several devices in the last day.
