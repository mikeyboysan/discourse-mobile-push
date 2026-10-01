# Operational Learnings

Experiential patterns from practice. Complements standards (what should be) with experience (what we keep learning).

## Design Patterns
<!-- Decomposition, architecture choices, scope decisions that proved good or bad -->
- 2026-10-01 [design] Provider errors that are ambiguous between "bad message" and "bad recipient" (e.g. HTTP 400) — classify on the detailed error payload, never the status alone; config-class errors must never delete recipient records.
- 2026-10-01 [design] Fan-out to N external recipients — one job per recipient with per-job retries avoids duplicate sends without cross-recipient bookkeeping (in Discourse, retry by quiet re-enqueue: raised job errors are logged on every attempt).
- 2026-10-01 [review] New user-owned tables slip through design without deletion rules — decide user deletion/anonymisation behaviour (FK cascade, cleanup hook) at design time.
- 2026-10-01 [review] Health verdicts shown in more than one place (dashboard problem check, admin page) belong in a core use case that returns a reason, not in the problem check adapter.
- 2026-10-01 [review] Lists with inline delete actions and offset-based paging skip a record on the next page after each delete — decide the paging scheme (cursor vs offset) at design time.
- 2026-10-01 [review] When adding a channel alongside a core feature (mobile push next to browser push), list where its behaviour differs from core (delays, filters, preferences) and document those differences.
- 2026-10-01 [review] Provider errors that may mean "one recipient" or "whole configuration" (e.g. FCM `SENDER_ID_MISMATCH`) — classify as configuration, but make health alerts require breadth (several recipients) so one stray token cannot raise a permanent alarm.

## Implementation Craft
<!-- Coding approaches, library gotchas, design-to-reality gaps -->
- 2026-10-01 [design] Read the host framework's current source before designing against an extension point — docs lag (e.g. Discourse's push event fires before push filters; official plugins now live in core `plugins/`).
- 2026-10-01 [implementation] Windows checkout with `core.autocrlf=true` — generated files come out CRLF, which breaks bash scripts and formatter checks in Linux containers; force LF with `.gitattributes` (`* text=auto eol=lf`) and normalise before container runs.
- 2026-10-01 [implementation] Discourse migrations — `db:migrate` aborts on a migration timestamped in the future; use a timestamp at or before the current UTC time.
- 2026-10-01 [implementation] Bind-mounting a Windows repo into a container — host `node_modules` makes linters/`find` crawl through the mount (6.5 min vs 10 s); mask it with an anonymous volume and prune it in `find`.
- 2026-10-01 [implementation] Local lint green, CI Prettier red on `.gjs` — the local gate used core's `@discourse/lint-configs` (different `prettier-plugin-ember-template-tag`) while CI uses the plugin's lockfile; run frontend linters from the plugin's own dependencies, as CI does.
- 2026-10-01 [implementation] Discourse core flushes Redis after every example (`spec/rails_helper.rb`); `use_redis_snapshotting` is a deprecated no-op, so specs using `RateLimiter.enable` or Redis caches need no extra isolation. Verify such review claims against the core test harness before acting on them.
- 2026-10-01 [implementation] Discourse's Zeitwerk inflector overrides match whole file basenames only (`http.rb` -> `HTTP`, but `http_client.rb` -> `HttpClient`); check `config/initializers/000-zeitwerk.rb` before naming plugin files with acronyms.
- 2026-10-01 [implementation] Ruby 3.4 ships `base64` as a bundled (not default) gem — encode base64url with `[bytes].pack("m0").tr("+/", "-_").delete("=")` instead of relying on `require "base64"`.
- 2026-10-01 [implementation] Discourse push titles — `discourse_push_notifications.popup.*` is missing for many notification types and plugins define some as nested hashes (chat's `chat_mention`); guard with `I18n.exists?` and a `String` check, falling back to a generic title.
- 2026-10-01 [implementation] Discourse `fab!` refinds its record on first access — a record deleted during the example and then referenced raises `RecordNotFound`; use `let!` for records the test deletes (recurred in slice 3).
- 2026-10-01 [implementation] Ruby helpers mixing an optional positional hash with keyword options — `helper(key: v)` binds to keywords and raises "unknown keyword"; take `**overrides` alongside the keyword options instead.
- 2026-10-01 [implementation] rubocop-discourse flags `Time.zone.now + 60.seconds` (`Rails/DurationArithmetic`); write `60.seconds.from_now`.
- 2026-10-01 [implementation] FCM HTTP v1 `android.priority` — send lowercase `"high"`/`"normal"` as in Firebase's examples, despite the REST reference listing enum names `HIGH`/`NORMAL`.
- 2026-10-01 [implementation] rubocop-discourse `Discourse/Plugins/CallRequiresPlugin` forces `requires_plugin` on every plugin controller, admin ones included — admin endpoints 404 while the plugin is disabled, so don't design admin flows that need them before enabling.
- 2026-10-01 [implementation] Discourse plugin problem checks — `app/services/problem_check/<name>.rb`, `require_relative` + `register_problem_check` in `after_initialize`, locale `dashboard.problem.<identifier>` (interpolates `%{base_path}`); without `perform_every` the check runs on every dashboard load, so keep it to cheap queries.
- 2026-10-01 [implementation] Discourse `RateLimiter` skips staff unless `apply_limit_to_staff: true` (needed for admin-only actions); rate-limit specs must call `RateLimiter.enable`.
- 2026-10-01 [review] Matching on usernames — resolve through Discourse (`User.find_by_username` / `User.normalize_username`), never a hand-rolled `downcase` (Unicode usernames).
- 2026-10-01 [implementation] Red lint stage — diagnose by running `rubocop --format simple` / `script/i18n_lint.rb` directly in the test container rather than opening the stage log.
- 2026-10-01 [implementation] Discourse does not load a disabled plugin's frontend code — "plugin disabled" states inside the plugin's own UI are unreachable dead code; don't build or spec them.
- 2026-10-01 [implementation] Discourse plugin admin page — `add_admin_route ..., use_new_show_route: true`, a route map under `admin.adminPlugins.show`, `api.addAdminPluginConfigurationNav` in an initializer, admin code under `admin/assets/javascripts`, and a server route `get "/admin/plugins/<id>/<tab>" => "admin/plugins#index"` so a hard refresh works.
- 2026-10-01 [implementation] Discourse system specs run under `docker:test` only with `RUN_SYSTEM_TESTS=1` — confirm a new gate stage actually executes them by checking the system example count.
- 2026-10-01 [implementation] Before planning GitHub-side release steps (tags, releases, repo settings), check `gh auth status` and `gh api repos/<owner>/<repo> --jq .permissions` — git push and `gh` can be signed in as different accounts.
- 2026-10-01 [implementation] Discourse plugin metadata — core parses `meta_topic_id` with `Integer()`, so a placeholder is silently dropped (remove it until a topic exists); a comment-only `.discourse-compatibility` parses as empty and is safe to ship.
- 2026-10-01 [implementation] Deleting a key from a locale YAML — check the surrounding lines; a lost newline breaks parsing and only the i18n lint step catches it.

## Quality Signals
<!-- Recurring quality issues that keep appearing despite rules -->
- 2026-10-01 [review] Auth and API-key scope tests written only for the first endpoint — cover authentication and scope on every endpoint, especially logout/unregister paths that apps depend on.
- 2026-10-01 [implementation] Public API docs should state the forward-compatibility rule (clients ignore unknown fields and types) from the first release, so later additive changes aren't breaking.
- 2026-10-01 [review] A slice that ships a contract external clients consume (e.g. the push `data` payload) must update its reference doc and changelog in the same slice — don't defer to a later docs slice.
- 2026-10-01 [review] Jobs that re-load records by id — test the "record gone" path for every record loaded (user and device), not only the main one.
- 2026-10-01 [review] Controllers coercing query params with `to_i`/`downcase` crash with a 500 on array params (`?page[]=1`) — validate the type of every query param, not only body params.
- 2026-10-01 [review] UI components that start overlapping loads (filter, paging) must ignore responses from requests that are no longer the latest, or a slow earlier response overwrites newer results.
- 2026-10-01 [review] Error paths keep slipping through (second review in a row) — parsers of untrusted or admin-supplied input need a spec for every explicit raise/rescue branch, not just the common failures.

## Reliability
<!-- Bug root causes, failure modes, fragile areas, boundary condition gaps -->
- 2026-10-01 [review] Upserts matched on more than one unique key — a matching order alone isn't enough; specify what happens when the other key is already taken, and handle concurrent inserts (transaction + rescue RecordNotUnique).
- 2026-10-01 [implementation] Discourse plugin `on(...)` handlers are skipped while the plugin is disabled — privacy/cleanup listeners (e.g. `:user_anonymized`) must use `DiscourseEvent.on` so data is still removed.

## Structural Health
<!-- Architectural drift, debt accumulation, coupling issues, migration lessons -->
