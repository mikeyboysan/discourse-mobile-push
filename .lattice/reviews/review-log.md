# Review Log

## 2026-10-01 — mobile-push-v1 design (commit 1f2e224)
- **Scope**: approved design doc (L3 flows, L4 contracts); no code in delta (`.lattice/**` excluded by config, reviewed as design by request)
- **Atoms**: clean-code, knowledge-priming, architecture, secure-coding; custom: Mobile API Compatibility, Discourse Compatibility
- **Result**: 2 critical, 5 warning, 4 suggestion
- **Key findings**: registration conflict on (user, app_id, device_identifier) index; user deletion/anonymisation unspecified; admin API scoped to staff instead of admins
- **Strengths**: provider neutrality — FCM codes never cross the port; config errors can't delete devices; no post text in push data

## 2026-10-01 — slice 1: skeleton, settings, Device, DeviceRegistry, Device API (uncommitted)
- **Scope**: 25 files; config edge, core, persistence, inbound HTTP, specs, tooling
- **Atoms**: clean-code, knowledge-priming, architecture, secure-coding, test-quality; custom: Mobile API Compatibility, Discourse Compatibility
- **Result**: 0 critical, 3 warning, 5 suggestion
- **Key findings**: RateLimiter test without redis snapshotting; API-key scope and login only tested on POST; v1 API undocumented (borderline, docs planned slice 6)
- **Strengths**: tokens never leave the server (fingerprint, filter_attributes, log filter, body-only); savepoint retry handles races
- **Note**: the redis-snapshotting finding was later found invalid (core flushes Redis after every example); reverted in slice 2

## 2026-10-01 — slice 2: PushMessage, DeliveryResult, PushProvider port, FCM adapter (uncommitted)
- **Scope**: 18 files; core value objects, port, outbound adapter (`fcm/`), composition root, specs
- **Atoms**: clean-code, knowledge-priming, architecture, secure-coding, test-quality; custom: Discourse Compatibility
- **Result**: 0 critical, 1 warning, 5 suggestion
- **Key findings**: untested ServiceAccount error branches (non-string field, unparsable token_uri); blank access token cacheable; SENDER_ID_MISMATCH ambiguity deferred to slice 4 problem check
- **Strengths**: secrets contained — parsed key object, fixed parse messages, token scrubbing, token_uri allowlist; only explicit UNREGISTERED/token violations delete devices

## 2026-10-01 — slice 3: notification dispatch (uncommitted)
- **Scope**: 17 files; core, inbound event + job adapters, Redis persistence port, composition root, locale, specs
- **Atoms**: clean-code, knowledge-priming, architecture, secure-coding, test-quality; custom: Mobile API Compatibility, Discourse Compatibility
- **Result**: 0 critical, 3 warning, 2 suggestion
- **Key findings**: shipped push data contract undocumented; title wording rule in core (kept, logged); job's user-gone and missing-attempt paths untested (error paths again)
- **Strengths**: job re-resolves the device through the user's own devices; end-to-end spec drives a real PostCreator reply through the FCM adapter

## 2026-10-01 — slice 4: admin diagnostics API and problem check (uncommitted)
- **Scope**: 28 files; core, port, FCM adapter, admin HTTP adapters, problem check, routes, locales, docs, specs
- **Atoms**: clean-code, knowledge-priming, architecture, secure-coding, test-quality; custom: Mobile API Compatibility, Discourse Compatibility
- **Result**: 0 critical, 3 warning, 4 suggestion
- **Key findings**: array page param causes a 500; username match bypasses Discourse normalisation; health rule in the problem check adapter with one message for two causes
- **Strengths**: token secrecy verified in admin JSON and the staff log; config-error breadth tracked per device
