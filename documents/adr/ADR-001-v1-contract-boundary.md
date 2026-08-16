# ADR-001: Versioned v1 contract boundary

- Status: Proposed
- Date: 2026-08-16
- Owners: contract, database/security, iOS, and web reviewers
- Requirements: FR-001–FR-004, FR-101–FR-106, FR-201–FR-206,
  FR-301–FR-305, FR-401

## Decision

Use OpenAPI 3.1 for HTTPS contracts and JSON Schema 2020-12 for realtime
events and fixtures. Complex mutations cross a versioned server policy boundary.
PostgreSQL/PostGIS is authoritative; clients cache and reconcile canonical
resources.

Tenant-owned response resources include immutable, server-derived
`organization_id`. Create requests identify the target occurrence or resource
but cannot select their own tenant. Mutations require `Idempotency-Key`; updates
also carry an expected version where a lost update is possible. Public location
uses only policy-approved descriptions and approximate coordinates. Realtime
events are minimal invalidation hints and cannot contain contact data, consent
evidence, incident text, minor data, media URLs, or precise location.

## Consequences

- Backend work begins only after the relevant schema patch is approved.
- iOS and web clients generate or hand-map types from the same contract and
  fixtures.
- Response enums require an unknown-safe client fallback.
- Requests reject unknown fields to reduce over-posting; responses may add
  fields compatibly.
- Database and RLS behavior remains separately tested and cannot be replaced by
  client validation.

## Migration

The current preview-only Swift models are mapped to v1 without treating their
field names as authoritative. No production data exists, so the initial database
migration may implement v1 directly. Later breaking changes require `/v2`, an
overlap window, and explicit data migration.

## Privacy and security

Public schemas omit precise operational addresses, private contacts, consent
payloads, incident text, storage keys, and minor rosters. Tenant IDs are derived
server-side. Authorization, resource state, membership, and assigned-site scope
are checked for each mutation and backed by deny-by-default RLS.

## Test impact

CI validates the OpenAPI document, JSON Schemas, positive/negative fixtures,
unique operation IDs, and mutation idempotency headers. Issue #7 adds tenant
deny, capacity race, audit, and replay tests against the implementation.

## Rollout and rollback

Release behind versioned `/v1` routes and feature flags. Rollback disables the
routes and clients while preserving additive schema/data. Contract files may be
reverted before implementation; after consumers merge, breaking rollback uses a
new version rather than rewriting v1 history.
