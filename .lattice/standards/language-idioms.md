---
language: ruby
version: "3.3+"
---

# Language Idioms: Ruby

Ruby as written inside a Discourse plugin (Rails engine, Zeitwerk autoloading).

## Error Handling

- Exceptions are the error mechanism. Define a namespaced base error (`DiscourseMobilePush::Error < StandardError`) and specific subclasses; rescue specific classes, never bare `rescue` or `rescue Exception`.
- Controllers raise Discourse's own errors (`Discourse::InvalidParameters`, `Discourse::NotFound`, `Discourse::InvalidAccess`) or use `render_json_error`; the framework maps them to HTTP responses.
- Expected outcomes of external calls (e.g. an FCM per-message rejection) are returned as result values, not raised.
- Background jobs re-raise only transient failures so Sidekiq retries them; permanent failures are recorded and swallowed.
- Log unexpected exceptions with `Discourse.warn_exception(e, message: ...)`; never include secrets in error messages.

## Type System & Object Model

- Dynamic duck typing; no Sorbet/RBS annotations.
- Plain Ruby objects (POROs) for services; ActiveRecord models only for persistence and simple invariants (validations, scopes).
- Immutable value objects via `Data.define` (Ruby 3.2+) for things like push messages and delivery results.
- Interfaces are expressed as a small base class whose abstract methods `raise NotImplementedError`; prefer composition over inheritance beyond that.
- Modules for namespacing; avoid mixins that hide state.

## Naming Conventions

- `snake_case` methods/variables, `CamelCase` classes/modules, `SCREAMING_SNAKE_CASE` constants.
- Predicates end in `?`; raising or mutating variants end in `!` (`find_by` vs `find_by!`).
- File paths match constant names exactly (Zeitwerk): `lib/discourse_mobile_push/fcm_provider.rb` -> `DiscourseMobilePush::FcmProvider`.
- Acronyms are written as words in constants: `FcmProvider`, `HttpClient`, `ApiKey`.
- Private helpers below a single `private` keyword.

## Testing Patterns

- RSpec: `describe` (class/method), `context "when ..."`, `it "does ..."` -- behaviour-focused descriptions.
- Fixtures via Fabrication: `fab!(:user)`; plugin fabricators in `spec/fabricators/`.
- Every plugin spec calls `enable_current_plugin` (and sets required site settings) in `before`.
- Request specs for HTTP API (`sign_in(user)`, `post "/mobile-push/v1/devices.json"`, `response.parsed_body`).
- External HTTP stubbed with WebMock `stub_request`; time with `freeze_time`; jobs with `expect_enqueued_with` / `Jobs.run_immediately!`.
- Spec files `*_spec.rb` mirror the source path under `spec/`.

## Parameter & Function Design

- Keyword arguments whenever there is more than one parameter or any optional parameter; no positional booleans.
- Controllers whitelist input with strong params (`params.require(...).permit(...)`).
- Return a `Data` value object rather than a loose hash when a result has several fields.
- Defaults belong in keyword-argument defaults, not in `opts = {}` hashes.

## Dependency Management

- No DI container. Inject collaborators through constructor keyword arguments with production defaults (`def initialize(provider: DiscourseMobilePush.provider)`) so tests can substitute fakes.
- Zeitwerk autoloads `app/` and `lib/`; `jobs/` files are `require_relative`'d from `plugin.rb`.
- Discourse globals (`SiteSetting`, `Discourse.redis`, `Jobs`) are used directly, but read at the edges (a settings/config object) rather than scattered through core logic.
- No new gems: Ruby stdlib (`OpenSSL`, `Net::HTTP`, `JSON`, `Digest`) plus what Discourse already provides.
