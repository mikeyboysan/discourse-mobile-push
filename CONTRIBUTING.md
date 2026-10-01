# Contributing

Thanks for helping improve discourse-mobile-push. Bug reports, fixes and documentation improvements are all welcome.

## Reporting issues

Open a [GitHub issue](https://github.com/mikeyboysan/discourse-mobile-push/issues) with your Discourse version, the plugin version, what you expected and what happened. The admin diagnostics page (Admin > Plugins > Mobile Push > Diagnostics) usually shows the relevant Firebase error. **Never paste a push token or a service account key** into an issue; the token fingerprint shown in the diagnostics is enough.

Report security problems privately instead; see [`SECURITY.md`](SECURITY.md).

## Development setup

You need Docker and a clone of this repository. Tests and linters run inside the official `discourse/discourse_test` image:

```sh
bin/docker-test lint     # rubocop, syntax_tree, i18n lint, ESLint, Prettier
bin/docker-test spec     # plugin RSpec suite, including system specs
bin/docker-test prepare  # optional: snapshot a migrated core database for faster spec runs
```

On Windows, check out with LF line endings (the repository's `.gitattributes` enforces this for new checkouts); CRLF files break the scripts and formatter checks inside the Linux container.

For editor tooling and frontend linting outside Docker, run `pnpm install`.

## Pull requests

- Keep each pull request focused on one change, with specs covering it. Both `bin/docker-test lint` and `bin/docker-test spec` must pass.
- Add an entry under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md) for any user-visible change.
- If you change what apps send or receive, update [`docs/mobile-api.md`](docs/mobile-api.md) in the same pull request.

## Design rules

These keep the plugin generic, secure and easy to maintain across Discourse upgrades. Pull requests that break them will be asked to change.

- **Mobile API compatibility.** `/mobile-push/v1` and the push `data` contract are used by shipped apps. Don't remove or rename fields, change types or status codes, or add required parameters; a breaking change needs a new API version path. New optional fields are fine, once documented.
- **Push tokens and credentials are secrets.** Never log, return or display a full push token or the service account key; use the token fingerprint. Tokens are accepted in request bodies only.
- **Ownership comes from the authenticated user.** Never accept a user ID from the client for device operations.
- **No delivery inside web requests.** Sending happens in background jobs; the admin test send is the only, bounded, exception.
- **Configuration errors never delete devices.** Only an explicit unregistered or invalid-token response from the provider removes a device.
- **Ports and adapters.** Core code in `lib/discourse_mobile_push/` never references Firebase (`Fcm::*`) or `SiteSetting`. Firebase specifics stay in `lib/discourse_mobile_push/fcm/`; site settings are read only through `Settings`; each Discourse internal (events, alert payload keys, jobs) is used from a single adapter.
- **No new gems.** In particular no Firebase or Google client gems: the FCM adapter uses OpenSSL and `Net::HTTP`.
- **Specs never call Firebase.** Stub HTTP in FCM adapter specs, and use the fake push provider in `spec/plugin_helper.rb` elsewhere.

## Releases

The plugin follows [Semantic Versioning](https://semver.org/). To release, move the `Unreleased` changelog entries under a new version heading, bump `version` in `plugin.rb`, and tag the commit `vX.Y.Z`. When a release drops support for a Discourse version, add an entry to `.discourse-compatibility` pinning that version to the last compatible commit.
