---
mode: overlay
---

> This document overlays project-specific customizations on top of the clean-code atom's embedded defaults. Only sections included here differ from the defaults -- all other sections remain as-is.
>
> Sections below replace matching sections in the defaults (matched by heading). New sections are appended after defaults.

**Table of contents:**

4. [Meaningful Naming](#4-meaningful-naming)

---

## 4. Meaningful Naming

Ruby naming follows community and `rubocop-discourse` conventions rather than prefix-based conventions from other languages.

### Naming Patterns

| Category | Convention | Good Examples | Poor Examples |
|----------|-----------|---------------|---------------|
| **Boolean variables** | Adjective/state name; `is_`/`has_` prefix only when a bare adjective would be ambiguous | `enabled`, `stale`, `configured` | `flag`, `check`, `status_bool` |
| **Predicate methods** | Trailing `?`, no `is_`/`has_` prefix | `stale?`, `configured?`, `retryable?` | `is_stale`, `has_config?`, `check_retryable` |
| **Raising/mutating variants** | Trailing `!` when a non-bang sibling exists or the call raises | `register!`, `deliver!` | `register_or_raise`, `deliver_unsafe` |
| **Functions (actions)** | Verb-first `snake_case` | `deliver`, `build_message`, `invalidate_device` | `delivery`, `message_builder`, `device_invalidation` |
| **Accessors/readers** | Bare noun, no `get_` prefix; `find_*`/`fetch_*` only for real lookups that may fail or hit storage | `token_fingerprint`, `project_id`, `find_device` | `get_token_fingerprint`, `get_project_id` |
| **Classes/modules** | `CamelCase` noun or noun phrase; acronyms as words | `PayloadBuilder`, `FcmProvider`, `DeviceRegistration` | `BuildPayload`, `FCMProvider`, `HandleDevices` |
| **Constants** | `SCREAMING_SNAKE_CASE`, frozen | `MAX_TOKEN_LENGTH`, `RETRYABLE_OUTCOMES` | `Max`, `n`, `LIMIT2` |
| **Collections** | Plural noun | `enabled_devices`, `retryable_results` | `list`, `data`, `arr` |
| **Hashes** | `x_by_y` | `devices_by_user_id`, `outcome_by_code` | `map`, `lookup`, `h` |
| **Settings** | `mobile_push_` prefix, describe effect | `mobile_push_privacy_mode` | `mp_mode`, `push_setting_1` |

### Names to Avoid

- **Single letters** beyond block params in one-line blocks (`devices.map { |d| d.id }` is fine; `d` in a multi-line method is not).
- **Abbreviations** needing project knowledge (`dev`, `tok`, `cfg`, `svc`) -- `id`, `url`, `json`, `fcm`, `api` are fine.
- **Generic names** (`data`, `info`, `result`, `obj`, `payload`) unless the scope is 2-3 lines or the name is the external contract (e.g. the Discourse alert `payload`).
- **Type-encoded names** (`token_str`, `devices_arr`).
- **Negated predicates** (`not_stale?`, `disabled_unless?`) -- use the positive form and negate at the call site.

### Scope-Length Rule

Name length is proportional to scope. A block variable in a one-line block can be short. A module-level constant used across classes must carry full context: `ACCESS_TOKEN_REFRESH_MARGIN_SECONDS`.

### Magic Numbers and Strings

Extraction test: **would a reader pause and ask "why this specific value?"** If yes, extract a named constant. If the value is self-evident from context, leave it inline.

| Scenario | Action | Example |
|----------|--------|---------|
| Meaning not self-evident | Extract named constant | `ACCESS_TOKEN_TTL = 1.hour`, `MAX_TOKEN_LENGTH = 4096` |
| Appears in multiple places | Extract named constant | FCM endpoint host used by client and specs |
| External protocol literal used once, next to its meaning | Leave inline | `"Bearer #{token}"`, `"application/json"` |
| Empty collection literal | Leave inline | `[]`, `{}` |
| HTTP status in framework call | Leave inline | `render json: ..., status: 422` |
| Duration via ActiveSupport | Leave inline when obvious | `30.days`, `5.minutes` |

---
*Generated for discourse-mobile-push on 2026-10-01. Mode: overlay.*
*Produced by the clean-code-refiner skill.*
