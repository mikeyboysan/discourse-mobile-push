# Mobile API (v1)

Reference for apps that register devices with `discourse-mobile-push`. The API is versioned in the path; breaking changes ship under a new version (`/mobile-push/v2/...`) and v1 keeps working.

Within v1, new optional request fields, response fields, push `data` keys and `data.type` values may be added. Apps should ignore keys and types they don't recognise.

All endpoints return JSON. Send request bodies as JSON (`Content-Type: application/json`) or form data.

## Typical app flow

1. The user signs in to Discourse from the app (for example by obtaining a User API key with the `discourse-mobile-push:devices` scope).
2. The app gets its FCM registration token from the Firebase SDK and [registers the device](#register-a-device).
3. On every app start, and whenever the Firebase SDK reports a new token, the app registers again. Registration is idempotent.
4. When a push arrives and the user taps it, the app opens the `url` from the [push payload](#push-payload).
5. On logout, the app [unregisters the device](#unregister-a-device) before discarding its credentials.

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
| `429` | More than 20 registrations per minute for this user (staff are exempt) |

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

Each Discourse push notification arrives as an FCM message with a `notification` (title and body) and a `data` map. All `data` values are strings.

| Key | Always present | Value |
|---|---|---|
| `type` | yes | `notification`, or `test` for an administrator's test notification (see below) |
| `notification_type` | for `notification` | Discourse notification type name, e.g. `replied`, `mentioned`, `private_message`, `chat_mention`; `unknown` for types Discourse does not name |
| `notification_type_id` | when known | Discourse's numeric notification type, as a string |
| `url` | yes | Absolute URL of the content to open, always on the forum's own host. Falls back to the forum's base URL when the notification has no link |
| `topic_id` | for post notifications | Topic ID |
| `post_number` | for post notifications | Post number within the topic |
| `post_id` | for post notifications | Post ID |
| `channel_id` | for chat notifications | Chat channel ID |

`data` never contains post or message text. Fetch content from Discourse when the user opens the notification.

```json
{
  "notification": {
    "title": "jane replied to you in \"Welcome\" - Example Forum",
    "body": "Thanks, that worked!"
  },
  "data": {
    "type": "notification",
    "notification_type": "replied",
    "notification_type_id": "2",
    "url": "https://forum.example.com/t/welcome/10/2",
    "topic_id": "10",
    "post_number": "2",
    "post_id": "20"
  }
}
```

**Title and body** depend on the `mobile_push_privacy_mode` site setting:

- `full`: the same title Discourse uses for browser push notifications, and the post or message excerpt as the body.
- `generic`: the site title, and "You have a new notification" (translated into the user's locale) as the body.

Titles are truncated to 150 characters and bodies to 500.

**Priority**: notification types listed in `mobile_push_high_priority_notification_types` (by default `private_message`, `mentioned` and `chat_mention`) are sent with Android `high` priority; everything else uses `normal`.

**iOS**: devices registered with `platform: "ios"` receive the same message through Firebase's APNs integration (the Firebase project needs an APNs key). v1 sets no APNs-specific options, so the priority setting applies to Android only.

**Test notifications**: an administrator can send a test notification to a device from the admin diagnostics. Its `data` contains only `type` (`test`) and `url` (the forum's base URL); it is sent with `high` priority and the same text in every privacy mode. Apps should open the forum's home page, or simply show it.

**Delivery**: Discourse's own rules decide who is notified, including do-not-disturb and push notification filters from other plugins. Pushes are sent straight away, even while the user is active on the website (Discourse's `push_notification_time_window_mins` delay applies only to browser push). Temporary Firebase failures are retried with backoff. A device whose token Firebase reports as unregistered or invalid is removed; the app re-registers it on its next start.
