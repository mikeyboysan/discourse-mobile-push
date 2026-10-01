# Mobile API (v1)

Reference for apps that register devices with `discourse-mobile-push`. The API is versioned in the path; breaking changes ship under a new version (`/mobile-push/v2/...`) and v1 keeps working.

All endpoints return JSON. Send request bodies as JSON (`Content-Type: application/json`) or form data.

## Authentication

Every endpoint acts on the signed-in user's own devices. Device ownership always comes from the authenticated user; a client-supplied user ID is never accepted.

| Method | How | Notes |
|---|---|---|
| Session cookie | Cookie from a normal login, plus an `X-CSRF-Token` header on `POST`/`DELETE` | Suits WebView apps; fetch the token from `/session/csrf.json` |
| User API key | `User-Api-Key` header | The key needs the `discourse-mobile-push:devices` scope. An admin must first add that scope to the `allow_user_api_key_scopes` site setting |
| Admin API key | `Api-Key` and `Api-Username` headers | For server-side tooling |

Unauthenticated requests get `403`. When the plugin is disabled every endpoint returns `404`.

## Register a device

`POST /mobile-push/v1/devices`

Call this on every app start and whenever the push token changes. Registration is idempotent.

| Field | Required | Rules |
|---|---|---|
| `platform` | yes | `android` or `ios` |
| `app_id` | yes | Your app's package / bundle ID, e.g. `com.example.app`. Letters, digits, `.`, `_`, `-`; up to 255 characters; must be in `mobile_push_allowed_app_ids` when that setting is not empty |
| `token` | yes | The FCM registration token. 1–1024 characters, no whitespace. **Body only**: a `token` in the query string is rejected with `400` |
| `app_version` | no | Up to 50 characters |
| `device_identifier` | no | A stable per-install ID you generate (up to 255 characters). Lets the server replace the old token when FCM rotates it |

```json
{
  "platform": "android",
  "app_id": "com.example.app",
  "token": "fcm-registration-token",
  "app_version": "1.4.0",
  "device_identifier": "6f1c2a9e-1b7d-4c55-9a39-5f2d0a7c8e11"
}
```

How the server matches an existing registration, in order:

1. Same `token` → that device is updated. If another user registered it, it moves to the current user (for example after a logout and a login as someone else).
2. Same `app_id` and `device_identifier` for this user → the device's token is replaced.
3. Otherwise a new device is created. If the user now has more than `mobile_push_max_devices_per_user` devices, the least recently seen ones are removed.

Responses:

| Status | Meaning |
|---|---|
| `201` | Device created |
| `200` | Existing device updated |
| `400` | Missing field, non-string value, or token in the query string |
| `422` | Validation failed (`errors` lists the reasons) |
| `429` | More than 20 registrations per minute for this user |

```json
{
  "device": {
    "id": 42,
    "platform": "android",
    "app_id": "com.example.app",
    "app_version": "1.4.0",
    "device_identifier": "6f1c2a9e-1b7d-4c55-9a39-5f2d0a7c8e11",
    "token_fingerprint": "3fa1c09b7e22",
    "last_seen_at": "2026-10-01T10:00:00.000Z",
    "created_at": "2026-09-01T08:30:00.000Z"
  }
}
```

The full token is never returned. `token_fingerprint` is a short, non-reversible digest you can use to recognise a device.

## List devices

`GET /mobile-push/v1/devices` returns `200` with `{ "devices": [ ... ] }`: the current user's devices, most recently seen first, in the same shape as above.

## Unregister a device

Call one of these on logout so the device stops receiving the user's notifications.

| Request | Success | Errors |
|---|---|---|
| `DELETE /mobile-push/v1/devices/:id` | `204` | `404` if the device does not exist or belongs to someone else |
| `DELETE /mobile-push/v1/devices` with body `{ "token": "..." }` | `204` | `400` for a token in the query string; `404` if the current user has no device with that token |

## Errors

Error responses use Discourse's standard shape:

```json
{ "errors": ["Platform is not included in the list"], "error_type": "record_invalid" }
```

## Push payload

The push `data` payload delivered to devices is documented here once notification delivery ships.
