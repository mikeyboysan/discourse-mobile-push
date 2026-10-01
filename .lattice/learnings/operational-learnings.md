# Operational Learnings

Experiential patterns from practice. Complements standards (what should be) with experience (what we keep learning).

## Design Patterns
<!-- Decomposition, architecture choices, scope decisions that proved good or bad -->
- 2026-10-01 [design] Provider errors that are ambiguous between "bad message" and "bad recipient" (e.g. HTTP 400) — classify on the detailed error payload, never the status alone; config-class errors must never delete recipient records.
- 2026-10-01 [design] Fan-out to N external recipients — one job per recipient with per-job retries avoids duplicate sends without cross-recipient bookkeeping (in Discourse, retry by quiet re-enqueue: raised job errors are logged on every attempt).
- 2026-10-01 [review] New user-owned tables slip through design without deletion rules — decide user deletion/anonymisation behaviour (FK cascade, cleanup hook) at design time.
- 2026-10-01 [review] Provider errors that may mean "one recipient" or "whole configuration" (e.g. FCM `SENDER_ID_MISMATCH`) — classify as configuration, but make health alerts require breadth (several recipients) so one stray token cannot raise a permanent alarm.

## Implementation Craft
<!-- Coding approaches, library gotchas, design-to-reality gaps -->
- 2026-10-01 [design] Read the host framework's current source before designing against an extension point — docs lag (e.g. Discourse's push event fires before push filters; official plugins now live in core `plugins/`).
- 2026-10-01 [implementation] Windows checkout with `core.autocrlf=true` — generated files come out CRLF, which breaks bash scripts and formatter checks in Linux containers; force LF with `.gitattributes` (`* text=auto eol=lf`) and normalise before container runs.
- 2026-10-01 [implementation] Discourse migrations — `db:migrate` aborts on a migration timestamped in the future; use a timestamp at or before the current UTC time.
- 2026-10-01 [implementation] Bind-mounting a Windows repo into a container — host `node_modules` makes linters/`find` crawl through the mount (6.5 min vs 10 s); mask it with an anonymous volume and prune it in `find`.
- 2026-10-01 [implementation] Discourse core flushes Redis after every example (`spec/rails_helper.rb`); `use_redis_snapshotting` is a deprecated no-op, so specs using `RateLimiter.enable` or Redis caches need no extra isolation. Verify such review claims against the core test harness before acting on them.
- 2026-10-01 [implementation] Discourse's Zeitwerk inflector overrides match whole file basenames only (`http.rb` -> `HTTP`, but `http_client.rb` -> `HttpClient`); check `config/initializers/000-zeitwerk.rb` before naming plugin files with acronyms.
- 2026-10-01 [implementation] Ruby 3.4 ships `base64` as a bundled (not default) gem — encode base64url with `[bytes].pack("m0").tr("+/", "-_").delete("=")` instead of relying on `require "base64"`.
- 2026-10-01 [implementation] FCM HTTP v1 `android.priority` — send lowercase `"high"`/`"normal"` as in Firebase's examples, despite the REST reference listing enum names `HIGH`/`NORMAL`.

## Quality Signals
<!-- Recurring quality issues that keep appearing despite rules -->
- 2026-10-01 [review] Auth and API-key scope tests written only for the first endpoint — cover authentication and scope on every endpoint, especially logout/unregister paths that apps depend on.
- 2026-10-01 [review] Error paths keep slipping through (second review in a row) — parsers of untrusted or admin-supplied input need a spec for every explicit raise/rescue branch, not just the common failures.

## Reliability
<!-- Bug root causes, failure modes, fragile areas, boundary condition gaps -->
- 2026-10-01 [review] Upserts matched on more than one unique key — a matching order alone isn't enough; specify what happens when the other key is already taken, and handle concurrent inserts (transaction + rescue RecordNotUnique).
- 2026-10-01 [implementation] Discourse plugin `on(...)` handlers are skipped while the plugin is disabled — privacy/cleanup listeners (e.g. `:user_anonymized`) must use `DiscourseEvent.on` so data is still removed.

## Structural Health
<!-- Architectural drift, debt accumulation, coupling issues, migration lessons -->
