# Day of Service product requirements

Status: living product baseline  
Last reviewed: 2026-08-16  
Product owner: Joe Skaggs  
Delivery owner: Project Manager / Product Delivery Manager

## Purpose and authority

Day of Service is a nationwide, multi-organization platform for planning and operating volunteer service events. It combines a native iPhone event-day experience, responsive public and guardian web flows, an organizer console, and a policy-enforced backend.

This document normalizes the repository requirements into one traceable product baseline. It does not replace `documents/05-functional-requirements.md`; the identifiers and intent in that file are preserved verbatim. The repository decision log (`documents/02-decision-log.md`) controls when prose conflicts, unless an accepted ADR explicitly supersedes it.

## Product outcomes

- Any authenticated adult can create an organization and organize an event without a new app, city fork, or year-specific codebase.
- Organizers enter event dates, IANA time zones, locations, sites, shifts, tasks, capacities, and policies. No event date or location is hard-coded.
- Visitors discover only published, non-sensitive event information.
- Adults register themselves, teams, and guardian-controlled dependents with attributable evidence for the active legal documents.
- Site leads operate assigned rosters and attendance even when connectivity is unreliable.
- Adult-submitted media follows the approved moderation and takedown lifecycle; minors cannot upload or publish media.
- Organizations can measure attendance and impact without exposing sensitive participant, minor, incident, or location data.

The first planned operating target is Martin Luther King Jr. weekend 2027. This is a pilot/release planning target, not an application rule; organizers remain responsible for supplying the actual occurrence schedule and location.

## Users

| User | Intended outcome |
|---|---|
| Visitor | Discover published organizations, events, sites, accessibility information, and approved impact stories. |
| Adult volunteer | Authenticate, register alone or with a team, sign documents, receive assignments, check in/out, complete work, receive announcements, and submit permitted media/impact information. |
| Guardian | Create named dependents, consent separately for each dependent, and control participation and media visibility. |
| Site lead | Access only assigned operational details, rosters, attendance, tasks, incidents, and announcements. |
| Organizer | Configure one tenant's events, sites, registration, assignments, communications, moderation, and reports. |
| Organization owner | Manage tenant membership, roles, settings, and organizer capabilities. |
| Platform operator | Support tenants and investigate abuse through justified, expiring, audited access rather than routine tenant-data access. |

## Product invariants

| ID | Requirement |
|---|---|
| PR-001 | Every tenant-owned record has an immutable, server-derived `organization_id`; authorization and PostgreSQL RLS deny access by default. |
| PR-002 | Reusable event definitions are distinct from dated occurrences. Organizer-supplied schedule and location data use IANA time zones and are never hard-coded for the pilot. |
| PR-003 | Consent is attributable, participant-specific, versioned evidence. A mutable Boolean or a list of document IDs is not sufficient production evidence. |
| PR-004 | A dependent remains guardian-controlled; team membership never conveys guardian authority. Minors cannot upload/publish media, direct message, activate Safety Sharing, or alter consent. |
| PR-005 | Precise Safety Sharing is voluntary, purpose-limited, recipient-scoped, visibly active, manually stoppable, automatically expiring, and off by default. |
| PR-006 | Media originals remain private. After validation/processing, an adult upload becomes visible immediately in the authorized event/group member feed without platform preapproval; minors cannot upload. A report immediately hides it pending review. Anonymous public-gallery publication is a separate, approval-controlled state, and guardian/policy changes can also trigger immediate takedown. |
| PR-007 | Public location, realtime events, logs, analytics, exports, and galleries exclude private addresses, precise safety location, minor rosters, consent payloads, incident text, object keys, and unnecessary personal data. |
| PR-008 | Registration, assignment, attendance, consent, moderation, and other retryable transitions are transactional, idempotent, auditable, and reconcile to canonical server state. |
| PR-009 | App Store review is the production distribution path. TestFlight is used only for beta validation. |
| PR-010 | Secrets and privileged credentials remain in server-side secret management and never enter source, fixtures, logs, mobile binaries, or browser bundles. |

## Known requirement normalization gap

| ID | Gap | Required resolution |
|---|---|---|
| PG-001 | The existing approval-first media state prose/code uses “published” without separating authorized event/group feed visibility from anonymous public-gallery publication. The owner has decided that a processed adult upload appears immediately in the member feed, a report hides it immediately pending review, minors cannot upload, and anonymous gallery publication remains separately moderated. Draft PR #12 also needs review for a distinct feed/gallery contract surface. | Lead Architect/contract owner records the distinction in an accepted ADR and versioned contract before WP-MED-01 implementation. Update the repository decision/functional/media documents so future agents cannot collapse the two audiences into one state. Add feed-membership, report/hide/review, guardian, and gallery-approval fixtures/tests. |

## Functional-requirement traceability

Status describes the whole requirement, not the existence of a model or contract. `In progress` means partial implementation exists but the requirement has not met the repository definition of done. Contract support in draft PR #12 is under review and does not by itself complete a feature.

| ID | Normalized requirement | Planned implementation | Required acceptance and test evidence | Status |
|---|---|---|---|---|
| FR-001 | Users authenticate with configured providers and can recover from cancellation, expiry, offline state, and session failure. | #10 identity slice on #5, accepted #6, and #7. | Apple/Google success, cancellation, failure, expiry, refresh/revocation, secure-token, UI/accessibility, and stale-session deny tests. | Blocked |
| FR-002 | The server derives tenant context and checks tenant, role, resource state, and assignment scope on every tenant mutation. | #7 RLS/policy foundation, then #10; Swift `AuthorizationContext` remains advisory only. | Role-by-table allow/deny matrix; cross-tenant IDOR/read/write tests; suspended/removed member denial; audit evidence. | In progress |
| FR-003 | Owners invite, expire, revoke, and role-scope members without removing the last owner or granting platform roles. | #7 invitation/membership schema and #10 owner UI/flows. | Single-use/expired/revoked invite tests; wrong-tenant and privilege-escalation denial; last-owner constraint; session/cache revocation. | Blocked |
| FR-004 | Users export and request deletion/correction of eligible personal data, subject to documented retention and legal holds. | #10 hooks plus WP-ADM-01 privacy operations. | Ownership checks, asynchronous job lifecycle, redacted export, deletion/tombstone/backup behavior, guardian requests, audit, and UI recovery tests. | Blocked |
| FR-101 | Organizers manage reusable events, dated occurrences, sites, shifts, tasks, eligibility, and publish state. | WP-EVT-01 on #7 and #9; iOS may consume but organizer authoring is web-first. | CRUD/state-transition authorization, validation, time-zone/DST, draft preview/indexing, publish confirmation, optimistic concurrency, accessibility, and rollback tests. | Blocked |
| FR-102 | Public discovery exposes only published, policy-approved fields and approximate/public locations. | Existing iOS discovery prototype; #7 public views/functions; #8 iOS integration; #9 public web. | Draft/archived/private-field non-disclosure, pagination, empty/error/offline UI, location precision, cache/realtime reconciliation, web/iOS accessibility tests. | In progress |
| FR-103 | Adults register individuals, teams, and guardian-controlled dependents and select `prefer_together` or `must_stay_together`. | Existing one-participant Swift form/model; WP-REG-01 across #7, #8, and #9. | Individual/team/dependent flows, duplicate/retry handling, invalid/large input, guardian authority, eligibility, accessibility, cancellation/offline, and cross-tenant denial. | In progress |
| FR-104 | Allocation respects hard safety limits, eligibility, accessibility, shift overlap, and `must_stay_together`; soft targets may be exceeded. | Existing deterministic Swift allocator as reference; authoritative transactional planner in WP-ASG-01/#7. | Concurrent capacity, eligibility/accessibility/overlap, whole-team placement, soft-target exceedance, deterministic preview, fairness review, and rollback tests. | In progress |
| FR-105 | Waitlist and assignment transitions are atomic, idempotent, auditable, and communicated. | WP-ASG-01 database mutation, outbox, organizer preview/confirm, participant status UI. | Race/retry/conflict, legal state transition, notification de-duplication, audit, stale preview, cancellation, and tenant/role denial tests. | Blocked |
| FR-106 | Every required participant has evidence for the active document versions before registration confirmation. | Existing client validation is only preliminary; WP-REG-01 consent ledger and guardian web flow. | Per-participant active-version evidence, signer/relationship, superseded/revoked history, forgery/over-posting denial, guardian authentication, locale/hash, and concurrency tests. | In progress |
| FR-201 | Authorized site leads view only assigned rosters and check participants in/out. | WP-OPS-01 on #7, #8, and #9. | Site/occurrence/time-scoped roster, wrong-site/tenant denial, minimized minor/contact data, check-in/out state transitions, accessibility and event-day load tests. | In progress |
| FR-202 | Scan/manual attendance is idempotent and supports an encrypted offline queue with visible conflict feedback. | Existing `OfflineAttendanceQueue` and API protocol; #8 production storage/reconciliation and WP-OPS-01 server operation. | Stable operation IDs, duplicate/replay, corrupted/persistence failure, partial sync, reconnect/conflict, wrong roster, encryption-at-rest, and UI feedback tests. | In progress |
| FR-203 | Organizers publish authorized targeted announcements without exposing recipient lists. | WP-OPS-01 announcement/outbox/provider integration and organizer preview UI. | Audience authorization, recipient estimation, hidden addresses/lists, duplicate suppression, quiet hours/time zones, emergency path, provider webhook replay, and failure recovery. | Blocked |
| FR-204 | Users open directions in a chosen maps application without enabling background tracking. | #8/WP-OPS-01 foreground directions experience. | App-choice/fallback, permission denial, no-map alternative, approximate-versus-assigned precise address, deep-link validation, VoiceOver, and proof no background tracking is required. | Blocked |
| FR-205 | Voluntary Safety Sharing visibly indicates sharing and stops manually or automatically at expiry. | Existing Swift state model; WP-OPS-01/#7 authoritative policy, expiry job, and client UI. | Explicit purpose/recipient/site scope, maximum duration, manual stop, expiry, stale/offline state, unauthorized recipient, redacted realtime/logging, and no-history retention tests. | In progress |
| FR-206 | Incident records are restricted, append-audited, retained separately, and excluded from normal analytics. | WP-OPS-01 restricted database/API/UI and severity runbooks. | Site/role scope, append-only audit, attachment policy, analytics/log exclusion, retention/legal hold, malicious text/upload, support access, and emergency escalation tests. | Blocked |
| FR-301 | Adult users obtain short-lived, type/size/checksum-bound media-upload authorization. | WP-MED-01 Edge Function/R2 integration plus iOS/web picker. | Adult/role/tenant ownership, URL expiry/reuse, content bounds, checksum, rate limit, minor denial, malformed/oversized file, cancellation, and no-secret leakage. | Blocked |
| FR-302 | Storage objects remain private through validation/scanning/transformation. A successfully processed adult upload becomes immediately visible only in the authorized event/group feed; it is not thereby approved for an anonymous public gallery. | Existing approval-first Swift lifecycle must be revised; WP-MED-01 needs distinct storage, processing, member-feed, report-review, and public-gallery visibility states. | Private object ACL, authorized feed membership, immediate post-processing visibility, abandoned/failed upload expiry, MIME/checksum/malware failure, direct-object denial, and state/race tests. | In progress |
| FR-303 | Reports immediately hide member-feed/public visibility pending moderator review; authorized moderators restore, reject, redact, unpublish, or remove with reason codes. Separate moderator approval controls anonymous public-gallery publication. | Existing Swift transition rules only partially match; WP-MED-01 moderator/report console and authoritative server transitions. | Report-to-hidden latency, role/tenant scope, legal transitions, required reason, concurrent reports/actions, immutable audit, cache/signed-access invalidation, notification, restore/remove, and gallery-approval tests. | In progress |
| FR-304 | Guardians control dependent visibility and minors cannot be uploaders. | Existing `uploaderIsAdult` domain guard; WP-REG-01 guardian policy plus WP-MED-01 server enforcement. | Minor direct/forged upload denial, guardian grant/change/revocation, team-leader denial, mixed-subject attestations, takedown propagation, and privacy/audit tests. | In progress |
| FR-305 | Anonymous public galleries serve only separately approved, privacy-safe derivatives and never expose object keys or EXIF/GPS; member-feed visibility does not imply gallery approval. | WP-MED-01 transformation/delivery plus distinct member-feed and public-gallery queries. | Feed-versus-gallery authorization, EXIF/GPS stripping from delivered derivatives, signed/cache expiry after takedown, object-key/original denial, unpublished filtering, accessibility, load, and report/block/support tests. | Blocked |
| FR-401 | Organizers view/export privacy-thresholded attendance, hours, task, and impact aggregates. | WP-ADM-01 aggregate views/jobs and organizer reporting UI. | Tenant/role scope, suppression thresholds, no incident/minor leakage, reconciliation totals, large export, expiring download, audit, accessibility, and CSV-injection tests. | Blocked |

## Cross-cutting requirements

| ID | Requirement | Verification owner |
|---|---|---|
| NFR-001 | iOS supports iOS 17+, Swift 6, SwiftUI, structured concurrency, VoiceOver, Dynamic Type, contrast, reduced motion, and meaningful permission-denied/error states. | iOS developer + Functional QA + Automated Test Engineer |
| NFR-002 | Responsive web supports keyboard/focus, screen readers, localization-safe date/time handling, secure sessions, CSP/CSRF protections, and no browser-bundled secrets. | Web developer + Functional QA + Auditor |
| NFR-003 | PostgreSQL/PostGIS is authoritative; realtime is an invalidation hint and offline caches/outboxes reconcile after reconnect. | Architect + Integration/Platform Developer |
| NFR-004 | Critical mutations use transactions, optimistic version checks, idempotency keys, append-only audit/outbox records, retry limits, and deterministic conflict responses. | Integration/Platform Developer + Automated Test Engineer |
| NFR-005 | Development, preview, staging, and production use separate projects, buckets, credentials, callbacks, telemetry, and access controls. | Integration/Platform Developer + Auditor |
| NFR-006 | Redacted logs, metrics, traces, crash reporting, alerts, dashboards, and runbooks make failures diagnosable without recording sensitive journeys. | Integration/Platform Developer + Auditor |
| NFR-007 | Release has no unresolved Critical/High security issue, cross-tenant leak, accessibility blocker, failed critical journey, or unowned rollback/privacy action. | Auditor + QA + Delivery Lead |
| NFR-008 | Forms preserve safe progress after recoverable failure, show labels/hints/errors, identify required fields, validate on client and server, and offer a non-map alternative. | Feature developer + Functional QA |
| NFR-009 | Time-zone and DST behavior, concurrent event-day load, degraded network, duplicate input, large values, malformed input, and interrupted uploads are explicitly tested. | Edge Case/Abuse Tester + Automated Test Engineer |

## MVP scope

The MVP includes native iPhone discovery and event-day flows; responsive discovery, registration, guardian, and organizer web flows; self-service organizations; reusable events and dated occurrences; sites/capacity; individual/team registration; versioned waivers; guardian-controlled dependents; assignments; directions; attendance; announcements; private media processing/moderation and approved galleries; impact totals; audit; exports; and account deletion requests.

V1 excludes Android native, peer-to-peer direct messaging, public live volunteer tracking, automated facial identification, payments/fundraising, background-check adjudication, and autonomous safety decisions.

## Requirement change control

Every story, commit, test, and pull request should cite affected FR/PR/NFR identifiers. A material product or architecture change requires an ADR describing migration, compatibility, privacy/security, tests, rollout, and rollback. A requirement moves to `Complete` only after integrated behavior, automated and observable acceptance evidence, user-facing documentation, and all applicable definition-of-done gates pass.
