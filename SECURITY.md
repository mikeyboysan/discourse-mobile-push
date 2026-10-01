# Security policy

## Supported versions

| Version | Supported |
|---|---|
| 1.x | Yes |
| < 1.0 | No |

Security fixes are released for the latest 1.x version.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub: on the repository's **Security** tab, choose **Report a vulnerability** (or go to [the private reporting form](https://github.com/mikeyboysan/discourse-mobile-push/security/advisories/new)). Don't open a public issue or pull request for a security problem.

Include the plugin and Discourse versions, the steps to reproduce, and the impact you expect. Never include a real push token or service account key; use placeholder values.

You can expect an acknowledgement within a week. Once a fix is ready, it is released and a security advisory is published, crediting you unless you prefer otherwise.

## Scope

Examples of what we treat as security issues:

- exposure of push tokens or the Firebase service account key (in API responses, the admin UI, logs or error messages);
- registering, listing or removing devices that belong to another user;
- sending push notifications to users or devices they weren't meant for, or leaking content to users who couldn't read it in Discourse;
- bypassing the admin-only restriction on the diagnostics API, or the rate limits.

Vulnerabilities in Discourse itself should be reported to Discourse following [its security policy](https://github.com/discourse/discourse/security/policy); issues in Firebase go to Google.
