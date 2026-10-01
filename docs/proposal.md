# Proposed Generic Discourse Mobile Push Notification Plugin

## 1. Executive Summary

This document proposes a new, generic Discourse plugin for delivering Discourse notifications to native mobile applications using Firebase Cloud Messaging (FCM).

The proposed plugin should be designed from the outset as a reusable open-source component rather than as a site-specific integration. It should allow any Discourse administrator who operates a compatible Android or iOS application to connect that application to their Discourse installation and deliver relevant Discourse notifications to users' mobile devices.

The proposed plugin will:

- integrate with Discourse's existing notification system;
- maintain a secure association between Discourse users and their registered mobile devices;
- support multiple devices per user;
- expose a documented API for mobile applications to register and unregister devices;
- deliver push notifications asynchronously through background jobs;
- use Firebase's modern HTTP v1 messaging interface;
- avoid unnecessary or obsolete Firebase-specific Ruby dependencies;
- remove invalid or expired device registrations automatically;
- provide meaningful diagnostics to administrators;
- provide a configurable notification payload;
- allow the mobile application to open the relevant Discourse content when a notification is tapped;
- be designed so that the Firebase delivery mechanism can eventually be replaced or supplemented by other push providers.

The design deliberately separates three concerns:

1. **Discourse notification generation** — deciding that a user has something to be notified about.
2. **Push notification delivery** — delivering that notification to a registered mobile device.
3. **Mobile application behaviour** — displaying the notification and responding when the user taps it.

This separation is intended to make the plugin maintainable, testable and useful to a broad range of Discourse-based applications.

---

# 2. Motivation

## 2.1 The problem

Discourse is primarily a web application. Users can receive notifications through the Discourse web interface and through email, but applications that provide a native mobile experience often require push notifications to make the application feel like a proper mobile application.

A native application needs a mechanism such as:

> Discourse notification → mobile push service → device

The existing ecosystem contains implementations of this concept, but a reusable solution should be designed around current Discourse and Firebase technologies rather than around legacy dependencies or assumptions made by an individual application.

## 2.2 Why build a new plugin?

A new implementation provides an opportunity to establish a clean architecture rather than indefinitely maintaining an older implementation.

In particular, the plugin should avoid coupling itself unnecessarily to a large collection of Firebase-related Ruby gems.

Firebase currently provides the FCM HTTP v1 API for sending messages to individual registration tokens, topics and other targets. Firebase also provides official server-side libraries for several languages.

The HTTP v1 protocol provides a particularly clear boundary:

```text
Discourse
    |
    | HTTPS + OAuth 2
    v
Firebase Cloud Messaging
    |
    v
Mobile application
```

This makes the Firebase integration conceptually simple and reduces the amount of Firebase-specific functionality that needs to live inside the Discourse plugin.

## 2.3 Avoiding unnecessary dependency risk

A Discourse plugin is installed inside the Discourse application and therefore participates in its Ruby/Bundler dependency environment.

A plugin that introduces an unnecessarily complicated dependency tree can make future Discourse upgrades more difficult.

The proposed plugin should therefore have a design goal of:

> **Minimum dependencies necessary to provide the functionality.**

The Firebase integration should not require a large framework when a small, well-defined HTTP client and authentication mechanism can perform the required operations reliably.

Where an official Google library is justified, it should be evaluated against the alternative of implementing only the small subset of OAuth/HTTP functionality required by the plugin.

This decision should be revisited during implementation rather than assumed in advance.

---

# 3. Goals

The plugin should have the following primary goals.

## 3.1 Functional goals

The plugin must:

- register mobile devices;
- associate devices with Discourse users;
- support multiple devices per user;
- send push notifications to individual devices;
- send notifications to all eligible devices belonging to a user;
- remove invalid device registrations;
- support notification preferences;
- support Android;
- be architecturally capable of supporting iOS;
- provide a documented mobile API;
- integrate with Discourse's existing notification model;
- operate asynchronously;
- provide useful administrative diagnostics.

## 3.2 Engineering goals

The plugin should:

- be compatible with modern Discourse versions;
- minimise dependencies;
- avoid modifying Discourse core;
- use supported plugin extension mechanisms;
- be testable independently;
- fail gracefully;
- avoid blocking normal Discourse requests;
- keep credentials outside application code;
- avoid storing more device information than necessary;
- be suitable for publication as an open-source plugin.

## 3.3 Non-goals

The plugin should not attempt to become:

- a replacement for Discourse's notification system;
- a complete mobile application;
- a user authentication framework;
- a Firebase administration console;
- a general-purpose messaging system;
- a replacement for email notifications;
- a replacement for Discourse Chat;
- a mechanism for deciding which Discourse events constitute notifications.

The plugin should deliver notifications generated by Discourse rather than reinventing Discourse's notification rules.

---

# 4. Architectural Overview

The proposed architecture is:

```text
                         DISCOURSE
                             |
                             |
                  Existing notification
                         mechanisms
                             |
                             v
                  Push notification adapter
                             |
                             v
                    Background job queue
                             |
                             v
                    Push delivery service
                             |
                             v
                Firebase Cloud Messaging
                             |
                 +-----------+-----------+
                 |                       |
                 v                       v
             Android                  iOS
             device                  device
```

The key architectural boundary is the **push notification adapter**.

Discourse determines:

> "User X has a new notification."

The plugin determines:

> "User X has these registered mobile devices."

The Firebase implementation determines:

> "Here is how to deliver this push message."

The mobile application determines:

> "Here is how to display the notification and what to do when it is tapped."

---

# 5. Integration With Discourse

## 5.1 Use Discourse's notification system

The plugin should integrate with Discourse's existing notification mechanisms rather than attempting to identify interesting events by monitoring arbitrary posts.

This is important because Discourse already understands concepts such as:

- replies;
- mentions;
- private messages;
- watched topics;
- followed topics;
- user notifications;
- notification preferences.

Duplicating those rules would create unnecessary complexity and could cause inconsistencies between web notifications and mobile notifications.

The plugin should therefore act primarily as a **delivery channel** for notifications that Discourse has already determined are relevant.

## 5.2 Avoid modifying Discourse core

The plugin should use documented or stable plugin extension points wherever possible.

Discourse provides a dedicated plugin development framework, including plugin settings, admin interfaces, acceptance tests and publishing mechanisms.

The plugin should not require changes to Discourse core.

This is essential for maintainability because Discourse is updated frequently.

---

# 6. Device Registration

## 6.1 Device registration concept

A user may have:

- one phone;
- several phones;
- a phone and tablet;
- multiple installations of the same application.

The database must therefore not store a single FCM token directly on the Discourse user record.

Instead, a separate device-registration record should be used.

Conceptually:

```text
MobileDevice
------------
id
user_id
platform
app_id
device_identifier
fcm_token
app_version
enabled
created_at
updated_at
last_seen_at
```

Some of these fields may be optional depending on the final implementation.

## 6.2 Why a separate table?

A separate table provides:

- multiple devices per user;
- independent token lifecycle;
- device-level invalidation;
- support for multiple applications;
- future platform support;
- better diagnostics;
- no pollution of the core Discourse User model.

## 6.3 FCM tokens

An FCM registration token identifies a particular client app instance.

Firebase explicitly recommends that registration tokens be treated as sensitive information and stored securely.

The plugin should therefore:

- never display complete tokens in normal administrator screens;
- avoid putting tokens into ordinary log messages;
- restrict access to device records;
- never expose another user's token through the mobile API;
- delete tokens when they are known to be invalid.

---

# 7. Mobile Application API

The plugin should expose a small, versioned API.

For example:

```text
POST   /mobile-push/v1/devices
GET    /mobile-push/v1/devices
DELETE /mobile-push/v1/devices/:id
```

The exact Discourse routing conventions should be determined during implementation.

## 7.1 Register device

The mobile application authenticates as a Discourse user and submits:

```json
{
  "platform": "android",
  "app_id": "com.example.application",
  "fcm_token": "...",
  "app_version": "1.2.3"
}
```

The server should associate the registration with the authenticated Discourse user.

The API must never accept an arbitrary `user_id` supplied by the application as the basis for ownership.

The authenticated Discourse identity should determine the user.

## 7.2 Idempotency

Registering the same device/token repeatedly should not create unlimited duplicate records.

The endpoint should be effectively idempotent.

For example:

```text
Application starts
        |
        v
Get FCM token
        |
        v
POST registration
        |
        +---- existing registration → update it
        |
        +---- new registration → create it
```

This is important because mobile applications may register their token whenever they start or whenever Firebase reports a token refresh.

## 7.3 Token refresh

FCM registration tokens can change.

The mobile application should therefore be expected to notify the server whenever its current token changes.

The plugin should treat this as an update rather than as a new device unless the supplied device identity indicates otherwise.

---

# 8. Authentication and Security

## 8.1 User authentication

The mobile API should use Discourse's existing authenticated-user mechanisms wherever possible.

The plugin should not invent a second password or account system.

## 8.2 Server credentials

Firebase credentials must remain server-side.

They must never be embedded in:

- the mobile application;
- the plugin's public source code;
- client-side JavaScript;
- an API response.

Firebase documents service-account credentials and Application Default Credentials as mechanisms for authorising server-side FCM requests.

## 8.3 Configuration

The plugin should support secure configuration through the mechanisms appropriate to the Discourse deployment.

Possible configuration values include:

```text
Firebase project ID
Firebase service-account credentials
```

The exact credential-storage mechanism should be selected during implementation with particular attention to Discourse's existing secret/configuration conventions.

## 8.4 Principle of least privilege

The Firebase service account should have only the permissions required to send FCM messages.

The plugin should not require broad Firebase project administration privileges.

---

# 9. Firebase Integration

## 9.1 Use FCM HTTP v1

The proposed implementation should target the current FCM HTTP v1 API.

The endpoint is conceptually:

```text
POST /v1/projects/{project-id}/messages:send
```

Firebase documents sending to individual registration tokens using this API.

## 9.2 Why HTTP v1?

HTTP v1 provides:

- current Firebase architecture;
- OAuth 2 authentication;
- explicit JSON payloads;
- platform-specific message options;
- clear error responses;
- support for notification and data payloads;
- a stable HTTP boundary.

It also avoids depending on an obsolete abstraction layer merely to make an HTTP request.

## 9.3 Notification plus data payload

The plugin should normally send both:

```text
notification
```

and:

```text
data
```

components.

For example:

```json
{
  "message": {
    "token": "...",
    "notification": {
      "title": "New reply",
      "body": "Someone replied to your topic"
    },
    "data": {
      "type": "topic",
      "topic_id": "12345",
      "post_id": "67890"
    }
  }
}
```

The exact payload should remain configurable.

The notification portion provides user-visible content.

The data portion allows the application to determine what content should be opened.

---

# 10. Deep Linking

A major purpose of push notifications is to take the user directly to the relevant Discourse content.

The plugin should therefore provide enough information for the application to navigate to the originating object.

Depending on the Discourse notification, this might include:

```text
notification type
topic ID
post ID
user ID
category ID
URL
```

The plugin should prefer stable identifiers over relying exclusively on presentation text.

For example:

```json
{
  "data": {
    "type": "topic",
    "topic_id": "12345",
    "post_id": "67890",
    "url": "/t/example-topic/12345/8"
  }
}
```

The application can then choose whether to use the supplied URL or construct its own navigation.

---

# 11. Background Processing

FCM delivery should not normally happen synchronously as part of the web request that generated the Discourse notification.

Instead:

```text
Discourse event
      |
      v
Create/enqueue push job
      |
      v
Return normal Discourse response
      |
      |
      v
Background worker
      |
      v
FCM
```

## 11.1 Motivation

This provides several advantages:

- notification delivery cannot unnecessarily delay a page request;
- temporary Firebase outages do not directly fail the Discourse request;
- retry logic can be implemented;
- batches of notifications can be handled more safely;
- delivery can be monitored separately.

## 11.2 Retry behaviour

The job system should retry transient failures.

For example:

```text
FCM unavailable
      |
      v
retry
      |
      v
retry
      |
      v
eventual success or permanent failure
```

Retries should use exponential backoff where appropriate.

Firebase explicitly recommends that server environments be capable of retrying requests using exponential backoff.

Permanent failures should not be retried indefinitely.

---

# 12. Invalid Device Tokens

Device registrations naturally become obsolete.

A user may:

- uninstall the application;
- reinstall it;
- clear application data;
- change devices;
- receive a new FCM registration token.

Firebase specifically documents `UNREGISTERED` as an indication that an app instance is no longer registered and that the token should no longer be used.

The plugin should therefore automatically disable or delete such registrations.

For example:

```text
Send notification
       |
       v
FCM response
       |
       +---- success → record success
       |
       +---- UNREGISTERED → remove token
       |
       +---- transient error → retry
       |
       +---- permanent configuration error → report
```

## 12.1 INVALID_ARGUMENT

`INVALID_ARGUMENT` requires more care.

Firebase notes that this error can mean either:

- an invalid registration token; or
- an invalid message/request.

Therefore the plugin should **not blindly delete a token whenever it receives HTTP 400**.

It should inspect the Firebase error details and only invalidate the registration when the error specifically identifies the registration token as invalid.

This distinction is important for reliable operation.

---

# 13. Device Freshness

The plugin should record:

```text
last_seen_at
```

for each device.

The mobile application can update this when it contacts the server.

This provides an additional mechanism for identifying abandoned registrations.

Firebase notes that an app instance that has not connected for approximately one month is generally considered stale, although the appropriate threshold depends on the application.

The plugin should therefore make stale-device cleanup configurable rather than hard-coding a universal period.

For example:

```text
Device considered stale after:
30 days
60 days
90 days
Never
```

The first implementation could simply provide the data and defer automatic cleanup until the behaviour has been proven.

---

# 14. Notification Preferences

The plugin should respect Discourse's notification preferences.

It should not independently decide:

> "This user wants push notifications."

Instead, the plugin should establish a clear relationship between Discourse notification preferences and push delivery.

Possible models include:

### Model A — Push mirrors Discourse notifications

If Discourse generates a notification for the user, the plugin sends a push.

Advantages:

- simple;
- predictable;
- minimal configuration.

### Model B — Separate push preferences

Users can independently enable or disable push notifications for categories such as:

- replies;
- mentions;
- private messages;
- watched topics;
- follows.

Advantages:

- greater control.

The recommended architecture is to start with Model A while allowing the system to evolve toward Model B.

---

# 15. Multiple Applications

The plugin should not assume that one Discourse installation has only one mobile application.

A Discourse instance could potentially have:

```text
Application A
Application B
Application C
```

The device registration should therefore contain an application identifier.

For example:

```text
app_id
platform
```

This allows administrators to distinguish devices belonging to different applications.

The plugin should not hard-code Android package names or iOS bundle identifiers.

---

# 16. Platform Abstraction

The first implementation can focus on FCM while avoiding Android-specific assumptions in the core data model.

Conceptually:

```text
PushDevice
    |
    +-- platform = android
    |
    +-- platform = ios
```

The delivery service can then contain platform-specific handling.

This is preferable to creating an architecture in which Android is permanently embedded throughout the plugin.

---

# 17. Provider Abstraction

Although Firebase is the initial delivery provider, the internal architecture should distinguish:

```text
Push notification
```

from:

```text
FCM delivery
```

For example:

```text
PushDeliveryService
        |
        +---- FirebaseProvider
        |
        +---- FutureProvider
```

This does not mean that multiple providers need to be implemented initially.

It means the code should avoid making Firebase concepts leak unnecessarily into every part of the plugin.

This could eventually permit support for another provider without redesigning device management and Discourse integration.

---

# 18. Administration Interface

The plugin should provide a modest administrator interface.

It should answer practical questions such as:

- Is push notification delivery configured?
- Is Firebase authentication working?
- How many devices are registered?
- How many active devices exist?
- When was the last successful delivery?
- When was the last delivery failure?
- Are there invalid devices?
- What application versions are registered?

## 18.1 Device list

An administrator could see:

| User | Platform | App | Version | Last Seen | Status |
|---|---|---|---|---|---|
| User A | Android | Example App | 1.4.2 | 2 min ago | Active |
| User B | Android | Example App | 1.3.8 | 8 days ago | Active |
| User C | iOS | Example App | 2.0.1 | 51 days ago | Stale |

Full FCM tokens should not normally be displayed.

## 18.2 Test notification

An administrator should eventually be able to select a registered device and send:

> Test notification

This would be extremely valuable for diagnosing whether:

- the Firebase configuration works;
- the device is registered;
- the FCM token is valid;
- the application is receiving messages.

The test facility should be restricted to appropriately authorised administrators.

---

# 19. Diagnostics and Logging

One of the major design objectives should be **observability**.

A push notification system that merely says "something failed" is difficult to maintain.

The plugin should record events such as:

```text
Notification created
Push job queued
Push job started
Device selected
FCM request sent
FCM accepted
FCM rejected
Device invalidated
Retry scheduled
```

However, logs should not contain:

- complete FCM tokens;
- Firebase private keys;
- OAuth access tokens;
- unnecessary personal information.

A token can instead be represented by a short fingerprint or truncated identifier for diagnostic purposes.

For example:

```text
device=8f31c2...
```

rather than:

```text
device=full-secret-token
```

---

# 20. Error Classification

The plugin should classify errors rather than treating all failures identically.

A useful initial model is:

### Success

```text
FCM accepted the message.
```

### Permanent device failure

```text
UNREGISTERED
```

Action:

```text
disable/delete device registration
```

### Temporary provider failure

Examples include:

```text
UNAVAILABLE
INTERNAL
```

Action:

```text
retry
```

Firebase documents these error classes and their meanings.

### Authentication/configuration failure

Examples:

```text
UNAUTHENTICATED
PERMISSION_DENIED
SENDER_ID_MISMATCH
```

Action:

```text
do not repeatedly retry indefinitely;
surface configuration error to administrator.
```

### Invalid application payload

Example:

```text
INVALID_ARGUMENT
```

Action:

```text
record detailed error;
determine whether request or token is invalid;
do not automatically delete token unless Firebase identifies it as invalid.
```

This classification should be implemented centrally in the Firebase provider.

---

# 21. Security Model

Security should be treated as a first-class requirement.

## 21.1 Server secrets

Firebase service-account credentials must remain server-side.

## 21.2 Device tokens

FCM registration tokens should be treated as secrets.

## 21.3 API authorisation

A user must only be able to:

- register their own device;
- list their own registered devices;
- remove their own devices.

An administrator may have additional capabilities.

## 21.4 Input validation

The API should validate:

- platform;
- application identifier;
- token length/format where appropriate;
- application version;
- device identifiers.

## 21.5 Rate limiting

Device registration endpoints should be protected against abuse.

The plugin should take advantage of existing Discourse facilities where appropriate rather than inventing a completely independent rate-limiting framework.

---

# 22. Privacy

The plugin should collect only what is required for push delivery.

The minimum useful information is approximately:

```text
Discourse user
FCM registration token
platform
application identifier
timestamps
```

A device's:

- GPS location;
- phone number;
- contacts;
- hardware identifiers;
- advertising ID

should not be required.

The plugin should not attempt to identify a physical person beyond the authenticated Discourse user to whom the device is registered.

---

# 23. Database Design

A preliminary table might be:

```text
mobile_push_devices

id
user_id
platform
app_id
device_identifier
registration_token
app_version
enabled
last_seen_at
created_at
updated_at
```

Indexes should include at least:

```text
user_id
registration_token
```

and potentially:

```text
user_id + app_id + platform
```

The precise uniqueness constraints require care because Firebase tokens can change.

The design should favour safe updates over assumptions that a particular token is permanently tied to a physical device.

---

# 24. Notification Payload Design

The payload should contain two conceptual sections.

## 24.1 Human-readable notification

```json
{
  "title": "New reply",
  "body": "Jane Smith replied to your topic"
}
```

## 24.2 Machine-readable data

```json
{
  "type": "topic_reply",
  "topic_id": "12345",
  "post_id": "67890",
  "url": "/t/example-topic/12345/8"
}
```

The plugin should avoid putting excessive information into the payload.

FCM imposes message-size limits; Firebase documents a 4096-byte limit for most messages.

The preferred design is therefore:

> Send enough information to identify the notification and navigate to the relevant content, but retrieve the full content from Discourse when the application opens it.

---

# 25. Notification Content and Privacy

The plugin should provide options concerning how much information appears in the push notification.

For example:

### Full

```text
Jane Smith
replied to "Question about..."
```

### Generic

```text
You have a new notification
```

This matters because notification text can be visible on a locked device.

The final implementation should allow administrators and/or users to select an appropriate privacy model.

---

# 26. Priority

FCM supports normal and high message priority.

Firebase describes normal priority as appropriate for less time-sensitive content and high priority as intended for time-sensitive, user-visible content.

The plugin should therefore not automatically mark every Discourse notification as high priority.

A sensible initial policy would be:

- ordinary Discourse notifications → normal priority;
- genuinely time-sensitive notifications → configurable;
- administrators → configurable policy.

This avoids unnecessarily treating ordinary forum activity as urgent.

---

# 27. Notification Collapse and Deduplication

A busy topic can generate multiple notifications.

The plugin should eventually consider FCM's message-collapsing facilities so that a large number of notifications does not create an unnecessarily noisy mobile experience.

However, this should not be implemented prematurely.

The first version should establish correct delivery semantics before adding aggressive collapsing.

A possible future strategy is:

```text
topic:12345
```

as a collapse identifier, allowing multiple pending notifications relating to the same topic to be represented efficiently.

The exact behaviour must be carefully tested because collapsing notifications can cause information to be lost.

---

# 28. Testing Strategy

Testing should occur at several levels.

## 28.1 Unit tests

Test:

- device registration;
- token replacement;
- device deletion;
- notification payload generation;
- Firebase error classification;
- invalid-token handling;
- retry classification.

## 28.2 Plugin acceptance tests

Test the complete Discourse-facing API:

```text
authenticate user
      ↓
register device
      ↓
retrieve device
      ↓
update token
      ↓
delete device
```

## 28.3 Firebase integration tests

A controlled Firebase project should be used for integration tests.

The tests should verify:

- valid token;
- invalid token;
- authentication failure;
- temporary provider failure;
- malformed payload.

## 28.4 Mobile application tests

At least one reference Android client should verify:

```text
register
receive
display
tap
navigate
```

The mobile client should also test token rotation.

---

# 29. Development Environment

The plugin should be developed against a current Discourse development environment rather than directly against a production installation.

The repository should include:

```text
README
installation instructions
development instructions
test instructions
API documentation
Firebase configuration documentation
```

Discourse provides specific guidance for plugin development, testing and publication, and the project should follow those conventions.

---

# 30. Compatibility Strategy

The plugin should define an explicit compatibility policy.

For example:

```text
Plugin version 1.x
    supports a defined range of Discourse releases
```

Compatibility should be tested against supported Discourse versions.

The plugin should avoid unnecessarily depending on private Discourse implementation details.

When a Discourse internal API must be used, that dependency should be isolated in one place so that future changes are easier to accommodate.

---

# 31. Versioning

The plugin should use semantic versioning:

```text
MAJOR.MINOR.PATCH
```

For example:

```text
1.0.0
```

A breaking change to the mobile API should be treated differently from an internal bug fix.

The API itself should be versioned:

```text
/mobile-push/v1/...
```

This allows the plugin to evolve without forcing every mobile application to update simultaneously.

---

# 32. Backwards Compatibility

The plugin should be designed so that future versions can migrate device records.

Database migrations should be ordinary Discourse plugin migrations.

For example:

```text
migration 1:
create mobile_push_devices

migration 2:
add app_id

migration 3:
add last_seen_at
```

The plugin should not require administrators to manually manipulate its database.

---

# 33. Installation

A typical installation should ultimately be as simple as adding the plugin repository to Discourse's plugin configuration.

Conceptually:

```text
Discourse
  |
  +-- plugins
       |
       +-- discourse-mobile-push
```

The installation documentation should then guide the administrator through:

1. creating/configuring a Firebase project;
2. enabling FCM;
3. creating appropriate server credentials;
4. configuring the plugin;
5. installing the mobile application;
6. registering a test device;
7. sending a test notification.

Firebase currently requires the Cloud Messaging API to be enabled for the project when using the server-side FCM integration.

---

# 34. Configuration Philosophy

Configuration should be deliberately small.

A possible initial set is:

```text
firebase_project_id
firebase_credentials
push_enabled
push_privacy_mode
stale_device_days
```

Additional settings should only be introduced when there is a demonstrated need.

Too many settings make a plugin difficult to understand and support.

Defaults should produce sensible behaviour.

---

# 35. Open-Source Considerations

Because the plugin is intended to be generic, it should be designed for public release.

The repository should contain:

```text
README.md
LICENSE
CHANGELOG.md
CONTRIBUTING.md
SECURITY.md
docs/
```

The README should explain the architecture rather than merely saying:

> Add this plugin to your Discourse installation.

A developer should be able to understand:

- what the plugin does;
- what it doesn't do;
- how the mobile API works;
- how Firebase is configured;
- how authentication works;
- how to develop against it;
- how to test it.

---

# 36. Reference Mobile Client

Although the plugin itself should remain application-independent, maintaining a small reference client would be valuable.

The reference client would demonstrate:

```text
Discourse login
      ↓
FCM registration
      ↓
POST device registration
      ↓
receive notification
      ↓
interpret notification data
      ↓
open Discourse URL
```

This would serve two purposes:

1. provide a working example for developers;
2. provide an integration test target for the plugin.

The reference client should not be embedded into the Discourse plugin itself.

---

# 37. Failure Scenarios

The design should explicitly handle the following scenarios.

## Firebase temporarily unavailable

```text
notification
    ↓
job
    ↓
Firebase unavailable
    ↓
retry
```

The Discourse notification itself must remain intact.

## Device has been uninstalled

```text
FCM → UNREGISTERED
          ↓
remove device
```

## User logs out

The mobile application should unregister or disable the device association as appropriate.

## User logs in on another device

The new device becomes another registration.

Existing devices should remain registered unless explicitly removed.

## FCM token changes

The application updates the registration.

## Firebase credentials are invalid

The plugin should report a clear administrator-visible configuration error rather than silently retrying indefinitely.

## Discourse notification has no mobile representation

The plugin should either send a generic notification or explicitly ignore that notification type according to documented rules.

---

# 38. Why the Plugin Should Be a Delivery Channel Rather Than a Notification Engine

This is perhaps the most important architectural decision.

The plugin should not try to understand every reason why Discourse might notify a user.

Instead:

```text
Discourse knows:
"User X should be notified."

Plugin knows:
"User X has these mobile devices."

Firebase knows:
"Here is how to deliver the message."

Application knows:
"Here is what to display/open."
```

Each component therefore has one responsibility.

This substantially reduces coupling.

---

# 39. Why Device Registrations Should Not Be Stored on Users

A common simple implementation might add:

```text
users.fcm_token
```

This should be avoided.

It fails as soon as a user has:

- two phones;
- a phone and tablet;
- multiple applications;
- an old token and a new token.

A separate device table is only slightly more complicated but solves all of these problems cleanly.

---

# 40. Why the Firebase Integration Should Be Isolated

Firebase is a delivery mechanism, not the reason the plugin exists.

The plugin's real function is:

> Connect Discourse notifications to mobile applications.

FCM is simply the first delivery provider.

Keeping the provider behind an abstraction makes the long-term design more robust.

---

# 41. Why Asynchronous Delivery Is Important

A push notification is inherently an external operation.

External services can:

- be slow;
- fail;
- rate-limit;
- become temporarily unavailable;
- reject individual tokens.

Those behaviours should not be allowed to interfere with normal Discourse requests.

Background jobs provide the appropriate boundary.

---

# 42. Why Diagnostics Are a First-Class Feature

Push notifications are notoriously difficult to debug because the failure may occur at several points:

```text
Discourse notification
        ↓
Plugin
        ↓
Job queue
        ↓
Firebase authentication
        ↓
FCM
        ↓
Device token
        ↓
Mobile OS
        ↓
Application
```

A useful implementation must make it possible to identify which stage failed.

The plugin should therefore be designed from the beginning with observable states rather than adding logging as an afterthought.

---

# 43. Proposed Initial Scope

The first production-quality version should deliberately limit its scope.

### Version 1.0

Implement:

- Discourse notification integration;
- Android support;
- FCM HTTP v1;
- authenticated device registration;
- multiple devices;
- token refresh;
- token invalidation;
- background delivery;
- basic retries;
- notification + data payload;
- deep-link information;
- basic administrator diagnostics;
- automated tests.

### Later versions

Potential additions:

- iOS-specific behaviour;
- advanced notification preferences;
- notification grouping/collapse;
- richer administrator dashboard;
- delivery metrics;
- multiple Firebase projects;
- multiple push providers;
- topic-based push subscriptions;
- richer privacy controls.

This staged approach reduces the risk of building a complicated system before the fundamental delivery path has been proven.

---

# 44. Proposed First End-to-End Milestone

The first meaningful milestone should be extremely concrete:

```text
1. A user logs into a native mobile application.

2. The application obtains an FCM registration token.

3. The application sends that token to Discourse.

4. Discourse stores the registration against the authenticated user.

5. Discourse generates an ordinary notification for that user.

6. The plugin creates a background push job.

7. The job sends an FCM HTTP v1 message.

8. Firebase accepts the message.

9. The mobile device receives it.

10. The user taps it.

11. The application opens the relevant Discourse content.
```

Until that complete path works reliably, additional features should not be prioritised.

---

# 45. Recommended Project Structure

A preliminary repository could look like:

```text
discourse-mobile-push/
│
├── plugin.rb
│
├── app/
│   ├── controllers/
│   │   └── mobile_push/
│   ├── models/
│   │   └── mobile_push_device.rb
│   └── serializers/
│
├── lib/
│   └── mobile_push/
│       ├── notification_service.rb
│       ├── firebase_provider.rb
│       ├── device_manager.rb
│       └── error_classifier.rb
│
├── jobs/
│   └── send_mobile_push.rb
│
├── db/
│   └── migrate/
│
├── config/
│
├── spec/
│   ├── models/
│   ├── requests/
│   ├── services/
│   └── jobs/
│
├── docs/
│   ├── architecture.md
│   ├── firebase.md
│   ├── mobile-api.md
│   └── troubleshooting.md
│
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
└── SECURITY.md
```

The exact structure should follow current Discourse plugin conventions once implementation begins.

---

# 46. Design Principles

The project should be governed by the following principles.

### 1. Generic first

No application-specific assumptions.

### 2. Minimal dependencies

Every dependency should have a reason to exist.

### 3. Use Discourse's notification system

Do not duplicate notification logic.

### 4. Use current Firebase technology

Target FCM HTTP v1 rather than obsolete interfaces.

### 5. Never block Discourse requests

Use background jobs.

### 6. Treat device tokens as sensitive

Do not expose or unnecessarily log them.

### 7. Remove invalid registrations automatically

Especially in response to `UNREGISTERED`.

### 8. Make failures diagnosable

An administrator should be able to determine what went wrong.

### 9. Version the API

Mobile applications cannot necessarily be upgraded simultaneously with the server.

### 10. Avoid unnecessary coupling to Discourse internals

The plugin should survive Discourse upgrades with minimal modification.

---

# 47. Open Questions Before Implementation

Several decisions should deliberately remain open until implementation research is complete.

## 47.1 Exact Discourse notification hook

The precise integration point should be selected based on the current Discourse version and supported plugin APIs.

## 47.2 Firebase authentication library

The implementation should compare:

- direct OAuth 2 / JWT authentication;
- Google's supported Ruby libraries;
- another minimal supported approach.

The deciding criterion should be the combination of reliability, security, maintainability and dependency footprint.

## 47.3 Credentials storage

The plugin should determine the safest and most idiomatic way of providing Firebase server credentials in a Discourse installation.

## 47.4 iOS support

The underlying model should support iOS, but the first release need not necessarily implement every iOS-specific feature.

## 47.5 Notification preferences

The first version should establish basic reliable delivery before implementing an extensive preference system.

## 47.6 Delivery metrics

It should be determined whether detailed delivery history belongs in the plugin database or whether lightweight operational logging is sufficient.

---

# 48. Overall Recommendation

The proposed plugin should be built as a **generic mobile push notification layer for Discourse**, with Firebase Cloud Messaging as its first delivery provider.

The fundamental architecture should be:

```text
                 ┌─────────────────────┐
                 │      Discourse      │
                 │ notification system │
                 └──────────┬──────────┘
                            │
                            ▼
                 ┌─────────────────────┐
                 │ Mobile Push Plugin  │
                 │                     │
                 │ • devices           │
                 │ • preferences       │
                 │ • jobs              │
                 │ • payloads          │
                 │ • diagnostics       │
                 └──────────┬──────────┘
                            │
                            ▼
                 ┌─────────────────────┐
                 │ Firebase Provider   │
                 │                     │
                 │ FCM HTTP v1         │
                 └──────────┬──────────┘
                            │
                            ▼
                 ┌─────────────────────┐
                 │ Native Mobile App   │
                 └─────────────────────┘
```

The central architectural principle is:

> **The plugin should be a bridge between Discourse notifications and mobile applications, not a replacement for either Discourse's notification system or the mobile application's own logic.**

A clean implementation following this model should be considerably easier to maintain through future Discourse upgrades than a tightly coupled, application-specific FCM implementation.

It should also provide a useful foundation for an open-source plugin that other Discourse operators and mobile-app developers can adopt.

# 49. Suggested Development Sequence

The implementation should proceed in the following order:

1. **Create the plugin skeleton.**
2. **Create the device-registration database model.**
3. **Implement authenticated registration/unregistration API.**
4. **Write automated tests for device management.**
5. **Identify and implement the correct current Discourse notification hook.**
6. **Create a generic internal push-notification object.**
7. **Implement the background job.**
8. **Implement the Firebase provider.**
9. **Implement FCM HTTP v1 authentication.**
10. **Send a real test message to a controlled device.**
11. **Implement invalid-token handling.**
12. **Implement retry/error classification.**
13. **Implement deep-link payloads.**
14. **Add administrator diagnostics.**
15. **Document installation and Firebase configuration.**
16. **Test against a current Discourse release.**
17. **Test upgrade/rebuild behaviour.**
18. **Publish an initial public release.**

The first objective should be **a small, dependable vertical slice**, rather than a large feature set:

> **Register one device → generate one Discourse notification → send one FCM message → receive it → open the correct Discourse content.**

Once that path is reliable, the rest of the plugin can be developed around a proven foundation.