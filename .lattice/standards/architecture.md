---
mode: override
---

> These are the architecture principles for discourse-mobile-push, following a Hexagonal / Ports & Adapters architecture (Rails-pragmatic). This document is the sole reference for the `architecture` atom -- there are no embedded defaults.

**Table of contents:**

1. [Layer Definitions](#1-layer-definitions)
2. [Dependency Rules](#2-dependency-rules)
3. [Boundary Rules](#3-boundary-rules)
4. [Per-Layer Rules](#4-per-layer-rules)
5. [Key Flows](#5-key-flows)
6. [Validation Checklist](#6-validation-checklist)
7. [Anti-Patterns](#7-anti-patterns)
8. [Ambiguity Signals](#8-ambiguity-signals)

---

## 1. Layer Definitions

| Layer | Responsibility | Typical Directory |
|-------|---------------|-------------------|
| Core | Provider-neutral push logic: value objects, payload building, device registration and delivery use cases, outcome handling | `lib/discourse_mobile_push/` (top level) |
| Ports | Contracts the core uses to reach the outside: `PushProvider` | `lib/discourse_mobile_push/push_provider.rb` |
| Inbound adapters | Turn Discourse events, HTTP requests, jobs, and admin actions into core calls | `plugin.rb`, `lib/discourse_mobile_push/notification_listener.rb`, `app/controllers/`, `app/serializers/`, `jobs/`, `app/services/problem_check/`, `assets/javascripts/` |
| Outbound adapters | Implement ports and persistence: FCM HTTP v1 provider, ActiveRecord `Device` model | `lib/discourse_mobile_push/fcm/`, `app/models/discourse_mobile_push/` |
| Configuration edge | The only place that reads `SiteSetting` / `GlobalSetting` for plugin behaviour | `lib/discourse_mobile_push/settings.rb` |

### Directory Mapping

```
plugin.rb                                  # inbound wiring: event subscription, API scopes, problem check, admin route
lib/discourse_mobile_push/
├── engine.rb
├── settings.rb                            # configuration edge
├── push_message.rb, delivery_result.rb    # core value objects (Data.define)
├── payload_builder.rb                     # core: alert data -> PushMessage
├── device_registration.rb                 # core use case
├── delivery_service.rb                    # core use case
├── push_provider.rb                       # port
├── notification_listener.rb               # inbound adapter (DiscourseEvent -> job)
└── fcm/                                   # outbound adapter (provider, access token, HTTP client, error classifier)
app/models/discourse_mobile_push/          # persistence (Device)
app/controllers/discourse_mobile_push/     # inbound HTTP (mobile API, admin API)
app/serializers/discourse_mobile_push/
app/services/problem_check/                # inbound: admin dashboard
jobs/regular/, jobs/scheduled/             # inbound async
assets/javascripts/discourse/              # admin UI
```

---

## 2. Dependency Rules

```
   Inbound adapters ──────┐
   (listener, controllers,│
    jobs, admin, problem  ▼
    check)            ┌────────┐       ┌───────────┐
                      │  Core  │──────▶│   Ports   │◀──── Outbound adapters
   Configuration ────▶│        │       │PushProvider│      (fcm/)
   edge (Settings)    └────────┘       └───────────┘
                          │
                          ▼
        Device (ActiveRecord), DiagnosticsStore (Redis) -- persistence ports
```

- Inbound adapters depend on Core. Core never references controllers, jobs, serializers, `params`, `DiscourseEvent`, or the admin UI.
- Outbound adapters implement Ports. Core depends on the `PushProvider` contract, never on `Fcm::*`.
- Core may use the `DiscourseMobilePush::Device` ActiveRecord model and the Redis-backed `DiagnosticsStore` directly; they are the persistence ports (Rails-pragmatic exception).
- `DiscourseMobilePush.provider` (which builds the concrete provider) is defined in the composition root, `plugin.rb`; core files never name `Fcm::*`.
- Core receives configuration as a `Settings` object (injected or via `DiscourseMobilePush.settings`), never by calling `SiteSetting` directly.
- Discourse internals (`DiscourseEvent`, `PostAlerter` payload keys, `Guardian`, `Jobs`, `SiteSetting`, `Discourse.redis`) appear only in adapters or the configuration edge. When an internal API must be used, it is isolated in exactly one place.

**Data crossing boundaries**: immutable `Data` value objects (`PushMessage`, `DeliveryResult`) and plain primitives. Job arguments are JSON-safe hashes of primitives. Firebase-specific structures and error codes never leave `fcm/`.

---

## 3. Boundary Rules

- Inbound adapters call core use cases through plain method calls with keyword arguments.
- Core reaches the outside only through the `PushProvider` port: `deliver(message:, token:) -> DeliveryResult`. Results carry a provider-neutral outcome: `:delivered`, `:invalid_device`, `:retryable`, `:config_error`, `:rejected`, plus a sanitized detail string.
- Dependency injection is manual: constructor keyword arguments with production defaults (`provider: DiscourseMobilePush.provider`). No DI container, no global mutable state beyond Discourse's own.
- Asynchrony is an adapter concern: the listener enqueues a job; the job invokes the delivery use case. Core is synchronous.
- Retry policy lives in the job adapter, driven by the core's neutral outcomes (`:retryable` -> the job re-enqueues itself with backoff and an attempt counter; only the final failure is logged).

---

## 4. Per-Layer Rules

### Core

**What belongs here:**
- Value objects, payload building (privacy mode, priority, deep-link data), device registration (idempotent upsert, ownership, per-user cap), delivery orchestration, outcome handling (remove invalid devices, record success/failure).

**What does not belong here:**
- HTTP, JSON wire formats of any provider, OAuth, Firebase error codes.
- `SiteSetting`, `DiscourseEvent`, `Jobs`, controllers, serializers, `Guardian`.

**Common violations:**
- Branching on `"UNREGISTERED"` or other FCM codes in core.
- Reading `SiteSetting.mobile_push_*` inside a core class.

### Ports

**What belongs here:**
- `PushProvider` base class: abstract `deliver(message:, token:)` and `configured?`, raising `NotImplementedError`.

**What does not belong here:**
- Any implementation logic or provider-specific types.

**Common violations:**
- Adding FCM-only parameters (e.g. `android_config`) to the port signature.

### Inbound adapters

**What belongs here:**
- Request parsing, strong params, authentication/authorization (`ensure_logged_in`, admin checks), serialization, job enqueueing, translating the Discourse alert payload into core input, admin UI.

**What does not belong here:**
- Business rules (device upsert logic, payload policy, outcome handling).
- Direct FCM calls.

**Common violations:**
- Controller performing device dedupe/ownership logic inline.
- Event listener building the push payload itself.

### Outbound adapters

**What belongs here:**
- `fcm/`: service-account parsing, JWT signing (OpenSSL), access-token caching, HTTP v1 requests (`Net::HTTP`), error classification into neutral outcomes.
- `app/models/`: `Device` schema mapping, validations, scopes.

**What does not belong here:**
- Decisions about which devices to notify or whether to delete a device (core decides from the neutral outcome).

**Common violations:**
- FCM adapter deleting `Device` rows directly.
- Model callbacks that enqueue deliveries.

### Configuration edge

**What belongs here:**
- Reading and normalising plugin settings (enabled, project id, credentials, privacy mode, priorities, limits) into a `Settings` object.

**What does not belong here:**
- Business logic; network calls.

**Common violations:**
- Parsing the service-account JSON in multiple places.

---

## 5. Key Flows

### Flow 1: Notification delivery

```
Discourse PostAlerter.push_notification(user, payload)
  -> DiscourseEvent :push_notification            [inbound: NotificationListener]
     - skip if plugin disabled, user has no devices, or a push_notification_filter rejects
     - enqueue Jobs::DiscourseMobilePush::DeliverToDevice(user_id:, device_id:, payload:, attempt: 1) per device
  -> Job.execute                                   [inbound: job]
     - AlertMapper.from_payload(payload) -> Alert; PayloadBuilder.build(alert:, locale:) -> PushMessage   [core]
     - DeliveryService.deliver(message:, device:)                           [core]
         provider.deliver(message:, token:)                                 [port -> fcm adapter]
         apply outcome: :invalid_device -> destroy device; :delivered -> touch; record diagnostics
     - :retryable outcome -> re-enqueue self with backoff until max attempts (quiet; final failure logged)
```

### Flow 2: Device registration

```
POST /mobile-push/v1/devices                      [inbound: DevicesController]
  - ensure_logged_in; strong params; current_user is the owner
  - DeviceRegistration.call(user:, attributes:) -> Device   [core]
      find by token -> reassign/update; else by (user, app_id, device_identifier) -> update token; else create
      enforce per-user device cap
  - render serialized device (masked token)
```

---

## 6. Validation Checklist

STOP after generating each component. Verify ALL of the following before proceeding:

1. **LAYER PLACEMENT**: Is each class in the layer and directory listed in §1?
2. **DEPENDENCY DIRECTION**: Does core reference only core, ports, the `Device` model, and `Settings` -- never `Fcm::*`, controllers, jobs, `SiteSetting`, or `DiscourseEvent`?
3. **PROVIDER NEUTRALITY**: Do Firebase-specific codes, payload shapes, and HTTP details stay inside `fcm/`, with only neutral outcomes crossing the port?
4. **DISCOURSE ISOLATION**: Is each Discourse internal API (event name, alert payload keys, filters, Guardian) used in exactly one adapter?
5. **BOUNDARY DATA**: Do values crossing layers use `Data` value objects or primitives, and are job args JSON-safe?
6. **ASYNC BOUNDARY**: Does every external network call happen in a job, never in a web request (except the explicit admin test-send, which is still enqueued or clearly bounded)?
7. **SECRETS**: Are tokens, private keys, and access tokens kept out of logs, serializers, and error strings (fingerprints only)?

---

## 7. Anti-Patterns

After verifying the checklist above, scan output for these anti-patterns. If found, fix before presenting.

- [ ] **Provider leak**: FCM error strings or message JSON appear outside `fcm/` -> map them to neutral outcomes inside the adapter and pass `DeliveryResult` instead.
- [ ] **Fat controller**: registration/dedupe/ownership logic in a controller -> move it into `DeviceRegistration` and have the controller only parse, authorize, and render.
- [ ] **Settings sprawl**: `SiteSetting.mobile_push_*` read in core or adapters other than `Settings` -> route through the `Settings` object.
- [ ] **Synchronous push**: FCM called inside a request or event callback -> enqueue a job.
- [ ] **Adapter decides policy**: FCM adapter deletes devices or chooses which devices to notify -> return an outcome; let `DeliveryService` act on it.
- [ ] **Callback-driven side effects**: ActiveRecord callbacks enqueue jobs or call providers -> trigger from explicit use cases or adapters.
- [ ] **Notification engine creep**: plugin inspects posts/topics to decide who to notify -> rely solely on the `:push_notification` event.

---

## 8. Ambiguity Signals

These checks often have multiple valid outcomes. When you encounter one, present options rather than silently choosing.

- Whether translating the Discourse alert payload belongs in the inbound adapter (Discourse-specific keys) or in core `PayloadBuilder` (policy) -- keep key extraction thin in the adapter, policy in core, and flag when the split is unclear.
- Delivery granularity: one job per notification fanning out to devices vs one job per device (affects retries and duplicate sends).
- Whether diagnostics/state (last success, last failure) are stored on `Device` rows, in Redis, or in a dedicated table.
- Whether an outcome is `:rejected` (bad message) vs `:invalid_device` when the provider's signal is ambiguous (e.g. FCM `INVALID_ARGUMENT`).

---
*Generated for discourse-mobile-push on 2026-10-01. Style: Hexagonal / Ports & Adapters (Rails-pragmatic).*
*Produced by the architecture-refiner skill.*
