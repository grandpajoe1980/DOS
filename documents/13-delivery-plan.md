# Delivery plan

## Milestones

1. **Foundations:** ADRs, design system, CI, environments, observability, database conventions, API schemas, fixtures.
2. **Identity/tenancy:** authentication, profiles, organizations, invitations/roles, RLS matrix, audit access.
3. **Event authoring:** definitions, occurrences, sites/shifts/tasks, previews, publish transitions, public discovery.
4. **Registration/consent:** households/dependents, teams, eligibility, versioned documents, guardian flow, capacity concurrency.
5. **Assignment:** constraints, planner preview, confirmation, waitlists, participant status.
6. **Event-day:** site-lead roster, directions, check-in/out, offline queue/reconciliation, announcements, incidents.
7. **Media:** signed uploads, processing, moderation, guardian controls, public gallery, reports/takedown.
8. **Impact/admin:** aggregates, exports, account requests, retention, support tools.
9. **Hardening:** accessibility, localization/time zones, performance, security/privacy review, disaster rehearsal.
10. **Beta/release:** TestFlight, organizer pilot, remediation, App Store submission, phased rollout.

## Story format

Each story names actor, outcome, requirements, authorization rule, acceptance examples, analytics/observability, accessibility, failure/offline behavior, privacy classification, dependencies, and rollout plan.

## Example acceptance scenarios

- Two tenants use the same slug-local names but can never query or mutate one another's data.
- Concurrent registrations cannot exceed a configured hard site limit; a soft target does not reject registration.
- A guardian must accept the active document for each named dependent; old evidence remains immutable.
- Retrying a check-in produces one attendance transition.
- A published image becomes unavailable promptly after takedown and cached/signed access expires.

## Delivery controls

Keep slices mergeable and behind expiring flags. Schema/API owners review contract changes. Risky migrations use expand/migrate/contract. Every milestone includes docs, automated tests, telemetry, runbooks, and a demonstrated rollback.
