# Changelog

All notable changes to this plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the plugin uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Device registration API at `/mobile-push/v1/devices`: register, list and unregister (by id or by token) the signed-in user's devices. See [docs/mobile-api.md](docs/mobile-api.md).
- `discourse-mobile-push:devices` User API key scope.
- `mobile_push_*` site settings, including a per-user device cap and an app ID allowlist.
- Devices are removed when their user is deleted or anonymised.
- Push tokens are filtered from request logs and never returned in API responses.
