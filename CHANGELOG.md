# Changelog

All notable changes to this plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the plugin uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Removed

- Third-party AI review-skill files (`.agents/`, `skills-lock.json`) are no longer part of the repository, so `git clone` installs don't receive them.

## [1.1.0] - 2026-10-01

Fixes from the 1.0.0 release review.

### Added

- Admins can remove a device from the admin diagnostics (`DELETE /admin/mobile-push/devices/:id`). Each removal is recorded in the staff action log.
- README sections on the data sent to Google and Apple, and on disabling, removing and backups.

### Changed

- A device is now tied to the User API key or session it was registered with. Revoking the key, or ending the session (logout, logging out of all devices, a password change, expiry), stops delivery to the device, and a daily job deletes it. Registrations made with an admin API key, and devices registered before 1.1.0 until their app registers again, aren't tied to a credential.
- In `generic` privacy mode, `data.url` no longer contains topic or chat channel slugs, which carry titles: post notifications link to `/t/<topic_id>/<post_number>`, chat notifications to `/chat/c/-/<channel_id>/...`, and other notifications to the forum's base URL.
- The `mobile_push_privacy_mode` setting description now says what is sent to Firebase and Apple.
- Developer-only files are left out of release archives.

## [1.0.0] - 2026-10-01

First release.

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
- README with Firebase setup and architecture, contributing guide and security policy.

[Unreleased]: https://github.com/mikeyboysan/discourse-mobile-push/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/mikeyboysan/discourse-mobile-push/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/mikeyboysan/discourse-mobile-push/releases/tag/v1.0.0
