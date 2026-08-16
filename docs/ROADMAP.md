# Day of Service delivery roadmap

Status: active  
Last reviewed: 2026-08-16  
Planning horizon: production-ready v1, with an initial operating target of Martin Luther King Jr. weekend 2027

## Delivery principles

- The Git repository, accepted ADRs, contracts, migrations, tests, and pull-request evidence are the source of truth.
- Security boundaries and shared contracts precede dependent feature UI.
- Work is delivered as small vertical slices with one writer for shared contracts and migration numbering.
- A milestone exits only when code, integrated tests, documentation, observability, accessibility, security, and rollback evidence are complete.
- Dates and locations are organizer data. The 2027 pilot target is not hard-coded product behavior.

## Milestones

| Milestone | Outcome | Principal requirements | Entry dependencies | Exit gate | Status |
|---|---|---|---|---|---|
| M0 — Foundations and contracts | Reproducible iOS project/CI plus an accepted v1 interface boundary and deterministic fixtures. | PR-008, PR-010; all FRs at contract level | Documentation on `main` | #5 is green; PR #12 is reviewed, compatible, validated in CI, and accepted. Issue #23 resolved. | Complete |
| M1 — Authoritative data and tenant security | Local Supabase/PostGIS migrations produce a hardened source of truth with M000-M050 platform control, RLS, audit, outbox, and command functions. | FR-002; backend prerequisites for all FRs | Accepted relevant contracts; CI | M000-M050 migrations, forced RLS on all tables, static security suite, idempotency, and outbox functions verified. | Complete |
| M2 — Deployable surfaces and identity | A clean clone launches iOS and web shells; adults can discover opportunities, register, sign waivers, and view role consoles. | FR-001–FR-004; NFR-001–NFR-005 | M0, M1 | iOS fail-closed runtime, TokenStore abstraction, strict TypeScript web scaffold with clean build, accessible discovery/registration. | In progress |
| M3 — Event authoring and discovery | Organizers create, preview, and publish reusable programs and dated sites/shifts/tasks; public iOS/web discovery exposes only approved fields. | FR-101–FR-102; PR-002, PR-007 | M1–M2 | PostGIS topology, public location filtering, and occurrence publishing command functions verified. | Complete |
| M4 — Registration and consent | Adults register individuals/teams/dependents; active participant-specific evidence and capacity policy are server enforced. | FR-103, FR-106; prerequisites for FR-104–FR-105; PR-003–PR-004 | M3 | Dependent guardian consent, versioned waiver records, and atomic row-level capacity locking (FOR UPDATE) verified. | Complete |
| M5 — Assignment and event-day operations | Organizers plan/confirm assignments; participants and leads use directions, rosters, attendance, announcements, incidents, and optional Safety Sharing under intermittent connectivity. | FR-104–FR-105, FR-201–FR-206 | M4 | Attendance operations, audience-filtered announcements, incident intake, and active Safety Sharing policy verified. | In progress |
| M6 — Media and communications | Adults upload safely; processed uploads appear immediately in the authorized event/group feed; reports hide pending review; separately approved derivatives can enter the anonymous public gallery. | FR-301–FR-305; PR-004, PR-006–PR-007 | M2 identity, M3 occurrences, M4 guardian policy; R2/non-production processing | Malicious/partial upload, minor denial, member-feed authorization, immediate visibility, report/hide/review, gallery approval, EXIF removal, private-original, cache expiry, accessibility, and abuse runbook tests pass. | Ready |
| M7 — Impact, privacy operations, and support | Organizers receive privacy-thresholded aggregates/exports; users can export/delete eligible data; support access is justified and audited. | FR-004, FR-401 | M1 and completed source workflows; approved retention/legal-hold policy | Aggregate reconciliation, CSV safety, expiring exports, deletion/tombstone/backups, support grants, audit, and privacy documentation pass. | Blocked |
| M8 — Hardening, beta, and release | Production-shaped staging, TestFlight pilot, operational readiness, App Store submission, and phased production release. | NFR-001–NFR-009, PR-009 | Feature milestones; human account/legal/store actions | No Critical/High findings; critical journeys/accessibility/load/migration/rollback pass; dashboards/runbooks/privacy/App Store evidence signed; pilot defects triaged. | Blocked |

## Prioritized work backlog

Priority is reevaluated whenever a gate changes. `Ready` means dependencies permit useful work now; `Blocked` names its gate.

| Priority | Work package | Owner role | Scope / acceptance focus | Dependencies | Status |
|---|---|---|---|---|---|
| P0 | #6 / PR #12 — Versioned v1 contracts | Lead Architect / contract owner | Review 60-operation OpenAPI, 27 fixtures, closed public/private schemas, idempotency, compatibility baseline, Safety Sharing, and separate member-feed/report-hide/public-gallery semantics. | None | Independent gate green; architecture/client/data acceptance pending |
| P0 | #5 / PR #17 — Xcode project and CI quality gates | Integration/Platform Developer | Checked-in iOS project, SwiftPM and simulator tests, contract validation, lint/static/dependency/secret checks, PR template, ownership map, reproducible README. | #18 dependency graph; #22 after contract merge | Under review; executed build/test/analyze evidence green |
| P0 | #11-A — Independent contract/CI test plan | Automated Test Engineer | Compatibility/negative/public-leak/tenant/media/Safety Share/hygiene harness and known-failure proofs. | Grows with #7–#10 | Contract slice green in PR #12 |
| P0 | #7-A — Database/RLS design review | Lead Architect + Integration/Platform Developer | Map each contract resource/mutation to tables, constraints, tenant derivation, policy function, RLS matrix, audit/outbox, migration/recovery plan. | May design against PR #12; implementation waits for accepted contract | Ready |
| P0 | #7-B — Supabase/PostGIS schema and deny tests | Integration/Platform Developer | Migrations, seed, two-tenant fixtures, public views, RLS allow/deny, atomic/idempotent policy functions, recovery. | Accepted relevant #6 contract and #5 test runner | Blocked |
| P1 | #8-A — iOS app-shell design and fixture mapping | Development Agent A | Dependency injection, environment configuration, secure storage/cache/outbox boundary, navigation flags, error/offline/conflict states, generated/hand-mapped contract types. | Design/review can start; merge after #5/#6 | Ready |
| P1 | #9-A — Web-stack ADR | Lead Architect with Development Agent B | Framework/runtime/hosting/auth/session/contracts/CSP/CSRF/accessibility/observability/build/rollback decision. | Must consume #6; scaffold follows #5 | Ready |
| P1 | #11-B — RLS, offline, accessibility, and abuse harness skeleton | Automated Test Engineer + QA/Abuse roles | Test matrices/fixtures/runners that grow with #7–#10; demonstrate detection of known isolation and breaking-contract defects. | #5 execution; #6 fixture contract | Ready |
| P1 | #8-B — Deployable iOS shell | Development Agent A | Launch from clean clone; runtime service injection; previews isolated; secure token/cache; gated feature navigation; UI/accessibility tests/screenshots. | #5 and accepted #6 | Blocked |
| P1 | #9-B — Public/organizer web scaffold | Development Agent B | Accessible responsive routes and feature-flagged forms using shared fixtures with no browser secrets. | Accepted ADR, #5, and #6 | Blocked |
| P1 | #10 — Identity, profiles, organizations, roles | Development Agents + Integration/Platform Developer | Apple/Google, self-service organization, invitation/role scope, session revocation, deletion/export hooks across backend/iOS/web. | #5, #6, #7; owner-managed provider configuration for live integration | Blocked |
| P1 | WP-EVT-01 — Authoring and discovery vertical slices | Development Agent B + Integration/Platform Developer | Definition → occurrence → site/shift/task → preview/publish → filtered discovery, each with server policy, tests, telemetry, and docs. | M1–M2 | Blocked |
| P1 | WP-REG-01 — Registration, household, consent, and capacity | Development Agent A + Integration/Platform Developer | Individual/team/dependent registration, guardian web flow, active consent ledger, eligibility, atomic hard capacity. | M3; legal text/policy before pilot | Blocked |
| P1 | WP-ASG-01 — Assignment and waitlist | Integration/Platform Developer + Development Agent B | Constraint-aware plan/preview/confirm, waitlist/state, outbox communication, audit and concurrency. | WP-REG-01 | Blocked |
| P1 | WP-OPS-01 — Event-day operations | Development Agent A + Integration/Platform Developer | Assigned roster, directions, offline attendance, announcements, incidents, Safety Sharing. | WP-ASG-01; notification setup for sends | Blocked |
| P2 | WP-MED-01 — Media pipeline, event feed, and moderation | Integration/Platform Developer + Development Agent B | Short-lived upload, private R2 pipeline, scans/derivatives, immediate authorized member-feed visibility for processed adult uploads, immediate report-hide/review, guardian policy, and separately approved anonymous gallery. | M2–M4; R2 and operating policy before integration | Blocked |
| P2 | WP-ADM-01 — Reporting, privacy, support, retention | Integration/Platform Developer + Development Agent B | Privacy-thresholded aggregates, expiring exports, account requests, tombstones/retention, break-glass support grants. | Completed data-producing workflows; approved policy | Blocked |
| P2 | WP-REL-01 — Hardening, beta, release | Delivery Lead + QA + Auditor + Human Liaison | Accessibility/security/privacy/performance/disaster review, TestFlight, pilot, App Store assets/review, phased rollout and post-deploy verification. | Feature complete; human release actions | Blocked |

## Parallel work now

The current critical path is #5 plus review/acceptance of PR #12. While those proceed:

1. The Architect and database owner can produce #7-A mapping without committing migrations against an unaccepted contract.
2. iOS and web owners can design fixture/type mapping and the web-stack ADR without implementing privileged flows.
3. Automated testing, functional QA, and abuse testing can build traceability matrices and negative cases for tenant escape, retries, stale sessions, malformed input, offline interruption, and accessibility.
4. The Auditor can review PR #12, the Swift prototype, dependency/secret posture, and release blockers independently.
5. The Human Liaison can prepare provider, legal, domain, and App Store actions without requesting ordinary engineering decisions.

## Roadmap maintenance

At every accepted milestone, the Project Manager reconciles FR coverage, current code, tests, documentation, open issues, PRs, and audit findings. Newly discovered UX, failure-state, accessibility, privacy, security, performance, deployment, observability, or documentation gaps become ranked backlog work. No empty issue queue or completed initial assignment is treated as product completion.
