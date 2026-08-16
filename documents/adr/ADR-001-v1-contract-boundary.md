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
but cannot select their own tenant; validation traverses the complete request
schema graph to enforce that boundary. Participant display names are derived
from the authenticated profile or chosen dependent rather than supplied by the
registration caller. Mutations require `Idempotency-Key`; updates also carry an
expected version where a lost update is possible.

The interface includes explicit household/dependent, team/member,
invitation/membership, event edit/preview/publish, legal-document/consent,
assignment/directions, roster/announcement, Safety Share, personal export, and
account-deletion lifecycle or read resources.

Media has independent `processing_state`, `event_feed_state`, and
`public_gallery_state`. A successfully validated and processed adult upload is
visible in the authenticated event feed without platform preapproval. Anonymous
gallery publication follows its own moderation lifecycle. A successful report
response guarantees the feed item was atomically quarantined before the
response. Member-feed and public-gallery read and delivery routes are distinct.

Public location uses only policy-approved descriptions and approximate
coordinates. Realtime events are minimal invalidation hints and cannot contain
contact data, consent evidence, incident text, minor data, media URLs, or
precise location.

## Consequences

- Backend work begins only after the relevant schema patch is approved.
- iOS and web clients generate or hand-map types from the same contract and
  fixtures.
- Schemas validate current enum values strictly while clients retain an
  unknown-safe fallback for future additive rollout.
- Requests reject unknown fields to reduce over-posting. Public and media
  audience schemas are closed to prevent accidental sensitive-field expansion.
- A checked compatibility baseline blocks removed paths, reassigned operation
  IDs, removed properties or response guarantees, new required request fields,
  and removed enum values. Baseline changes require an explicit reviewed
  contract decision.
- Database and RLS behavior remains separately tested and cannot be replaced by
  client validation.

## Migration

The current preview-only Swift models are mapped to v1 without treating their
field names as authoritative. No production data exists, so the initial database
migration may implement v1 directly. Later breaking changes require `/v2`, an
overlap window, and explicit data migration.

## Privacy and security

Anonymous public schemas expose only `published` occurrences and omit precise
operational addresses, private contacts, consent payloads, incident text,
storage keys, and minor rosters. Precise operational addresses appear only in
authorized organizer/assignment responses. Safety Share locations are readable
only by an explicit authorized recipient. Safety Share activation is adult-only;
dependent/minor identities are denied, recipients must be active and authorized
in the same occurrence, and expiry must be future server time within the
server-enforced 43,200-second maximum duration. Legal-document responses bind
exact content, locale, version, and hash; consent evidence binds that
version/hash to the signer, guardian relationship where applicable, revocation,
and supersession. Tenant IDs are derived server-side. Authorization, resource
state, membership, and assigned-site scope are checked for each request and
backed by deny-by-default RLS.

## Test impact

CI validates the OpenAPI document, JSON Schemas with format checking,
representative positive/negative fixtures, unique operation IDs, mutation
idempotency, exhaustive request tenant exclusion, public/media closure, media
state separation and report quarantine semantics, and the compatibility
baseline. The current 27-fixture set is representative rather than exhaustive
across all 60 operations. Per-operation fixtures, generated-client compilation,
and implementation-level authorization, tenant deny, capacity race, media race,
audit, atomicity, and replay tests remain required before issue #6 can be
accepted as feature-complete and before issue #7 implementation can be
accepted.

## Rollout and rollback

Release behind versioned `/v1` routes and feature flags. Rollback disables the
routes and clients while preserving additive schema/data. Contract files may be
reverted before implementation; after consumers merge, breaking rollback uses a
new version rather than rewriting v1 history.
