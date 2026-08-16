# Day of Service security and privacy plan

Status: living security plan and preliminary threat model, reviewed against `main` at commit `1c2a95286d2d4692b3ebdf47247b0bac0ff44a87` on 2026-08-16.

## Security objectives

1. Prevent access or mutation outside the actor's tenant, role, resource, site, occurrence, household, and lifecycle scope.
2. Preserve the integrity and attribution of consent, guardian authority, capacity, attendance, moderation, audit, and deletion records.
3. Keep media originals private, scope processed media to the correct event-member feed or separately approved anonymous gallery, and keep precise location, minor data, incidents, contact details, and legal evidence confidential by default.
4. Remain safe under retries, concurrency, offline replay, malicious input, compromised clients, and failed external processors.
5. Minimize collection and retention, honor user/guardian rights, and make public disclosure explicit and reversible.
6. Detect, contain, investigate, and recover from misuse without placing sensitive payloads in logs or analytics.

Client code and UI checks are never security boundaries. Authorization must be deny-by-default in the API and PostgreSQL RLS/constraints. Privileged object storage and service credentials remain server-side.

## Current security posture

The current repository is a prototype and is **not production-safe**:

- no authentication/session implementation exists;
- no backend, migrations, RLS, storage policy, audit trail, rate limiting, or server-side state machine exists;
- `AppModel` defaults to `PreviewEventService`, so registration succeeds without a server;
- `APIClient` has no authorization-token provider and accepts any base URL supplied by its caller;
- public and privileged site properties share one `Codable` model;
- offline persistence is an optional no-op hook and has no encrypted-at-rest implementation;
- no media upload, guardian consent, incident, Safety Sharing transport, deletion/export, or notification implementation exists;
- no CI/security scan or Xcode signing/privacy-manifest evidence exists.

These are development gaps, not accepted residual risks. Production and external beta gates stay closed until the controls and tests in this document are implemented.

## Assets and data classification

| Class | Examples | Default handling |
|---|---|---|
| Public | approved organization/event summary, approximate site label, approved transformed media | explicit allowlisted DTO; cache only to documented TTL; reversible publication |
| Internal | task definitions, aggregate operational metrics, non-sensitive configuration | authenticated tenant scope; least privilege; redacted logs |
| Confidential | adult profile/contact, household/registration, assignment/attendance, accommodations, invitations, exports | field minimization; encrypted transit/at rest; tenant/resource RLS; bounded retention |
| Restricted | minor identity/contact/roster, precise location/share, incident content, emergency contact, consent evidence, support access, private originals/object keys | explicit purpose; narrow time/resource scope; immutable audit; no general analytics/logging; short access and retention where feasible |
| Secret | service keys, signing keys, OAuth secrets, webhook secrets, encryption keys, production credentials | managed secret store/HSM or platform equivalent; never client/repo/log; rotation and access audit |

Accommodations are operationally sensitive free text and should be replaced by structured minimal options where possible. Do not solicit diagnoses. Exact date of birth is collected only when a documented policy cannot use an age band or derived eligibility result.

## Actors and trust boundaries

Actors include anonymous visitors, adults/guardians, dependent minors, site leads, media moderators, organizers, tenant owners, platform support/admins, background workers, identity providers, notification providers, and hostile/untrusted clients.

Trust boundaries:

- device/browser ↔ public API;
- authenticated client ↔ tenant API/RLS;
- API/Edge Function ↔ PostgreSQL and outbox;
- API/worker ↔ private R2 buckets/CDN;
- webhook/provider ↔ ingestion endpoint;
- CI/CD ↔ environment secrets and release signing;
- support operator ↔ just-in-time production access;
- public derivative/CDN ↔ internet and downstream caches.

Every boundary authenticates its peer where possible, authorizes each operation, validates input and output, attaches a request/operation ID, applies replay/rate controls, and emits redacted audit/telemetry.

## Threat model and required controls

### Tenant escape and IDOR

- Every tenant row has a non-null `organization_id` and tenant-consistent composite foreign keys.
- Enable and force RLS on exposed tables. Policies cover all operations and use server-derived identity/role claims, never a body-provided tenant alone.
- Public access uses explicit views/DTOs that contain only published fields.
- Security-definer functions set a safe search path, validate actor and tenant, expose minimal grants, and are directly tested.
- Realtime, exports, signed URLs, storage policies, jobs, and caches use the same tenant/resource scope.
- Foreign and nonexistent sensitive IDs return non-enumerating errors where practical.

### Identity, invitation, and privilege takeover

- Use provider state/nonce/PKCE and exact callback allowlists; validate issuer, audience, signature, expiry, and replay.
- Store tokens in Keychain on iOS with appropriate accessibility; never UserDefaults, logs, screenshots, or analytics.
- Invitations are random, hashed at rest, scoped, expiring, single-use, and invalid after inviter loss of authority.
- Owners cannot grant platform roles; last-owner constraints are transactional.
- Role/suspension/support-grant changes invalidate authorization caches and sessions within a documented maximum.
- Platform production access is MFA-protected, just-in-time, reason/ticket-bound, expiring, and immutably audited.

### Consent and guardian forgery

- Legal text is versioned and content-hashed. Evidence is append-only and binds signer, participant, relationship attestation, tenant, document, version, locale, method, time, and request context.
- Active requirements are calculated server-side; the client cannot declare a document satisfied.
- Team lead, staff membership, emergency contact, or shared registration never grants guardian authority.
- Revocation/supersession preserves history and triggers documented downstream participation/media policy.
- Avoid claims of identity/relationship verification stronger than the product actually performs. Legal counsel approves waiver, guardian, child-privacy, retention, and jurisdiction language before release.

### Capacity, lifecycle, replay, and concurrency

- Hard capacity, assignment, attendance, consent, moderation, deletion, and owner changes run in database transactions with constraints/locking appropriate to the invariant.
- Idempotency keys bind actor, tenant, route, and canonical payload hash; same key/same payload returns the first result, while changed use conflicts.
- Client operation IDs persist before network send and survive restart. Webhooks/outbox/jobs are replay-safe and deduplicated.
- Expected resource versions reject stale mutation. Realtime is advisory; reconnect refetches canonical state.
- Retry policies distinguish validation/auth/conflict/rate/server/network failures and use bounded jittered backoff.

### Malicious media, member-feed, and public-content abuse

- Adult identity is verified server-side before a short-lived, one-use, tenant/object/size/type/checksum-bound upload authorization.
- Objects enter a private quarantine bucket. Completion independently checks ownership, actual bytes/MIME, checksum, size, dimensions/duration, and scan/transform outcome.
- Processing is isolated and resource-limited. Reject polyglots, malformed/decompression-bomb inputs, unsupported formats, and incomplete uploads.
- Strip EXIF/GPS/XMP, filenames, embedded thumbnails, and unsafe metadata. Public delivery uses only approved derivatives with controlled cache policy; never reveal originals or storage keys.
- After successful validation/processing, an adult upload is automatically visible to authenticated members of the associated occurrence's event feed; moderator preapproval is not part of this member-feed transition. Event membership, occurrence, tenant, adult-uploader status, and applicable guardian visibility are enforced server-side at delivery.
- An unreported member-feed item remains visible. A report atomically hides/quarantines it from the member feed pending review; a moderator can restore or remove it with an audited reason.
- Anonymous public-gallery publication is a separate state and requires its own explicit moderation/visibility decision. A member-feed URL or entitlement never implies anonymous-public access.
- Moderation and guardian visibility are rechecked at feed/gallery delivery. Reports must immediately stop applicable delivery while preserving restricted evidence and audit history.
- Rate-limit upload/report/moderation/notification paths. Provide reachable report/block/support paths; no face recognition.

### Location, incidents, and safety

- Public location is a separate allowlisted representation from precise operations location.
- Directions do not require current location; foreground/on-demand permission is requested in context.
- Safety Sharing is voluntary, adult-only, purpose/occurrence/site/recipient-scoped, visibly active, bounded by a server maximum, manually stoppable, and server-expired.
- Do not store movement history or send precise location through analytics, logs, crash breadcrumbs, push, or general realtime.
- Incident content/attachments use dedicated restricted policies, append-only audit, separate retention, no routine analytics/export, and documented emergency/escalation playbooks.
- The app states that it supports coordination and does not replace emergency services or trained supervision.

### API, web, notification, and export abuse

- HTTPS only; production hosts and identity callbacks are allowlisted. Apply secure headers, CSRF protection where cookies are used, output encoding, and strict CORS.
- Validate schemas, lengths, Unicode/control characters, file bytes, coordinates, pagination, sort/filter fields, and state transitions server-side.
- Return stable safe errors with request IDs, not SQL, stack, policy, token, contact, or existence details.
- Audience queries are role checked; recipient lists and addresses never appear in responses. Webhook signatures include timestamp/replay validation.
- Exports are authorization checked at request and download time, formula-injection safe, encrypted, short-lived, single-purpose, audited, and deleted on schedule.
- Deep links authenticate before showing private content; push previews contain no sensitive data.

### Availability, supply chain, and delivery

- Rate limits distinguish actor/tenant/IP/resource and do not rely on IP alone. Use quotas, timeouts, body limits, queue backpressure, dead-letter handling, and cost alerts.
- Pin dependencies and CI actions; review licenses; run secret, SAST, dependency, IaC, and artifact scans.
- Separate development, preview, staging, and production projects/buckets/credentials/callbacks. Production data never seeds lower environments.
- Protect release branches, require review/status checks, use least-privileged CI identities, sign artifacts, retain provenance, and rotate exposed credentials.
- Backups, point-in-time recovery, migration rehearsal, restore tests, rollback, and degraded-mode runbooks are mandatory before production.

## Privacy controls by lifecycle

### Collection and notice

- Maintain a field-level inventory: purpose, necessity, sensitivity, source, legal basis, processors, access roles, retention, export, and deletion behavior.
- Provide just-in-time, plain-language notice before location, photo, notification, guardian/dependent, public media, accommodation, emergency contact, and analytics collection.
- Separate required operational processing from optional communications/marketing and public publication.
- Use data minimization defaults. Free text warns users not to enter unnecessary medical or incident details.

### Use and disclosure

- Use data only for its disclosed purpose. No sale, targeted advertising, face recognition, public live tracking, peer direct messages, or automated safety decisions in v1.
- Public release is explicit and allowlisted. Approved media remains subject to report, guardian change, and takedown.
- Aggregates apply documented small-cell suppression and anti-inference rules.
- Processors receive only necessary data under reviewed contracts/configuration.

### Storage and retention

Retention values require owner/legal approval before beta. Until approved, use conservative short defaults in non-production and do not claim final retention publicly.

At minimum define separate schedules for profiles/accounts, invitations/sessions, registrations/attendance, consent evidence, dependents, precise Safety Sharing, incidents, media originals/derivatives/reports, notifications, exports, audit events, logs/traces/crash reports, deletion tombstones, and backups. Expiry jobs are monitored and tested. Legal holds are explicit, narrow, authorized, and audited.

Offline iOS data is minimal and encrypted using a Keychain-protected key, excluded from backup where appropriate, protected while the device is locked, and removed on sign-out/account deletion when policy permits.

### Individual and guardian rights

- Support access, correction, portable export, deletion, and guardian requests with authenticated status tracking.
- Reauthorize sensitive actions; prevent requests against another household/tenant.
- Deletion is an idempotent state machine across database, identity, R2/CDN, notification, analytics, exports, backups/tombstones, and processors.
- Tell users what is deleted, retained, de-identified, legally held, or scheduled to age out. Do not promise immediate backup erasure if that is not technically true.

## Logging, analytics, and audit

Operational logs are structured and use opaque IDs. Central redaction tests fail builds when fields include names, email/phone, minor identifiers, emergency contacts, accommodations, consent payloads/signatures, incident text, coordinates, object keys/private URLs, tokens, authorization headers, or raw request bodies.

Security/audit events are append-only and record actor, tenant, action, target opaque ID/type, result, reason code where needed, request ID, time, and trusted source metadata. Audit access is restricted and itself audited. Do not put the sensitive changed payload into a general audit row.

Analytics events use an approved allowlist and cannot reconstruct a person's location or minor/incident journey. Crash reports disable/clean screenshots, breadcrumbs, URLs, view contents, and custom context that could capture restricted data.

## Security verification and review cadence

- Threat-model review for every new trust boundary or Restricted-data flow.
- RLS and API authorization matrix on every policy/schema change.
- Secret/SAST/dependency scans on every pull request; full scan and SBOM per release.
- Manual privacy/log review and abuse tests per milestone.
- Independent penetration test before broad public launch and after material auth/tenant/media changes.
- Quarterly access/processor/retention review and annual incident/recovery exercise after production.

Exact commands and adversarial cases are maintained in `docs/TEST_STRATEGY.md`. A clean scanner result does not offset a missing server-side control.

## Threat and risk register

Likelihood/impact are preliminary until architecture and production controls exist.

| ID | Risk | Likelihood | Impact | Required treatment and evidence | Status |
|---|---|---:|---:|---|---|
| R-001 | cross-tenant access through API/RLS/realtime/export/storage | High | Critical | tenant-composite schema, forced RLS, full role/operation matrix, IDOR test, independent review | Open; release blocker |
| R-002 | public endpoint leaks precise site/arrival/internal fields | Medium | High | separate public DTO/view allowlist, response schema, cache/network inspection | Open; current model mixes fields |
| R-003 | forged guardian authority or stale consent satisfies a minor requirement | Medium | Critical | household authority model, immutable versioned evidence, revocation tests, legal review | Open; not implemented |
| R-004 | minor uploads or public visibility bypass client checks | Medium | Critical | API/RLS/storage enforcement at each lifecycle step, guardian policy tests | Open; only local model check exists |
| R-005 | concurrent registration/assignment exceeds hard safety limit | High | High | transactional constraint/locking, burst test, reconciliation | Open; allocator is local only |
| R-006 | retry creates duplicate registration/attendance/notification | High | High | persisted idempotency ledger and client key, outbox/webhook dedupe, lost-response tests | Open; registration key is regenerated per call |
| R-007 | precise location is retained, broadcast, logged, or shared after expiry | Medium | Critical | separate restricted store/channel, server expiry, redaction and termination/offline tests | Open; transport not implemented |
| R-008 | malicious upload reaches processors/public users or exposes EXIF/GPS | High | High | bounded private quarantine, sniff/scan/transform, derivative-only delivery, metadata tests | Open; media pipeline not implemented |
| R-009 | reported media remains accessible in the event-member feed or anonymous gallery through API/CDN/cache/signed URL | Medium | High | atomic report-to-quarantine, controlled TTL/invalidation, delivery recheck, read/report race and takedown tests | Open |
| R-017 | approval-first implementation withholds valid adult uploads, or a single “published” state conflates member-feed and anonymous-public visibility | High | High | distinct feed/gallery visibility model; automatic post-processing member visibility; explicit public-gallery approval; contract and state-machine tests | Open; current code/contract diverge |
| R-010 | support/admin or CI credential misuse | Medium | High | JIT MFA access, reason/expiry/audit, least-privileged CI, secret rotation/scans | Open |
| R-011 | offline queue is lost, readable, corrupted, or replayed concurrently | High | Medium | encrypted durable store, atomic writes, single-flight reconcile, operation IDs and corruption tests | Open; persistence defaults to no-op |
| R-012 | wrong device time zone shows wrong event time/date | High | Medium | render in occurrence IANA zone, DST/device-zone tests | Open; UI uses device default |
| R-013 | deletion/export is incomplete across processors/backups or leaks data | Medium | High | inventoried deletion state machine, tombstones, download auth/expiry, restoration test | Open; not implemented |
| R-014 | notification/realtime payload reveals recipient, minor, incident, or location data | Medium | High | payload allowlist, audience auth, redaction tests, provider configuration | Open; not implemented |
| R-015 | vulnerable/unpinned dependency or compromised release pipeline | Medium | High | lockfiles/action pinning, SBOM/scans, protected review, signing/provenance | Open; CI absent |
| R-016 | insufficient App Store privacy/account deletion/UGC controls blocks release | High | High | truthful disclosures, in-app deletion, reporting/takedown/support, privacy manifest, review rehearsal | Open |

Risk owners and target dates belong in `docs/IMPLEMENTATION_STATUS.md`/issue tracking. Critical and High residual risks require documented security/privacy and release-owner acceptance; tenant escape, public Restricted data, guardian bypass, or missing mandatory platform controls cannot be accepted for production.

## Incident response minimum

Before staging handles sensitive flows, document and rehearse:

1. intake, severity, on-call ownership, and out-of-band escalation;
2. immediate containment for tenant policy, credential, media publication, precise location, and notification incidents;
3. evidence preservation with restricted access and chain-of-custody notes;
4. credential/key/session revocation and safe policy rollback;
5. affected-data/tenant/user assessment and legal notification decision;
6. recovery validation, monitoring, user communication, and post-incident corrective work.

Do not expose incident or child-safety details in general issue trackers. Public security contact and reporting instructions must exist before launch.

## Required approvals before production

- Security: threat model, RLS matrix, penetration findings, secrets/dependencies, runbooks, and no unresolved Critical/High findings.
- Privacy/legal: data inventory, notices/policy, waiver/guardian/child terms, retention/deletion, processors, App Privacy answers, and jurisdictional obligations.
- Product/operations: safety escalation, moderation/reporting response, support access, emergency language, and event-day incident process.
- Release owner: evidence that implemented behavior and disclosures match; no approval is inferred from this engineering plan.
