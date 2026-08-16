# ADR-002: Use a policy-centered modular monolith for v1

- Status: Proposed
- Date: 2026-08-16
- Decision owners: Lead Architect and Delivery Lead
- Product decisions: D-001, D-002, D-003, D-004, D-005, D-013, D-014
- Requirements: FR-001–FR-401

## Context

Day of Service must serve multiple independent organizations through a native
iPhone app, public/guardian web flows, and an organizer web console. The highest
risk operations—tenant authorization, guardian consent, hard capacity,
attendance, media publication, and precise location—need transactional policy
and consistent audit evidence.

The current repository is an iOS preview and Swift package. There is no
production backend or web implementation and no production data to migrate.
Splitting v1 into independently deployed business microservices would add
network failure modes and distributed consistency before the domain and team
need them.

## Decision

Build v1 as a modular monolith around Supabase Auth and one authoritative
PostgreSQL/PostGIS database.

- Native iOS remains Swift/SwiftUI.
- One strict-TypeScript responsive web application contains public, guardian,
  and organizer route groups.
- A versioned `/v1` policy API, implemented through narrowly scoped Supabase
  Edge Functions and transactional database functions, is shared by both
  clients.
- Domain state is partitioned into bounded contexts with explicit ownership:
  identity/tenancy, event programming, participation, consent, event
  operations, Safety Sharing, media, impact/lifecycle, and platform operations.
- Cross-context external work is emitted through a transactional outbox and
  processed by idempotent workers.
- Cloudflare R2 stores private media objects and safe derivatives; PostgreSQL
  stores opaque object keys, event-feed visibility, optional public-gallery
  publication, report/quarantine, and lifecycle metadata. ADR-004 defines the
  reactive event-feed policy.
- Realtime messages are redacted invalidation hints. Clients reconcile from the
  authoritative API/database after reconnect or a version gap.

Modules may deploy as separate clients, Edge Functions, and workers, but they
do not own separate business databases in v1. A later service extraction must
show a measured scaling, isolation, ownership, or release benefit and receive a
new ADR.

## Consequences

### Positive

- Capacity, consent, attendance, moderation, audit, and outbox changes can be
  committed atomically.
- The team can deliver vertical slices without coordinating distributed
  schemas or transactions.
- One web application reuses identity, accessibility, contract, and design
  work across public and privileged surfaces.
- Bounded contexts and provider adapters preserve a credible extraction path.

### Tradeoffs

- Database migration and module ownership require discipline because many
  features share one deployment unit.
- A poorly designed service-role path could bypass tenant policy across the
  product; ADR-003 constrains that boundary.
- Long-running media, notification, export, and retention work cannot execute
  synchronously in request handlers and requires outbox/job operations.

## Migration and compatibility

There is no production database. Establish the initial modular schemas and v1
contract before implementing feature data access. Existing Swift preview models
are mapped at the client boundary rather than treated as the server schema.
Future module extraction uses an expand/migrate/contract sequence, an overlap
window, and an outbox-backed data transition; clients continue to use the
versioned contract.

## Privacy and security

- Clients are untrusted and contain publishable configuration only.
- Server authorization and deny-by-default RLS protect every tenant-owned row.
- Sensitive bounded contexts use narrower read models and policies than
  ordinary tenant content.
- Async messages and realtime events carry only the minimum identifiers and
  redacted data needed by their consumers.
- R2 originals and derivatives remain private at rest. Event members receive
  processed derivatives immediately through controlled delivery; anonymous
  public delivery is a separate approved publication state.

## Test impact

Every context needs unit tests for its state machines and integration tests for
its API/database boundary. CI must include two-tenant RLS allow/deny tests,
transactional concurrency and idempotency tests, contract compatibility,
outbox retry/deduplication, and client reconciliation after reconnect.

## Rollout and rollback

Deploy additive migrations, then compatible API handlers, then flagged clients.
Workers are enabled only after their outbox producer and dead-letter monitoring
are live. Rollback disables feature flags, handlers, and consumers while
preserving additive data. Destructive contract migrations wait until all
readers have moved and the rollback window has closed.
