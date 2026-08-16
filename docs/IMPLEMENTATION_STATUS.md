# Day of Service implementation status

Snapshot: 2026-08-16  
Repository: `grandpajoe1980/DOS`  
Default branch: `main` at `1c2a95286d2d4692b3ebdf47247b0bac0ff44a87`

## Executive summary

The project is a documented and unit-tested Swift prototype, not yet a deployable application. `main` contains the complete engineering handoff, iOS discovery/registration UI wired to a preview service, an HTTP client protocol, an offline attendance queue, domain models for authorization/allocation/media/Safety Sharing, and 11 Swift unit tests reported passing in merged PR #4.

The first production boundary is now in draft PR #12: a versioned v1 OpenAPI/realtime contract package with validators and fixtures. It is under review and is not yet authoritative on `main`. The other immediate P0 is issue #5, because the repository has no Xcode project, CI workflow, status checks, contract-compatibility gate, or independent test execution.

There is no database, RLS, authentication integration, hosted API, organizer web application, media pipeline, notification provider, deployment configuration, observability stack, or release configuration. No functional requirement is complete end to end.

## Repository and delivery state

| Item | Evidence | State |
|---|---|---|
| Product/engineering handoff | `documents/README.md` and `documents/01`–`15`; merged PR #1 | Complete as baseline; living docs still required |
| Architecture notes | `docs/ARCHITECTURE.md` plus system handoff | Implemented prototype described; current architecture review in progress |
| Swift package | `Package.swift`, `DOSCore`, three test files | Present on `main` |
| Native app project | No `DOS.xcodeproj`, asset catalog, schemes, or environment configuration | Missing; #5 ready |
| CI / required checks | No `.github/workflows/**`; no checks on `main` | Missing; release blocker |
| Shared contracts | Draft PR #12 on `agent/define-v1-contracts`; OpenAPI, realtime schema, fixtures, validator, ADR | Under review; #6 not complete |
| Backend | No `supabase/**`, migrations, functions, seed, or RLS tests | Missing; #7 blocked on accepted contract/CI |
| iOS runtime integration | Preview service is the default; no auth, secure storage, environment selection, realtime, or production cache | Prototype only; #8 blocked |
| Web | No `web/**` or web-stack ADR on `main` | Missing; #9 blocked |
| Identity/tenancy | Swift advisory authorization helper only | Server enforcement absent; #10 blocked |
| Independent quality harness | Unit tests only; no contract/integration/security/performance/UI test implementation | Missing; #11 can start with #5/#6 |
| Repository visibility | GitHub reports `public`; MIT license on `main` | Owner review required before operational/configuration material |

## Implemented prototype capabilities

| Capability | Current evidence | What is not yet implemented | State |
|---|---|---|---|
| Event discovery/detail | `EventOccurrence`, `ServiceSite`, `PreviewEventService`, Discover/detail SwiftUI with loading/empty/retry and non-precise location copy | Hosted public query, publish/privacy enforcement, pagination, web surface, cache/realtime, UI/accessibility automation | In progress |
| Adult registration | `RegistrationRequest`, form, `RegistrationValidator`, API registration call, team-mode choices | Authentication, multiple participant/dependent UI, authoritative server validation, active evidence ledger, atomic capacity, persisted status | In progress |
| Consent precheck | Client checks required document IDs and UI describes separate guardian consent | Attributable per-participant/version/hash/signer evidence, guardian web authentication, revoke/supersede history | In progress |
| Assignment planning | Deterministic `AssignmentAllocator` handles eligible sites, whole candidate count, hard limits, soft-target ranking; unit test | Accessibility/shift-overlap logic, authoritative transaction, planner UI, fairness analysis, confirmation/waitlist/audit/notification | In progress |
| Authorization model | Tenant/site-scoped `AuthorizationContext` and unit denial cases | Authentication, membership/session lifecycle, server policy and RLS. Client helper is not a security boundary. | In progress |
| Offline attendance | Actor queue deduplicates stable operation IDs, persists via injected callback, and reconciles; unit tests | Encrypted production persistence, scan/manual UI, canonical conflict feedback, server idempotency/RLS, corruption/reconnect/UI tests | In progress |
| API client | Public occurrences, registration, and attendance endpoints; ISO-8601, idempotency, basic status mapping, slug encoding | Authentication headers/refresh, full v1 mapping, error envelope/field pointers/request IDs/pagination/versioning, retry policy, telemetry | In progress |
| Media lifecycle | Local adult-only approval-first transition model with required moderation reasons; unit test | It does not match the full owner policy: processed adult uploads should appear immediately in an authorized event/group feed, reports should hide immediately pending review, and anonymous public-gallery approval must remain separate. Upload authorization, R2, processing, feed authorization, guardian policy, takedown/cache expiry, and gallery are absent. | In progress |
| Safety Sharing | Local recipient/site/occurrence/expiry/manual-stop state model; unit test | Explicit activation UI, maximum duration, server policy/RLS, location delivery/redaction, expiry job, offline and retention behavior | In progress |
| App surfaces | Discover, event detail, registration, My Day placeholder, Profile placeholder | Checked-in Xcode project, runtime service injection, auth/account, assignments, operations, media, permission/offline/conflict states, UI tests | In progress |

## Functional-requirement rollup

The detailed mapping, planned implementation, and required tests are in `docs/PRODUCT_REQUIREMENTS.md`.

| Status | Count | Requirements |
|---|---:|---|
| In progress (partial prototype only) | 11 | FR-002, FR-102–FR-104, FR-106, FR-201–FR-202, FR-205, FR-302–FR-304 |
| Blocked on foundation/contracts/backend or later workflow | 11 | FR-001, FR-003–FR-004, FR-101, FR-105, FR-203–FR-204, FR-206, FR-301, FR-305, FR-401 |
| Under review as a full feature | 0 | None; PR #12 is contract support, not feature completion |
| Tested end to end | 0 | None |
| Complete | 0 | None |

## GitHub work ledger

| Issue / PR | Scope | Dependencies | Current state | Next gate |
|---|---|---|---|---|
| #3 | v0.1 orchestration board | None | In progress | Keep child state, dependencies, and evidence current |
| #5 | Xcode project, CI, repository quality gates | None | Ready | Assign platform owner; require SwiftPM, simulator, contract, secret/dependency/static checks |
| #6 / draft PR #12 | Versioned v1 schema/API/realtime contracts and fixtures | None | Under review | Database/security, iOS, web, and quality review; CI validation; compatibility evidence; reconcile PG-001 member-feed/report-hide/public-gallery semantics; mark ADR accepted |
| #7 | Supabase/PostGIS schema, migrations, RLS, seed, functions/tests | Accepted relevant #6 contract; #5 runner | Blocked (design can begin) | Produce contract-to-table/policy/RLS map, then implement after contract acceptance |
| #8 | Deployable iOS application shell | #5 and accepted #6 | Blocked (design can begin) | Define fixture/type mapping, DI, secure cache/token, navigation/flag and UI test plan |
| #9 | Web-stack ADR and public/organizer scaffold | #5 and accepted #6 | Blocked (ADR can begin) | Accept ADR, then scaffold shared-fixture routes/build/accessibility checks |
| #10 | Authentication, profiles, organizations, roles | #5, #6, and tenant controls from #7 | Blocked | Prepare provider/env documentation; implement only on server-derived roles and RLS |
| #11 | Independent contract/RLS/offline/accessibility/security harnesses | #5; grows with #6–#10 | Ready to start planning/skeleton | Add negative matrix, known-defect proofs, commands, duration, ownership, flaky-test policy |

## Pull requests and branches

- PR #1, #2, and #4 are merged into `main`.
- Draft PR #12 is the only observed open PR and is mergeable at the snapshot, but its required cross-discipline reviews and CI gate are not yet evidenced.
- `agent/define-v1-contracts` contains PR #12 work.
- The three earlier `codex/*` branches contain no work ahead of `main` and are historical.

## Test evidence and limitations

- Merged PR #4 reported `swift test` passing all 11 tests: four registration-validator tests, two offline-queue tests, and five documented-feature model tests.
- Current unit coverage proves selected pure/local behavior only. It does not prove database authorization, tenant isolation, live API compatibility, secure offline storage, UI accessibility, web behavior, concurrency under authoritative persistence, uploads, notifications, or release readiness.
- There is no repository CI to rerun those tests on each change, and no checked-in Xcode project to execute simulator/UI tests.
- Draft PR #12 reports its local validator passed OpenAPI, realtime schema, and listed fixture checks. This evidence must be reproduced by #5 CI and expanded by #11 compatibility/negative tests before acceptance.

## Highest risks and gaps

1. **Release-blocking foundation:** without #5, every result depends on manual/local claims and the app cannot be clean-clone built for iOS.
2. **Security boundary absent:** local Swift authorization/validation is not server enforcement; #7 RLS and policy functions are the next critical gate after contract acceptance.
3. **Contract breadth versus fixture depth:** PR #12 describes all requirement families but currently lists only representative fixtures. Issue #6 calls for valid/invalid fixtures for every first-slice request/response and explicit race/authorization/unknown-enum examples; reviewers must reconcile this before completion.
4. **Consent/minor risk:** the current request model's document-ID list and participant names do not satisfy attributable guardian/participant/version evidence.
5. **Event-day durability:** offline queue persistence is injected but not encrypted, device-backed, corrupt-data tolerant, or integrated with UI/server conflict semantics.
6. **Media model conflicts with the approved feed rule:** current code assumes approval before publication and has no separate member-feed/gallery visibility. The owner requires immediate member-feed visibility after processing for adult uploads, immediate hide-on-report pending review, no minor uploads, and separate approval for the anonymous public gallery. The contract/state model must be reconciled before WP-MED-01 implementation; no private object boundary, processing pipeline, guardian enforcement, or takedown exists yet.
7. **No independent QA/audit evidence:** accessibility, abuse, privacy, performance, migration, disaster recovery, and deployment behavior remain unverified.
8. **Public repository posture:** provider/project details, operational playbooks, or accidentally committed secrets would have immediate exposure unless governance is confirmed and automated scanning is added.

## Immediate next decisions by the delivery organization

No ordinary engineering choice needs owner intervention. The team should: review PR #12, start #5, design #7's RLS map, draft the web ADR and iOS fixture mapping, and begin #11 test matrices in parallel. Human-owned account, legal, domain, and release actions are tracked separately in `docs/HUMAN_ACTION_REQUIRED.md`.
