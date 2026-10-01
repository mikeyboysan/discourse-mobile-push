---
feature: "discourse-mobile-push Knowledge Base"
mode: override
created: "2026-10-01"
---

> This is the knowledge base for discourse-mobile-push. It primes AI with project-specific context -- tech stack, architecture, trusted sources, and project structure -- so generated code fits this codebase rather than defaulting to generic patterns.

## 1. Architecture Overview

A generic, open-source Discourse plugin (a Rails engine loaded inside the Discourse monolith) that delivers Discourse notifications to native mobile apps via Firebase Cloud Messaging. It is a **delivery channel, not a notification engine**: Discourse decides who is notified; the plugin only routes to devices.

- **Notification adapter**: subscribes to core's `DiscourseEvent :push_notification` (fired by `PostAlerter.push_notification` for post and chat alerts, after do-not-disturb, before `push_notification_filters`).
- **Device registry**: `mobile_push_devices` table + versioned JSON API under `/mobile-push/v1/devices`; many devices per user, many apps per site.
- **Delivery**: Discourse background jobs (Sidekiq) build a provider-neutral push message and hand it to a push provider.
- **Push provider**: FCM HTTP v1 is the first (and initially only) implementation behind a provider interface; error classification lives inside it.
- **Diagnostics**: admin plugin page (status, device list with masked tokens, test send) + admin dashboard problem check for config errors.
- **External systems**: FCM `POST /v1/projects/{id}/messages:send`; Google OAuth2 token endpoint (service-account JWT grant).

## 2. Tech Stack and Versions

- **Host**: Discourse `main`/tests-passed only (Ruby 3.3+, Rails as shipped by Discourse, PostgreSQL, Redis). Older Discourse versions are pinned via `.discourse-compatibility`, not supported in code.
- **Background work**: `Jobs::Base` / `Jobs::Scheduled` (not raw Sidekiq workers, not ActiveJob).
- **Firebase**: FCM HTTP v1 (not the legacy FCM HTTP/XMPP APIs). **No Firebase/Google gems** (not `fcm`, not `firebase-admin`, not `googleauth`, not the `jwt` gem): service-account JWT signed with Ruby `OpenSSL` stdlib, HTTP via `Net::HTTP`.
- **Credentials**: Firebase service-account JSON in a `secret` site setting, shadowable by a global/env setting (`DISCOURSE_*`).
- **Mobile auth**: any standard Discourse auth -- session cookie (+ CSRF), User API keys (plugin-registered scope), admin API keys. Never a client-supplied `user_id`.
- **Frontend (admin only)**: Ember/Glimmer `.gjs` components using Discourse `ui-kit`; pnpm.
- **Testing**: RSpec + Fabrication + WebMock inside Discourse's plugin harness (`LOAD_PLUGINS=1`); QUnit for JS. Run in the `discourse/discourse_test` Docker image (no local Ruby on the dev machine; Windows host).
- **Lint/format**: `rubocop-discourse` + `syntax_tree` (stree); `@discourse/lint-configs` (eslint, prettier, stylelint).

## 3. Curated Knowledge Sources

| Topic | Source | Why |
|-------|--------|-----|
| Plugin development | https://meta.discourse.org/t/developing-discourse-plugins-part-1-create-a-basic-plugin/30515 | Official guide |
| Plugin skeleton | https://github.com/discourse/discourse-plugin-skeleton | Canonical layout and tooling |
| Plugin API / hooks | discourse core `lib/plugin/instance.rb`, `app/services/post_alerter.rb`, `lib/route_matcher.rb`, `app/models/problem_check.rb` | Ground truth for extension points |
| Current conventions | bundled plugins in discourse core `plugins/` (e.g. `discourse-events`) | Up-to-date admin pages, jobs, engine setup |
| User API keys | https://meta.discourse.org/t/user-api-keys-specification/48536 | Mobile auth flow |
| FCM send | https://firebase.google.com/docs/cloud-messaging/send-message | HTTP v1 message format |
| FCM errors | https://firebase.google.com/docs/reference/fcm/rest/v1/ErrorCode | Error classification |
| FCM tokens | https://firebase.google.com/docs/cloud-messaging/manage-tokens | Staleness, invalidation |
| Service-account OAuth | https://developers.google.com/identity/protocols/oauth2/service-account | JWT grant without gems |
| Requirements | `docs/proposal.md` | Source proposal |

**Example consumer**: `C:\Users\user\Dev\Tziburia` -- Flutter Android WebView app (`firebase_messaging`) for tziburia.co.za. Today it registers via the legacy `discourse-fcm-notifications` plugin (`GET /fcm_notifications/automatic_subscribe?token=` with session cookie from WebView JS) and opens notifications from `data.url` / `data.linked_obj_data`, requiring an absolute `https` URL on the forum host. It is the first migration target and the reference client stack is Flutter.

## 4. Project Structure

```
plugin.rb                     # metadata, settings, event subscription, plugin API registrations
lib/discourse_mobile_push/    # engine + autoloaded core logic (provider, payloads, classification)
app/controllers/discourse_mobile_push/   # mobile API + admin controllers
app/models/discourse_mobile_push/        # Device model
app/serializers/discourse_mobile_push/
app/services/problem_check/   # admin dashboard problem checks
jobs/regular/, jobs/scheduled/ # Jobs::*, required explicitly from plugin.rb
db/migrate/                   # plugin migrations
config/                       # settings.yml, routes.rb, locales/
assets/javascripts/discourse/ # admin plugin page (route map, initializer, templates)
spec/                         # requests/, models/, lib/, jobs/, fabricators/, system/
docs/                         # proposal, architecture, firebase, mobile-api, troubleshooting
```

## 5. Project Conventions

- Plugin name `discourse-mobile-push`; Ruby namespace `DiscourseMobilePush`; site settings and tables prefixed `mobile_push_`.
- The mobile API is versioned in the path (`/mobile-push/v1/...`); breaking changes require a new version.
- FCM tokens are secrets: never logged or displayed in full -- use a short SHA-256 fingerprint.
- Notification `data` values are strings (FCM requirement) and include an absolute `url`.
- Semantic versioning in `plugin.rb`, recorded in `CHANGELOG.md`.

---
*Generated for discourse-mobile-push on 2026-10-01. Mode: override.*
*Produced by the knowledge-priming-refiner skill.*
