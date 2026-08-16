# Definition of done

A change is done only when every applicable item is satisfied.

## Product and UX

- Acceptance criteria and referenced requirement IDs pass.
- Loading, empty, error, retry, cancellation, permission-denied, offline, and conflict states are designed.
- VoiceOver, Dynamic Type, contrast, reduced motion, keyboard/focus, and plain-language errors are verified.
- User-visible copy and policy links are approved; localization-safe strings and time zones are used.

## Contracts and implementation

- Schema/API/event changes are versioned, documented, compatible, and represented in fixtures.
- Migrations are tested forward and through the documented recovery/rollback path.
- Authorization is server enforced; RLS allow and deny cases cover every affected role/tenant.
- Concurrency, idempotency, retries, and state transitions have automated tests.
- No credentials, personal data, precise location, consent payload, or private media URL leaks to clients/logs/analytics.

## Quality and operations

- Unit, database, contract, integration, UI, accessibility, security, and performance checks pass as applicable.
- Telemetry is redacted and includes actionable metrics, traces, errors, and alerts.
- Feature flag, staged rollout, rollback, support, and incident runbook are ready.
- Dependencies and licenses are reviewed; secret/SAST/dependency scans pass.
- Documentation and App Store/privacy disclosures match actual behavior.

## Release evidence

The pull request records exact verification commands and results, screenshots for perceptible UI changes, migration evidence, reviewer approvals, residual risks, and rollback owner. Release owner confirms dashboards after deployment and closes or owns every follow-up.
