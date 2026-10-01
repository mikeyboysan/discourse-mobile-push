# Review Log

## 2026-10-01 — mobile-push-v1 design (commit 1f2e224)
- **Scope**: approved design doc (L3 flows, L4 contracts); no code in delta (`.lattice/**` excluded by config, reviewed as design by request)
- **Atoms**: clean-code, knowledge-priming, architecture, secure-coding; custom: Mobile API Compatibility, Discourse Compatibility
- **Result**: 2 critical, 5 warning, 4 suggestion
- **Key findings**: registration conflict on (user, app_id, device_identifier) index; user deletion/anonymisation unspecified; admin API scoped to staff instead of admins
- **Strengths**: provider neutrality — FCM codes never cross the port; config errors can't delete devices; no post text in push data
