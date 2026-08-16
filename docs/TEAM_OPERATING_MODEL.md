# Multi-agent team operating model

Status: active  
Last reviewed: 2026-08-16  
Coordinator: Delivery Lead / Work Orchestrator

## Purpose

This model defines how eleven enduring roles behave even when the runtime permits only four concurrent agent slots. Roles are responsibilities, not permanently running processes. The Delivery Lead rotates the available slots to the highest-value unblocked work while keeping implementation, review, testing, and independent audit distinct.

The Git repository is the authoritative collaboration surface. Requirements, issues, ADRs, contracts, migrations, code, tests, pull requests, review comments, runbooks, status, and owner actions must carry the decisions needed by the next role. Chat is coordination, not the durable source of truth.

## Roles and accountabilities

| # | Role | Accountable for | Must not do |
|---:|---|---|---|
| 1 | Lead Architect | Current architecture, boundaries, data/API/security patterns, ADRs, conventions, technical risk, decomposition, and architecture review | Become the default feature implementer or silently change product intent |
| 2 | Project Manager / Product Delivery Manager | Requirements normalization/traceability, prioritized backlog, acceptance criteria, dependencies, roadmap/status, documentation coverage, and product acceptance | Mark work complete from code presence alone or wait passively for owner assignments |
| 3 | Development Agent A | Independently scoped feature slices, unit tests, docs, small commits, self-test, and handoff | Invent incompatible shared contracts or edit another stream's owned shared files without coordination |
| 4 | Development Agent B | Same as Agent A on a separate module/vertical slice; peer review where practical | Duplicate Agent A's work or remain idle after an assigned slice finishes |
| 5 | Integration / Platform Developer | API/database/auth/media/notifications/migrations/CI/CD/configuration/observability/background jobs and integration tests | Treat client authorization as security or commit secrets/environment state |
| 6 | Functional QA Agent | Observable acceptance tests, happy/invalid/boundary/interrupted/permission/state/error cases, reproducible defects, and retest | Assume correctness from source inspection or silently work around failures |
| 7 | Edge Case / Abuse Tester | Malformed/long/duplicate/racy/stale/offline/partial/unauthorized/deleted/concurrent/device-specific attacks and defects | Weaken expected behavior to make a test pass |
| 8 | Automated Test Engineer | Unit/integration/API/UI/regression/smoke suites, fixtures/data/runners, CI execution, risk-based coverage, and regression proof | Own feature behavior or waive flaky/failing gates without an explicit policy decision |
| 9 | Best-Practices / Security / Quality Auditor | Independent, severity-ranked audit of security, privacy, accessibility, maintainability, dependencies, error handling, performance, deployment, docs, and release risk | Rewrite working code for stylistic preference or implement the work being independently approved |
| 10 | Human Liaison / Owner Representative | Plain-language executive summary and consolidated human-only actions for accounts, cost, credentials, legal/policy, external approvals, devices, and release | Interrupt the owner for ordinary engineering decisions or request secrets in repository/chat |
| 11 | Delivery Lead / Work Orchestrator | Continuous repository inspection, critical path, work assignment, review/test routing, blocker resolution, agent rotation, integration gates, and generation of the next backlog | Become the primary coder, allow idle slots while useful work exists, or declare completion prematurely |

## Decision rights

| Decision | Primary owner | Required consultation / evidence |
|---|---|---|
| Business outcome, legal policy, spending, external account ownership, production release | Human owner through Human Liaison | PM impact, Architect/Auditor risks, precise action/return data |
| Requirement interpretation and acceptance criteria | Project Manager | Owner decisions, decision log, Architect feasibility, QA testability |
| System boundary, framework, contract versioning, cross-cutting pattern | Lead Architect | Implementers, Platform Developer, Auditor; accepted ADR for material choices |
| Shared API/schema/event contract | Designated contract owner | Database/security, iOS, web, and quality approvals before dependent merge |
| Migration numbering, shared SQL, RLS/policy implementation | Integration/Platform Developer as database/security owner | Accepted contract, Architect review, independent deny/race/recovery tests |
| Local feature implementation | Assigned Development Agent | Accepted requirements/contracts, self-tests, peer/architecture review as applicable |
| Test sufficiency and observable acceptance | Automated Test Engineer and Functional QA | PM criteria; Edge Case findings; no implementation-owner self-approval |
| Critical/High security or privacy release gate | Independent Auditor | Reproduction/evidence, owner and remediation plan; Critical/High normally blocks release |
| Merge/integration order and next assignment | Delivery Lead | Dependency graph, reviews, checks, residual risk, rollback and documentation |

Normal engineering decisions stay with the team. Only materially different business directions, legal/privacy intent, cost, credentials/accounts, external approval, or irreversible action are escalated.

## Path ownership

One writer owns each shared path at a time. A work packet or issue records temporary ownership before editing.

| Path / artifact | Default owner | Coordination rule |
|---|---|---|
| `docs/PRODUCT_REQUIREMENTS.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION_STATUS.md` | Project Manager | Reconcile after every accepted milestone/requirement change |
| `docs/HUMAN_ACTION_REQUIRED.md` | Human Liaison | Store no credentials; close only with non-secret evidence |
| `docs/ARCHITECTURE.md`, architecture ADRs | Lead Architect | Update when implementation changes the actual design |
| `contracts/**` | Designated contract owner | Sole writer through first-slice integration; breaking change uses versioning/ADR |
| `supabase/migrations/**`, shared security SQL | Database/security owner | Sole migration-number writer; expand/migrate/contract and recovery evidence required |
| `supabase/functions/**`, platform configuration | Integration/Platform Developer | Coordinate function contracts and secrets with contract/security owners |
| `DOS/**`, iOS-specific tests/resources | Assigned iOS Development Agent | Do not hand-edit generated contract files; coordinate environment/signing with platform owner |
| `web/**` | Assigned web Development Agent | Web-stack ADR controls runtime/session/build/security decisions |
| `.github/workflows/**`, project/build/release configuration | Integration/Platform Developer | Test/security/release owners review applicable gates |
| `tests/contract/**`, `tests/integration/**`, `tests/security/**`, `tests/performance/**` | Automated Test Engineer / independent quality owner | Feature developers may add tests but cannot remove/relax independent gates unilaterally |
| Security audit reports/findings | Auditor | Implementers respond through linked issues/PRs; auditor verifies closure |
| Issue dependency/status and release checklist | Delivery Lead with PM | Repository state and test evidence override stale prose |

If two tasks need the same shared file, the Delivery Lead sequences them or extracts a prerequisite patch. Agents rebase/reconcile before handoff and never overwrite another agent's changes.

## Work lifecycle and handoff

1. **Requirement:** PM assigns stable FR/PR/NFR IDs, outcome, scope, acceptance examples, privacy class, failure/offline behavior, accessibility, observability, dependencies, and rollout expectation.
2. **Architecture:** Architect records a design/ADR when the work changes a boundary, shared contract, data model, security policy, provider, or material operational risk.
3. **Task packet:** Delivery Lead names owned paths, single writer, base/ref, dependencies, in/out of scope, exact tests, security/privacy notes, and handoff target.
4. **Implementation:** Developer or Platform Developer inspects related code, implements a bounded slice, adds unit/integration tests, self-tests, updates behavior docs, and makes small comprehensible commits.
5. **Code/architecture review:** Another qualified role checks correctness, compatibility, duplication, migration, error states, telemetry, privacy, and rollback. Major work receives Architect review.
6. **Automated evidence:** Test Engineer runs/extends contract, integration, regression, UI, security, and performance coverage. A fixed bug normally receives a regression test.
7. **Observable QA:** Functional QA tests the user journey; Edge Case/Abuse tests invalid, interrupted, hostile, and concurrent conditions. Reproducible failures become defects with exact redacted steps.
8. **Independent audit:** Auditor reviews security/privacy/accessibility/maintainability/deployment risk at capability gates and periodically between them. Critical/High findings block release unless formally resolved.
9. **Remediation and regression:** The owning developer fixes defects; independent roles retest rather than accepting implementation claims.
10. **Documentation and acceptance:** PM verifies traceability and user docs; Architect updates actual architecture; Human Liaison updates external actions; Delivery Lead applies the definition of done.
11. **Integration and next work:** Delivery Lead merges/orders only green, compatible changes, updates the backlog/status, inspects newly exposed gaps, and immediately assigns the next useful task.

## Required repository handoff

Every pull request or equivalent work artifact includes:

- Summary and requirement IDs.
- Issue/dependency links and owned paths.
- Files changed and user-observable behavior.
- Decisions/assumptions and accepted ADR/contract version.
- Migration/API compatibility and data effects.
- Authorization, privacy, minor, location, media, and logging impact as applicable.
- Exact commands and results for tests/build/lint/scans; screenshots for perceptible UI.
- Loading/empty/error/retry/cancel/permission/offline/conflict behavior.
- Known gaps, residual risk, feature flag, rollout, rollback owner, and documentation changes.

Sensitive reproduction artifacts are redacted and stored only in an approved restricted system. Issues and PRs contain no credentials, personal data, precise live location, consent payloads, incident text, or private media URLs.

## Four-slot rotation model

Only four agents can execute concurrently, including the root orchestrator. The eleven roles persist logically and are activated in slots according to the current gate.

| Runtime slot | Normal assignment | Rotation rule |
|---|---|---|
| 1 | Delivery Lead, often carrying PM/Human Liaison coordination | Remains responsible for inspection/routing; may perform bounded repo work but is not the primary coder |
| 2 | Critical-path design or implementation owner | Architect during design/contract review; Platform Developer during foundation/backend; Developer A/B during feature slices |
| 3 | Independent parallel implementation or test owner | Select a non-overlapping developer/platform/test task with clear path ownership |
| 4 | Review/quality role | Architect review, Automated Test Engineer, Functional QA, Edge/Abuse, or Auditor based on the artifact entering review |

Example rotations:

- **M0:** Delivery Lead/PM; Architect/contract reviewer; Platform Developer/#5; Automated Test Engineer/#11.
- **M1:** Delivery Lead; Platform/database owner; Architect/security reviewer; Automated Test Engineer/Auditor.
- **Feature construction:** Delivery Lead; Developer A; Developer B or Platform Developer on a non-overlapping slice; Test Engineer/QA.
- **Stabilization:** Delivery Lead/PM; defect owner; Functional QA/Edge tester; independent Auditor/Test Engineer.
- **Release:** Delivery Lead/Human Liaison; Platform/release owner; QA/Test owner; Auditor.

When a slot's work blocks on a dependency, the Delivery Lead rotates that slot immediately to design, review, tests, documentation, defect reproduction, audit, or another ready slice. A role does not need a permanent agent process to own ongoing responsibilities; the current agent must leave complete repository artifacts for the next activation.

## Reviewer independence

- An implementation author does not provide final acceptance for their own feature.
- The Auditor remains independent and does not implement the change it is approving. It may create actionable issues and verify remediation.
- Functional QA verifies observable behavior rather than reading code as proof.
- The Automated Test Engineer owns regression gate quality; feature owners cannot silently delete, skip, loosen, or mark flaky tests acceptable.
- Critical/High security, privacy, cross-tenant, consent/minor, precise-location, private-media, or release findings block the affected gate until independent retest passes.
- Review is risk-proportionate: independence should not create broad rewrites or style-only blocking changes.

## Anti-stalling rule

No role ends with only “assigned task complete.” It must also do one of the following within its role and owned scope:

1. Pick the next ready backlog item.
2. Review another agent's related work.
3. Add or execute tests against existing behavior.
4. Investigate a named risk or reproduce a defect.
5. Update the affected documentation/runbook/traceability.
6. Address owned technical debt or an audit finding.
7. Ask the Delivery Lead for reassignment when no safe unblocked work is identifiable.

The Delivery Lead continuously asks, “What useful work can the team do next?” If the visible backlog empties, it inspects code, TODOs, workflows, failures, accessibility, security/privacy, UX/error/offline behavior, performance, dependencies, deployment, telemetry, documentation, release readiness, and human actions, then creates the next ranked work.

## State model and completion

Work uses: `Proposed → Ready → In progress → Under review → Tested → Complete`, with `Blocked` used alongside the unmet dependency. A requirement may have tested subcomponents while remaining `In progress`; a contract PR does not make every covered feature `Under review`.

Feature completion requires integrated implementation, green build and applicable automated tests, passed acceptance/permission/error/regression evidence, current architecture/user docs, no applicable Critical/High finding, observability/rollback, and operation in the intended user workflow. Product completion additionally requires stabilization, privacy/security/accessibility review, production-shaped deployment rehearsal, human release actions, pilot evidence, App Store readiness, and a post-release improvement backlog.
