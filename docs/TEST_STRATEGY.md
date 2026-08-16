# Day of Service test strategy

Status: living plan, reviewed against `main` at commit `1c2a95286d2d4692b3ebdf47247b0bac0ff44a87` on 2026-08-16.

## Purpose and quality goals

This strategy covers the iOS app, responsive public/guardian web flows, organizer web console, API, PostgreSQL/PostGIS policies, Cloudflare R2 media pipeline, jobs, and delivery infrastructure. Tests are evidence for the functional requirements in `documents/05-functional-requirements.md`; they do not replace server-side controls.

The product is releasable only when it demonstrates:

- complete tenant isolation, including direct database access through every exposed role;
- safe, attributable consent and guardian workflows;
- atomic capacity, assignment, attendance, moderation, and deletion transitions;
- correct behavior during retries, concurrency, stale data, and intermittent connectivity;
- private-by-default media processing, correctly scoped event-member feed visibility, and precise location handling;
- usable critical journeys with VoiceOver, large text, reduced motion, keyboard/focus navigation, and supported devices;
- observable failure without logging personal, minor, incident, consent, media, or precise-location data.

## Current baseline

The current repository contains a Swift package with core models, a preview-only SwiftUI slice, an HTTP client, and 11 Swift Testing tests. It does not yet contain an Xcode project, iOS UI test implementation, CI workflow, backend, migrations/RLS, web application, media pipeline, or deployment configuration. Therefore:

- `swift test` is the only repository-level test command expected to work today;
- authorization tests exercise a local value type, not the required server/RLS policy boundary;
- preview registration is not an end-to-end test because `PreviewEventService` accepts it locally;
- all database, contract, integration, UI, accessibility, security, performance, and release tests below are planned gates until their components exist.

No milestone may convert a planned gate to “not applicable” merely because its implementation has not been built.

## Test ownership and evidence

- Feature developers write unit tests and component-level failure cases with each change.
- The automated test engineer owns fixtures, contract/database/integration/UI suites, CI execution, and flaky-test quarantine.
- Functional QA independently verifies acceptance criteria on a production-like build.
- Edge/abuse QA attacks validation, permissions, lifecycle, concurrency, offline, and device boundaries.
- The security/quality auditor reviews RLS, auth, privacy, dependencies, logging, accessibility, and release evidence independently.
- The delivery lead links each requirement, defect, test result, and accepted residual risk in the release record.

Evidence belongs in CI artifacts or the pull request: exact command, commit SHA, environment, result bundle/report, screenshots or recordings where useful, failures, and residual risk. Tests must use synthetic identities and must never put real minor, incident, precise-location, or consent data in fixtures.

## Test pyramid

The target automated mix is approximately:

| Layer | Target | Runs | Examples |
|---|---:|---|---|
| Unit and property tests | 60% | every change | validation, allocation, state machines, redaction, time zones, retry classification |
| Database, contract, and component integration | 25% | every change affecting a boundary; full suite nightly | constraints, RLS matrix, API schemas, object lifecycle, job retries |
| UI and end-to-end | 15% | critical smoke on every change; full suite nightly and before release | registration, guardian consent, check-in, moderation, deletion |

Manual exploratory, accessibility, device, penetration, load, recovery, and legal/privacy review sit outside the percentage. A small UI layer is intentional; critical policy behavior must be tested closer to the database/API boundary where failures are easier to isolate.

## Deterministic fixtures

Maintain versioned builders/fixtures for:

- tenants `alpha` and `bravo`, plus similarly named resources in each tenant;
- public visitor, authenticated adult, guardian, dependent, suspended user, site lead for one site, moderator, organizer, owner, platform support, and platform admin;
- active, expired, revoked, and single-use invitations and support grants;
- draft, published, cancelled, completed, and archived occurrences in UTC, `America/New_York`, and `America/Chicago`, including DST gaps/folds and year boundaries;
- sites below/at/above soft targets and below/at hard safety limits;
- individual, `prefer_together`, and `must_stay_together` teams of boundary sizes;
- active, retired, superseded, revoked, translated, and tampered legal documents/evidence;
- every attendance, assignment, safety-share, incident, notification, export, deletion, and media state;
- expired tokens, signed URLs, cursors, sessions, shares, upload grants, and feature flags;
- malformed, oversized, duplicate, stale-version, unsupported-enum, Unicode, bidirectional-text, and control-character payloads.

Fixture IDs are stable UUIDs. Clocks, UUID generation, network reachability, and retry schedules must be injectable. Tests freeze time rather than sleeping.

## Acceptance-to-test traceability

| Requirement | Minimum automated evidence | Independent acceptance/abuse evidence |
|---|---|---|
| FR-001 | provider callback/state/nonce tests; token refresh/revocation; session expiry; device sign-out | cancelled login, stale callback, account switch, stolen/replayed callback, offline launch |
| FR-002 | complete RLS allow/deny matrix; API IDOR tests; tenant-context mismatch tests | enumerate/guess UUIDs across tenants; alter body/path tenant IDs; realtime cross-tenant subscription |
| FR-003 | invitation expiry/single-use; role-grant authorization; last-owner constraint; cache/session revocation | duplicate acceptance, concurrent owner removal, organizer escalation, suspended inviter |
| FR-004 | export completeness/schema; deletion state machine; retention/tombstone/retry tests | export another user, restore-after-delete, partial processor failure, guardian/dependent request |
| FR-101 | CRUD/state transition/validation tests for definitions, occurrences, sites, shifts, tasks | unauthorized edits, publish invalid schedule, stale draft, destructive confirmation, preview indexing |
| FR-102 | public DTO allowlist and response schema; draft/archived exclusion; location precision test | inspect network/cache/search metadata for restricted address, roster, contact, arrival, or object keys |
| FR-103 | individual/team request validation and persistence; duplicate submission idempotency | very large/empty/duplicate teams, repeated submit, back navigation, Unicode names, lost response |
| FR-104 | allocator property tests; eligibility/accessibility/overlap constraints; transactional hard-cap test | concurrent registration/assignment burst; zero/negative capacities; no eligible site; stale occupancy |
| FR-105 | atomic transition, outbox, audit, optimistic concurrency, and idempotency tests | two organizers confirm simultaneously; notification retry; stale waitlist promotion |
| FR-106 | active-version lookup; immutable evidence; signer/participant/relationship binding | substitute participant/document/tenant; revoked/superseded evidence; clock and locale boundaries |
| FR-201 | roster query and mutation RLS by tenant, occurrence, site, time, suspension | site lead requests another site/date/tenant; expired assignment; guessed registration ID |
| FR-202 | operation-ID uniqueness; check-in/out state machine; offline persistence/reconciliation | double tap, two devices, reordered check-out/check-in, crash mid-save, corrupt queue, clock skew |
| FR-203 | role-scoped audience query, outbox dedupe, recipient redaction, opt-out handling | audience tampering, duplicate send, oversized content, quiet hours, recipient enumeration |
| FR-204 | deep-link construction and map-app fallback; no background permission use | deny location, no map app, approximate-only mode, malformed coordinates, offline directions |
| FR-205 | share authorization, purpose/duration limits, manual stop and expiry job | background/terminated app expiry, stale recipient, clock skew, replayed update, minor activation |
| FR-206 | restricted RLS, append-only audit, attachment access and analytics exclusion | public/lead/export/log/realtime leakage; update/delete history; malicious attachment |
| FR-301 | signed grant ownership, TTL, one-use/size/type/checksum bounds | MIME/polyglot/zip bomb, oversized/chunk abuse, expired/replayed grant, foreign object key |
| FR-302 | bucket policy and pipeline tests proving private quarantine until validation/processing, then automatic event-member feed visibility for a valid adult upload | request original before/while/after scan; access feed outside event membership; verify unreported items remain visible without preapproval |
| FR-303 | immediate report-driven feed hide/quarantine, review restore/remove, separate anonymous public-gallery approval, reason/audit, role/tenant checks | report/read race, stale/concurrent actions, repeated report, moderator self-scope, cached/signed derivative after takedown |
| FR-304 | guardian/dependent binding and visibility policy; minor uploader rejection at API/RLS | falsified age/guardian/team leader; revoked guardian consent; direct storage/API upload |
| FR-305 | derivative-only public response; EXIF/GPS strip verification; key/URL redaction | crafted EXIF/XMP/filename, cache poisoning, range requests, expired signed URL |
| FR-401 | aggregation/export accuracy; suppression threshold; authorization and job isolation | small-cell inference, filter combinations, CSV injection, export URL leakage/expiry, deleted users |

Each pull request must add or update trace links for affected requirement IDs. A requirement is not accepted while its minimum evidence is still “planned.”

## Mandatory adversarial suites

### Tenant and RLS isolation

For every tenant-owned table and storage/realtime policy, generate tests for anonymous, adult/guardian, suspended, each organization role, platform support without/with valid grant, and service jobs. For each role test `SELECT`, `INSERT`, `UPDATE`, `DELETE`, RPC/function calls, realtime subscription, and object access.

Required abuse cases:

1. Read and mutate tenant Bravo by changing a tenant UUID while authenticated to Alpha.
2. Reference an Alpha parent from a Bravo child row; composite foreign keys must reject it.
3. Omit `organization_id`, set it to null, or rely on a client-provided default.
4. Guess UUIDs through API paths, filters, nested relations, exports, signed URLs, and deep links.
5. Join/filter through a non-RLS view, security-definer function, materialized view, or storage metadata table.
6. Subscribe to a global or wildcard realtime channel and inspect errors/timing for existence leaks.
7. Reuse a cached role/session after suspension, invitation revocation, role removal, or support-grant expiry.
8. Attempt role escalation, last-owner removal, self-approval, and platform-role grant by a tenant owner.
9. Verify deny behavior is the same for missing and foreign records where existence is sensitive.
10. Prove logs, metrics, traces, crash reports, and analytics contain no cross-tenant payload.

RLS tests must execute as actual database roles/JWT claims; mocking `AuthorizationContext` is insufficient.

### Concurrency and idempotency

- Send 50–500 simultaneous registrations against one remaining hard-cap slot; committed occupancy never exceeds the limit.
- Submit the same idempotency key and byte-equivalent payload concurrently; return one canonical result.
- Reuse the key with a different payload, tenant, actor, or endpoint; return a stable conflict without data change.
- Lose the response after commit, restart the client, and retry with the persisted key.
- Double-tap, back/forward submit, and launch the same action from two devices.
- Concurrently promote a waitlist entry, confirm assignments, check in/out, moderate/take down media, revoke consent, stop/expire sharing, and remove/change the last owner.
- Exercise optimistic version conflicts, deadlocks, transaction retry, outbox dedupe, webhook replay, and job redelivery.
- Verify clocks do not determine uniqueness and that operation IDs survive app restarts.

### Offline, interruption, and reconciliation

- Launch with no network; move among offline-capable screens; show freshness and unavailable actions accurately.
- Interrupt before local save, after local save/before send, after server commit/before response, and during local removal.
- Terminate/relaunch with a pending queue; corrupt/truncate the queue; rotate/lose the encryption key; fill disk.
- Reconcile reordered and stale operations, partial successes, 401/403/409/429/5xx, timeouts, captive portal, and network flapping.
- Start reconciliation twice concurrently and from two devices; never create duplicate state.
- Preserve user input after recoverable failure and provide explicit resolution for rejected conflicts.
- Verify offline data is minimal, encrypted at rest, protected by device policy, and removed on sign-out/deletion.

### Media and user-generated content

- Validate JPEG/PNG/HEIC/video by sniffed bytes, not extension or declared MIME.
- Reject unsupported codecs, decompression bombs, malformed dimensions, oversized files, checksum mismatch, truncated multipart upload, and malicious metadata.
- Strip EXIF, GPS, XMP, filenames, thumbnails, and other embedded metadata from every public derivative.
- Keep original and quarantine objects private throughout scanning, transformation, failure, rejection, and retention.
- After validation and processing succeed, make an adult upload visible automatically to authenticated members of that occurrence's event feed without moderator preapproval. Prove nonmembers, anonymous users, other occurrences, and other tenants cannot read it.
- Prove an unreported member-feed item remains visible; background jobs or absent moderation must not silently withdraw it.
- A report atomically hides/quarantines the item from the event-member feed before returning success, pending moderator review. Exercise the read/report race and prove no post-report feed/cache delivery.
- Moderator review may restore a cleared item to the event-member feed or remove it. Keep this lifecycle distinct from approval for the anonymous public gallery, which is a separate, explicit publication decision.
- Test adult identity and guardian visibility at upload authorization, completion, feed visibility, report, review, public-gallery publication, and delivery—not only in the client. Minors are rejected at API, RLS, and object-authorization boundaries.
- Report/take down a feed/gallery item and prove feed/gallery removal, cache invalidation/control, signed URL expiry, search removal, audit, and notification.
- Rate-limit uploads/reports without preventing legitimate accessibility retries; prevent report spam and notification amplification.

### Minors and guardian authority

- A dependent cannot be created or modified outside an authenticated guardian-controlled household.
- Team membership, emergency contact, staff role, shared surname, or guessed ID never grants guardian rights.
- Consent binds signer, relationship attestation, participant, tenant, exact document hash/version/locale, method, and time.
- Retired/revoked/superseded consent is preserved but cannot satisfy a new requirement.
- Minors cannot upload media, publish, enable Safety Sharing, direct message, or change consent through UI, API, database, storage, deep link, or stale session.
- Guardian visibility withdrawal promptly affects future publication and triggers the documented treatment of existing media.
- Age/date boundaries cover leap day, DST, time zone, unknown DOB, and minimum-data alternatives.
- Public pages, exports, analytics, logs, push previews, and screenshots never expose minor rosters/contact/location.

### Location and maps

- Public DTOs return only policy-approved approximate labels/coordinates; precise operations location has a separate restricted field and policy.
- Time-zone rendering uses the occurrence/site IANA zone, not the viewer device zone, across DST gaps/folds.
- Directions work without granting location and offer a non-map address/instruction alternative.
- Denied, restricted, approximate, one-time, and revoked permissions produce clear states without repeated prompting.
- Safety Sharing is explicit, purpose- and recipient-scoped, visibly active, bounded by a server maximum, manually stoppable, and server-expired even when devices are offline.
- Verify no movement history, background collection, analytics coordinate, crash breadcrumb, push payload, or realtime precise location remains after stop/expiry.
- Test invalid/out-of-range coordinates, poles/antimeridian, geofence boundary, clock skew, and location spoofing assumptions.

## Accessibility and device matrix

Every critical flow receives automated accessibility identifiers/traits checks plus manual assistive-technology testing. “Automated passed” never substitutes for VoiceOver testing.

Required iOS coverage before release:

- smallest supported iPhone and current large-screen iPhone;
- oldest supported iOS 17.x and current production iOS on physical devices, plus current simulator CI;
- portrait and landscape where supported; light/dark mode; increased contrast; differentiate without color;
- Dynamic Type from default through the largest accessibility size without clipping or horizontal scrolling;
- VoiceOver order, names, values, hints, rotor headings, focus after navigation/error, modal dismissal, and live updates;
- Reduce Motion, Reduce Transparency, Button Shapes, Bold Text, Switch Control/Voice Control where critical;
- hardware/software keyboard and focus on web/organizer surfaces;
- slow device, low-memory termination, low storage, thermal pressure, camera/photos permission states, interrupted calls, and background/foreground transitions.

Web surfaces additionally cover current Safari iOS/macOS, Chrome, Firefox, 200% and 400% zoom, reflow to 320 CSS pixels, keyboard-only operation, visible focus, screen-reader semantics, error summaries, and WCAG 2.2 AA contrast/target size.

## Performance and reliability budgets

Numeric service-level objectives must be approved before beta and recorded in the release checklist. At minimum measure:

- registration/check-in latency and error rate under expected and burst event-day load;
- concurrent hard-cap correctness under database contention;
- public discovery cold/warm launch, API payload size, image memory, scroll responsiveness, and crash-free sessions;
- realtime reconnect and canonical reconciliation time;
- media upload/scan/moderation/takedown and export/deletion job completion;
- notification outbox lag, retry/dead-letter recovery, database saturation, and rollback recovery time.

Load fixtures must be synthetic and tenant-distributed. Averages alone are insufficient; report p50/p95/p99, error rate, saturation, and correctness invariants.

## Defect severity and release policy

| Severity | Definition | Examples | Release policy |
|---|---|---|---|
| Critical | active exploitation, broad sensitive-data exposure, tenant escape, destructive corruption, or safety feature causing immediate danger | cross-tenant minor roster; public originals/precise location; unrecoverable data loss | stop affected environments, incident response; blocks every release |
| High | credible unauthorized access, consent/guardian bypass, hard-cap race, account takeover, systemic critical-journey failure, or missing mandatory platform control | IDOR; minor upload accepted; duplicate confirmed registration after retry; no account deletion | blocks beta/production and affected merge unless isolated behind an off-by-default flag |
| Medium | material failure with bounded impact or viable workaround; accessibility failure affecting a supported journey; privacy/operational weakness | wrong event time zone; queue loses pending check-in; 403 shown as expired session | must be fixed before production unless release owner records owner/date/mitigation and security/privacy approve |
| Low | limited cosmetic, diagnostic, or maintainability defect with little user impact | minor copy inconsistency; noncritical layout polish | may ship with a tracked owner and target milestone |
| Improvement | useful enhancement without a current requirement failure | expanded property testing or developer tooling | prioritized normally; does not block alone |

No Critical or High issue may be waived by the development team. A disabled feature is acceptable only when it is inaccessible server-side, excluded from review paths, documented, and proven off in production.

Flaky critical tests are failures. Quarantine requires a defect, owner, expiration, and equivalent deterministic coverage; no release gate may silently ignore or retry-to-green a failure.

## Exact verification commands

### Available now

Run from the repository root with the pinned Swift toolchain:

```bash
swift --version
swift package describe
swift test --parallel
swift test --sanitize=address
swift test --sanitize=thread
python3 contracts/validate_contracts.py
```

`contracts/validate_contracts.py` becomes mandatory when the contract work lands on the tested branch. AddressSanitizer and ThreadSanitizer should run as separate CI jobs; unsupported host/toolchain combinations must be replaced by an equivalent supported Xcode job, not skipped without evidence.

### Required after the Xcode project and targets exist

CI must pin an actual installed simulator name and OS rather than using an unreviewed moving target. The planned commands are:

```bash
xcodebuild -project DOS.xcodeproj -scheme DOS -showdestinations
xcodebuild -project DOS.xcodeproj -scheme DOS -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DOS.xcodeproj -scheme DOS -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -resultBundlePath TestResults/DOSCore.xcresult test
xcodebuild -project DOS.xcodeproj -scheme DOSUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' -resultBundlePath TestResults/DOSUI.xcresult test
xcrun xcresulttool get test-results summary --path TestResults/DOSCore.xcresult
xcrun xcresulttool get test-results summary --path TestResults/DOSUI.xcresult
```

For App Store candidates:

```bash
xcodebuild -project DOS.xcodeproj -scheme DOS -configuration Release -destination 'generic/platform=iOS' archive -archivePath build/DOS.xcarchive
xcrun dwarfdump --uuid build/DOS.xcarchive/dSYMs/*.dSYM
```

### Required after backend/infrastructure exists

Run against disposable local/CI projects with synthetic fixtures:

```bash
supabase start
supabase db reset
supabase test db
python3 contracts/validate_contracts.py
```

The backend implementation must add one documented command for API/component integration, one for web unit tests, one for web end-to-end tests, one for load tests, and one for migration/restore rehearsal. CI cannot claim those gates before the repository provides the scripts and pinned dependencies.

### Security and quality checks required before beta

Once configuration and lockfiles exist:

```bash
gitleaks detect --source . --no-banner --redact
semgrep scan --config auto --error
osv-scanner scan source -r .
swift package show-dependencies --format json
```

Tools and rulesets must be version-pinned in CI. Reports are retained as artifacts and failures are triaged; security scanners are defense in depth and do not replace manual/RLS abuse testing.

## Continuous improvement

After every milestone, QA reviews production-representative behavior and asks what is untested, confusing, fragile, privacy-sensitive, inaccessible, unobservable, or unrecoverable. Every reproducible bug receives a regression test at the lowest effective layer. The test inventory, fixtures, device matrix, performance budgets, and traceability table are updated whenever requirements or implementation change.
