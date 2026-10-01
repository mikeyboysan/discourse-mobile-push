# Operational Learnings

Experiential patterns from practice. Complements standards (what should be) with experience (what we keep learning).

## Design Patterns
<!-- Decomposition, architecture choices, scope decisions that proved good or bad -->
- 2026-10-01 [design] Provider errors that are ambiguous between "bad message" and "bad recipient" (e.g. HTTP 400) — classify on the detailed error payload, never the status alone; config-class errors must never delete recipient records.
- 2026-10-01 [design] Fan-out to N external recipients — one job per recipient with native retries avoids duplicate sends without custom retry bookkeeping.

## Implementation Craft
<!-- Coding approaches, library gotchas, design-to-reality gaps -->
- 2026-10-01 [design] Read the host framework's current source before designing against an extension point — docs lag (e.g. Discourse's push event fires before push filters; official plugins now live in core `plugins/`).

## Quality Signals
<!-- Recurring quality issues that keep appearing despite rules -->

## Reliability
<!-- Bug root causes, failure modes, fragile areas, boundary condition gaps -->

## Structural Health
<!-- Architectural drift, debt accumulation, coupling issues, migration lessons -->
