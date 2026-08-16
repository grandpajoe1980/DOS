# ADR-005: Put database policy and durable effects in one command transaction

- Status: Proposed
- Date: 2026-08-16
- Decision owners: Lead Architect, Data/Authorization owner, Security owner
- Product decisions: D-001, D-004, D-006, D-007, D-009–D-014
- Requirements: PR-001–PR-008, FR-001–FR-401
- Contract: `contracts/openapi/v1.yaml`

## Context

The v1 contract has 60 operations over data with different authority and
exposure rules. Several commands establish safety or legal facts: organization
ownership, invitation consumption, guardian consent, hard-capacity assignment,
attendance, incident intake, precise Safety Sharing, media quarantine, and
deletion. A handler that authorizes first and writes later would create
check-then-act races. A broad database service role would also make RLS an
optional convention rather than a security boundary.

The application needs one repeatable database pattern before migrations are
split among parallel feature owners. The pattern must preserve tenant
isolation, exact retry outcomes, immutable evidence, external-effect delivery,
and recovery without requiring distributed transactions.

## Decision

### 1. Separate storage, policy, and operational namespaces

Use these PostgreSQL namespaces:

- `app_private`: authoritative application tables. It is not an exposed
  Supabase API schema and grants no direct access to `anon` or `authenticated`.
- `api_v1`: reviewed, contract-shaped views and functions. This is the only
  application schema exposed to user-facing clients or Edge Functions.
- `policy`: small actor/scope predicate functions used by RLS and command
  functions. It exposes no data-returning general-purpose query.
- `ops_private`: idempotency, audit, outbox, job-control, support-grant, and
  reconciliation tables. It is not client exposed.

`auth` remains owned by Supabase. Cloudflare R2 is authoritative only for object
bytes; PostgreSQL owns opaque object keys, object lifecycle, audience state,
and delivery revocation.

Every tenant row has a non-null `organization_id`. Parent tables expose a
unique `(organization_id, id)` key, and tenant children reference that pair.
Cross-tenant foreign keys by bare `id` are forbidden. Global actor-owned rows
such as profiles and households are explicitly global and use owner/guardian
predicates instead of a fabricated tenant.

### 2. Use current database facts for authority

Supabase Auth establishes `auth.uid()`. A server-owned profile maps that
identity to the application actor. Current rows—not request bodies or JWT role
arrays—establish:

- active account and adult capability;
- active organization membership and organization role;
- site-lead assignment;
- guardian relationship to a dependent;
- registration, assignment, and event-member status;
- media uploader and audience eligibility; and
- expiring, resource-scoped platform support authority.

The policy layer provides narrow boolean predicates such as
`actor_profile_id()`, `is_active_member(org)`, `has_org_role(org, roles)`,
`has_site_scope(org, site)`, `is_guardian_of(dependent)`,
`controls_registration(registration)`, and
`can_view_occurrence_feed(occurrence)`. Predicate functions set
`search_path = ''`, qualify every object, return false for missing context, and
are not executable by `PUBLIC` unless a policy requires them.

Organization roles and platform roles stay separate. A dependent is never an
authenticated actor. Team membership never implies guardian authority. A site
lead receives only assigned-site scope. Support access requires a current,
ticket/reason-bound grant and is audited on each use.

### 3. Force RLS and expose allowlisted read models

Enable and force RLS in the same migration that creates each tenant or
sensitive table. Start with no policies. Add explicit policies for the exact
actor/resource operation, then add grants. CI must reject a tenant or sensitive
table without `relrowsecurity` and `relforcerowsecurity`.

Reviewed `api_v1` read models have an explicit contract column list. Directly
exposed views are owned by a non-login, non-`BYPASSRLS`, non-table-owner
`dos_<context>_query` role with only that context's required base-column
`SELECT` grants. Forced
RLS still evaluates actor/resource predicates from the authenticated request
context. Views use `security_barrier` when predicate ordering could expose
values. Do not mark a view `security_invoker` while withholding all underlying
table privileges from the caller; that combination cannot execute. A read that
needs more procedural policy is a named query function with the same safe
ownership/search-path rules. Public views select only published rows and
approved public columns. They never derive a public response by selecting an
internal row and removing fields in application code.

Precise locations, dependent details, consent evidence, incidents, Safety
Sharing samples, media object keys/reports, support grants, audit, and export
artifacts do not appear in general tenant views. Realtime publications contain
only redacted invalidation envelopes and are authorized separately.

### 4. Use one command function per atomic mutation

Each user-facing mutation calls one named `api_v1.cmd_*` database function.
The HTTP handler authenticates, validates the OpenAPI payload, computes a
canonical keyed request digest, and invokes the function once. It does not duplicate
authorization SQL or assemble a business transaction from multiple RPC calls.

Command functions may be `SECURITY DEFINER` only when required to reach
non-exposed tables. Their owner is a non-login, non-`BYPASSRLS`
`dos_<context>_command` role with grants limited to that bounded context, not
the table owner or Supabase service role. Cross-context work calls the owning
context's named function; a command role does not gain the other context's
table privileges. The underlying tables use forced
RLS, the function derives the actor from `auth.uid()`, and every function sets
`search_path = ''`, qualifies names, validates resource scope, and has an
explicit `EXECUTE` grant. Direct table mutation remains unavailable to the
caller.

A command transaction performs this sequence:

1. Claim `(principal, operation_id, idempotency_key)` and compare the canonical
   request digest. Use a versioned server-keyed HMAC so low-entropy personal
   values cannot be recovered by guessing a plain stored hash. The canonical
   input includes path identifiers and relevant headers as well as the body.
2. Derive the tenant by loading the immutable parent/resource chain. For
   create-organization, generate the tenant inside the transaction. Never
   accept a body-provided tenant or actor.
3. Lock mutable roots in a documented, deterministic order.
4. Recheck actor, account, membership, role, site, guardian, lifecycle, and
   expected-version predicates against current rows.
5. Enforce database constraints and cross-row invariants.
6. Apply the state change and increment affected resource versions.
7. Append a redacted immutable audit event.
8. Append any required outbox records for realtime invalidation, notification,
   storage, media, export, or lifecycle work.
9. Store the canonical safe outcome in the idempotency record and commit.

An exception rolls back all nine steps. A retry with the same key and hash
returns the first committed result; a changed payload conflicts. Concurrent
claims block on the unique key and then replay the winner. For anonymous media
reports, the principal is a server-issued pseudonymous rate-limit identity;
raw IP addresses are not used as durable actor identifiers.

Idempotency records store only the minimum response snapshot or a stable
resource locator needed to reproduce the contract response. Sensitive request
bodies, report details, consent names, incident text, coordinates, tokens, and
object URLs are excluded. Retention is operation-class specific and is never
shorter than the supported retry window.

For an expiring capability such as a media upload URL, the committed outcome is
the one-use lease and opaque object identity, not the raw signed URL. An
identical replay may derive a fresh short-lived URL for that same unconsumed
lease. It must never allocate a second object or broaden the lease.

### 5. Define locking and isolation by invariant

Use ordinary `READ COMMITTED` plus explicit row/advisory locks for most
commands. Use `SERIALIZABLE` only where a reviewed proof shows deterministic
locking cannot protect a predicate invariant; retry serialization failures in
the server with the same idempotency key.

Required lock roots are:

- organization for owner-role and membership changes;
- invitation for accept/revoke;
- occurrence, then sites in ascending UUID order, for assignment planning and
  hard capacity;
- registration for participant, submission, and consent eligibility changes;
- consent evidence root for revoke/supersede;
- assignment for confirmation and attendance, followed by participant where
  needed;
- Safety Share for location update/stop/expiry;
- media asset for completion, processor result, report, moderation, delivery
  epoch, and publication; and
- deletion request/profile for account lifecycle steps.

Proposed assignments are expiring capacity reservations. A plan creates
proposed assignment rows bound to one plan and expiry. Capacity checks count
confirmed assignments plus unexpired reservations by participant count while
the site is locked. Registration participants cannot be changed while a live
proposal or confirmed assignment exists. Confirmation, expiry, cancellation,
waitlist changes, and capacity release use the same lock order.

Attendance and consent are append-only facts. Corrections append a reversal,
revocation, or supersession rather than updating evidence in place. Safety
Sharing stores only the latest precise sample; a newer sample conditionally
replaces it, and stop/expiry deletes or renders it unreadable atomically.

Media processing, reporting, and moderation lock the same media row. A worker
may transition a verified adult upload to `processing_state = ready` and
`event_feed_state = visible` only if no report, quarantine, or removal exists.
A valid report always commits `event_feed_state = quarantined` (or preserves
`removed`) and withdraws public publication before returning. A processing or
restore race can therefore never end visible after a later committed report.

### 6. Couple audit and outbox to the business commit

Every command writes an audit record containing opaque actor/tenant/target IDs,
operation, result, request ID, trusted time, and a safe reason code where
needed. It never copies the changed payload. Consent and attendance evidence
remain authoritative domain records, not substitutes for a security audit.

External effects are represented by a transactional outbox row with a stable
effect key and allowlisted payload. Workers claim rows with skip-locked leases,
write provider deduplication keys, retry with bounded backoff, and dead-letter
after a policy-defined threshold. Replaying an outbox record must be safe.
Location, incident text, consent payload, contact data, minor identity, object
keys, private URLs, and report details are not outbox or realtime payloads.

Worker identities are split by capability—for example media ingest, media
transform, notification dispatch, export, retention, and reconciliation. No
worker receives a general service-role key. A worker calls named functions or
uses grants limited to its queue and target transition.

### 7. Recover by roll-forward and replay, never by weakening policy

Schema changes use expand/migrate/contract. Restore procedures recover the
database to an isolated environment, apply all due expiry/deletion/quarantine
reconciliation before serving, and verify tenant/RLS tests before promotion.
Point-in-time recovery, R2 inventory reconciliation, outbox replay, job replay,
and idempotent deletion-step replay are required exercises before production.

Rollback disables the affected API/feature/worker and restores a previously
reviewed function or policy version. It preserves evidence and additive data.
Disabling RLS, broadening a worker role, making an R2 bucket public, rewriting
consent/audit history, or resurrecting expired Safety Sharing is not a rollback
strategy.

## Consequences

### Positive

- Authorization, invariant checks, the state change, audit, and durable effects
  share one commit boundary.
- Forced RLS remains effective even when a command needs definer privileges.
- Feature owners have a repeatable migration, function, and test pattern.
- Idempotent replay and outbox recovery avoid distributed transactions.
- Separate public/read models reduce accidental Restricted-data expansion.

### Tradeoffs

- Each operation needs a purpose-built function or view and an explicit policy
  matrix; generic CRUD is intentionally unavailable.
- RLS helper functions, command ownership, and migration grants require careful
  automated inspection.
- Expiring assignment reservations and media delivery revocation add state and
  reconciliation work.
- Some contract questions must be resolved before their migrations can be
  final; the data/authorization map records them.

## Migration and compatibility

There is no production database, so the initial schema can implement these
boundaries directly. Migrations create roles/namespaces first, then identity
and tenancy, control-plane tables, bounded-context tables, and finally reviewed
`api_v1` views/functions and realtime publications. RLS is created with each
base table, not added after client access.

The OpenAPI contract remains authoritative for transport. Database rows may be
more normalized and restrictive than transport schemas, but `api_v1` maps them
without exposing internal identifiers or weakening response guarantees.

## Privacy and security

Retention classes are assigned before a table ships, but production durations
remain blocked on owner/legal approval. Legal holds are explicit rows with
scope, authority, expiry/review, and audit. Encryption keys and raw provider
credentials remain outside PostgreSQL application rows. Restricted values use
separate tables so ordinary read policies cannot select them accidentally.

## Test impact

Every table/function/view receives direct database and API tests using two
tenants, foreign IDs, no membership, suspended membership, each relevant role,
assigned and unassigned sites, guardian and non-guardian actors, expired
grants, stale versions, duplicate idempotency keys, and worker roles.
Concurrency tests run in separate sessions and assert the committed database,
audit, outbox, and replay result—not only HTTP status. Public schema and
realtime tests fail on any Restricted field.

## Rollout and rollback

No endpoint is enabled until its table constraints, forced RLS, command
function, idempotency behavior, audit/outbox behavior, and two-tenant deny cases
pass in CI. Worker consumers start only after their producer and dead-letter
monitoring are live. Rollback follows the recovery rules above and keeps all
security boundaries closed.
