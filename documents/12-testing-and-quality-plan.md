# Testing and quality plan

## Test layers

- Unit: validation, eligibility, capacity, allocator constraints, state machines, redaction, date/time-zone behavior.
- Database: migrations, constraints, RLS allow/deny matrix, tenant isolation, concurrent capacity and assignment transactions.
- Contract: API schemas, idempotency, authorization, pagination, error codes, webhooks, backward compatibility.
- Integration: identity, R2 uploads/processing, notifications, exports, account deletion, retention jobs.
- UI: critical iOS/web flows, offline/reconnect, permission denial, deep links, cancellation, Dynamic Type, VoiceOver, keyboard navigation.
- Security/privacy: IDOR and cross-tenant attempts, upload abuse, URL expiry, secrets/log inspection, dependency/SAST scans, deletion/export evidence.
- Performance/reliability: event-day load, registration bursts, gallery delivery, realtime reconnect, job retry/dead-letter recovery.

## Required fixtures

At least two tenants; roles at every level; adult, guardian, dependent, suspended user; draft/published/archived occurrences; soft and hard capacities; all consent versions; assignment/team modes; every media state; expired invite/share/URL; multiple time zones and DST boundaries.

## Release gates

No critical/high security issue; no cross-tenant leak; migration/rollback rehearsal passes; critical journey tests pass; accessibility audit has no blocker; crash-free and latency targets met in staging load; privacy/App Store checklist signed; operational dashboards and rollback tested.

## Production verification

Use synthetic non-sensitive probes, staged rollout, server/client version dashboards, error-budget alerts, and post-deployment reconciliation. Never test production with real minor records or sensitive incident text.
