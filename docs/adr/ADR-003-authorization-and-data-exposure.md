# ADR-003: Make the server policy API and deny-by-default RLS the authorization boundary

- Status: Proposed
- Date: 2026-08-16
- Decision owners: Lead Architect and Security/Data owners
- Product decisions: D-001, D-004, D-006, D-007, D-009, D-010, D-011, D-012, D-013
- Requirements: FR-001–FR-004, FR-101–FR-106, FR-201–FR-206, FR-301–FR-305, FR-401

## Context

Supabase makes direct database access convenient, but authentication alone does
not establish organization membership, role, assigned-site scope, guardian
authority, valid consent, resource state, or temporary support authority.
Client-side role helpers are useful for presentation but can be bypassed.

Day of Service also handles data with sharply different exposure rules:
published event summaries, precise operations locations, rosters, dependents,
consent evidence, incidents, Safety Sharing, media originals, and platform
support access. A single broad table API would make accidental disclosure and
IDOR/tenant escape more likely.

## Decision

Use defense in depth with a versioned server policy API as the ordinary command
boundary and deny-by-default PostgreSQL RLS as a mandatory backstop.

1. Supabase Auth establishes the caller's identity. Current server records
   establish suspension, tenant membership, role, assignment, guardian
   relationship, and support-grant scope.
2. Keep base tables in a non-exposed application schema. Expose only reviewed
   views/functions through the configured API schema.
3. Public endpoints select from purpose-built public views/types containing
   policy-approved approximate locations and no tenant-private fields.
4. User-facing commands enter through `/v1` handlers. The handler authenticates
   and validates; one database transaction reauthorizes resource scope, checks
   the lifecycle/version, changes state, and appends audit and outbox evidence.
5. Tenant and actor identity are server derived. Create payloads cannot grant
   `organization_id`, role, guardian status, uploader identity, or site scope.
6. RLS is enabled for tenant and sensitive data and has explicit allow and deny
   tests. User-facing handlers use the caller's JWT context where possible.
7. Service-role bypass is reserved for named worker/platform operations. Each
   operation receives the narrowest practical database/object permission,
   validates its job or support grant, and writes immutable audit evidence.
8. JWT custom claims are not the sole authority for revocable permissions.
   Memberships, suspension, assignments, and support grants are checked from
   current server state for privileged operations.
9. Realtime subscriptions are tenant/resource scoped and contain a minimal
   redacted envelope. They never carry consent payloads, incident text, private
   contacts, minor data, precise location, private media URLs, or object keys.

## Consequences

### Positive

- A forged client payload or direct table request cannot select another tenant
  or create its own privilege.
- Public serialization is allowlisted rather than based on removing sensitive
  columns from internal records.
- Atomic policy functions eliminate check-then-write races for capacity,
  assignment, invitation use, consent, attendance, and moderation.
- Revocation can take effect without waiting for every long-lived token claim
  to expire.

### Tradeoffs

- Every feature requires policy design, RLS tests, and purpose-built response
  types before it can be exposed.
- Some simple reads may pass through reviewed API views/functions rather than
  raw tables, adding explicit mapping work.
- Service workers need separate roles/policies and cannot share one unrestricted
  service key as a convenience.

## Migration and compatibility

No production data exists. Initial migrations create non-exposed base schemas,
reviewed API views/functions, tenant-aware keys/indexes, and RLS before clients
connect. If a table is already exposed during development, remove exposure only
after its API replacement is available and integration tests cover both paths.
Contract response changes remain additive in v1; narrower security behavior is
not weakened for backward compatibility.

## Privacy and security

- Consent and audit history is append-only; correction creates revocation or
  supersession evidence.
- Incidents, dependents, precise locations, Safety Sharing, support grants, and
  media originals receive narrower policies and retention than routine event
  data.
- Logs, analytics, errors, realtime, and outbox payloads are redacted by
  allowlist and never include sensitive free text or durable media access URLs.
- Invitations are expiring, single-use, hashed at rest, rate limited, and
  consumed atomically.
- Break-glass support requires an expiring grant, ticket/reason, MFA-protected
  operator identity, and immutable audit.

## Test impact

For every exposed resource, test at least two organizations, no membership,
each relevant role, suspended membership, foreign resource IDs, expired/revoked
grants, assigned and unassigned sites, and both direct database and API paths.
Concurrency tests cover hard capacity, invitation consumption, idempotency,
attendance replay, and moderation/takedown. Contract tests assert that public
and realtime payloads cannot contain sensitive fields.

## Rollout and rollback

RLS and API authorization ship before the client feature flag is enabled.
Staging uses synthetic multi-tenant fixtures and records policy-denial metrics
without sensitive values. Rollback disables the API/feature and preserves audit
and evidence rows. Do not roll back by disabling RLS or broadening a service
role; restore a previously reviewed handler/policy version instead.

