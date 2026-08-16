# Day of Service release checklist

Status: living staged-release gate. No current commit is a release candidate.

Release owner: unassigned  
Candidate commit/tag: unassigned  
Build/version: unassigned  
Target environment/date: unassigned  
Rollback owner: unassigned

## How to use this checklist

Every checked item must link to durable evidence for the exact candidate commit and target environment. “Implemented,” a screenshot, or a passing preview service is not sufficient evidence. Mark non-applicable items with an approver and reason; do not delete them.

Release is blocked by:

- any unresolved Critical or High defect/security/privacy finding;
- any cross-tenant, guardian/minor, consent, hard-capacity, private-media, precise-location, account-deletion, or signing/privacy-disclosure failure;
- a failed or flaky critical-journey gate;
- missing migration/restore/rollback evidence;
- behavior that differs materially from the privacy policy, App Privacy answers, review notes, or support commitments.

A feature behind a flag does not block only if server access is deny-by-default, production configuration proves it off, no user/reviewer path exposes it, and removal/rollback is tested.

## Gate 0 — repository and requirement readiness

- [ ] Candidate is a reviewed commit on a protected branch; working tree and generated artifacts are reproducible.
- [ ] `PRODUCT_REQUIREMENTS.md`, `ARCHITECTURE.md`, ADRs, `ROADMAP.md`, and `IMPLEMENTATION_STATUS.md` match implemented behavior.
- [ ] Every in-scope FR has implementation, acceptance criteria, trace-linked automated tests, and owner.
- [ ] Out-of-scope or deferred work is inaccessible, documented, and not implied by UI/store copy.
- [ ] API/schema/event changes are versioned, compatible through the supported upgrade window, and represented by valid/invalid fixtures.
- [ ] No unresolved TODO/FIXME, disabled assertion, skipped critical test, debug endpoint, preview service, mock credential, or sample data is reachable in Release configuration.
- [ ] Dependency licenses and third-party terms are compatible; SBOM is archived.
- [ ] Release notes list user-visible changes, known limitations, support impact, migration, and rollback.

Evidence:

- [ ] Requirement-to-test matrix:
- [ ] Candidate diff/review approvals:
- [ ] SBOM/license report:

## Gate 1 — build, static checks, and automated tests

- [ ] Pinned toolchain/version is recorded and clean checkout builds without local state.
- [ ] `swift test --parallel` passes.
- [ ] AddressSanitizer and ThreadSanitizer jobs pass separately on supported hosts.
- [ ] Contract/schema validation passes.
- [ ] iOS Debug build and unit tests pass on the pinned simulator.
- [ ] UI smoke and full regression suites pass with `.xcresult` artifacts.
- [ ] Database migrations, constraints, and complete RLS allow/deny matrix pass.
- [ ] API, web, worker, object-storage, notification, export, deletion, and retention integration tests pass as applicable.
- [ ] Secret, SAST, dependency, IaC, and artifact scans pass or have approved non-High findings.
- [ ] No flaky critical tests; any quarantine has issue, owner, expiration, and deterministic substitute.
- [ ] Coverage report identifies untested high-risk code; thresholds are not gamed with generated/trivial code.

Evidence:

- [ ] CI run URL/artifact manifest:
- [ ] Test result bundles/reports:
- [ ] RLS/contract/security scan reports:

## Gate 2 — security and privacy

- [ ] Threat model and risk register reflect the candidate architecture and data flows.
- [ ] Every tenant-owned table, view, RPC, storage object, realtime channel, export, and job has tenant/resource authorization tests.
- [ ] Anonymous and each role are denied by default; suspension/role removal/support expiry revokes access within the documented maximum.
- [ ] Auth provider callback, PKCE/state/nonce, token refresh/revocation, account switch, invitation, last-owner, and privilege-escalation tests pass.
- [ ] Secrets are absent from repository, app bundle, source maps, logs, crash reports, artifacts, screenshots, and public configuration.
- [ ] TLS/host/callback/CORS/CSRF/security-header and safe-error behavior is verified.
- [ ] Idempotency, optimistic concurrency, database atomicity, webhook replay, outbox dedupe, and job redelivery tests pass.
- [ ] Consent evidence is immutable, attributable, versioned, tenant/participant bound, and active-version checked server-side.
- [ ] Guardian authority cannot be gained through team/staff/contact association; minor-prohibited actions fail at API/RLS/storage boundaries.
- [ ] Public responses and caches expose no precise location, private arrival note/address, roster/contact, minor, incident, consent, storage key, or original media.
- [ ] Media uses private bounded upload, byte/MIME/checksum validation, isolated processing, EXIF/GPS stripping, and derivative-only delivery.
- [ ] A successfully processed adult upload becomes visible without preapproval only in the authenticated event-member feed; nonmembers/anonymous/other events/tenants are denied, minors cannot upload, and unreported items remain visible.
- [ ] A report atomically hides/quarantines the item from the event-member feed pending review; restore/remove is audited, and anonymous public-gallery publication is a separate approval state.
- [ ] Safety Sharing is voluntary, adult-only, scoped, visible, manually stoppable, and server-expired without movement history.
- [ ] Logging/analytics/crash redaction tests pass; production access is JIT/MFA/reasoned/audited.
- [ ] Account export/deletion, retention expiry, processor cleanup, tombstones, and backup-restoration behavior are tested and accurately disclosed.
- [ ] Independent security review/penetration test has no unresolved Critical/High finding.

Evidence:

- [ ] Security approval and risk acceptance record:
- [ ] Privacy/legal approval and data inventory:
- [ ] Penetration/abuse report:

## Gate 3 — functional and adversarial acceptance

- [ ] Public discovery returns only published allowlisted information and handles loading/empty/error/retry/offline states.
- [ ] Authentication/session and organization selection work across cancellation, expiry, offline, and account switching.
- [ ] Adult individual/team registration preserves input, validates active documents, and survives repeated submit/lost response without duplicates.
- [ ] Guardian creates a named dependent and supplies separate active-version evidence without granting peers/staff guardian rights.
- [ ] Concurrent registration/assignment cannot exceed a hard limit; soft target behavior, waitlist, stale versions, and notification are correct.
- [ ] Site leads see only current assigned rosters and can check in/out manually/scan with offline queue, restart, conflict, and reconciliation.
- [ ] Directions work without location permission and use the event/site IANA time zone and a non-map alternative.
- [ ] Announcements hide recipient lists and respect authorization, dedupe, quiet hours, opt-out category, and emergency path.
- [ ] Incident access, attachments, audit, retention, and exclusion from normal analytics/export are verified.
- [ ] Adult media upload, processing, automatic event-member feed visibility, unreported persistence, immediate report quarantine, moderator restore/remove, separate anonymous-gallery approval, guardian visibility, takedown, and retention flows pass; minor upload fails at every boundary.
- [ ] Impact totals/exports are accurate, authorized, suppression-safe, formula-injection safe, expiring, and auditable.
- [ ] Account access/correction/export/deletion and support escalation are complete end to end.
- [ ] All reproducible release-scope defects have regression tests and have been independently retested.

Evidence:

- [ ] Functional QA report:
- [ ] Edge/abuse QA report:
- [ ] Regression report:

## Gate 4 — accessibility, compatibility, and usability

- [ ] Critical iOS journeys pass on smallest supported and current large-screen iPhones, oldest supported iOS 17.x, and current production iOS; at least the oldest/current matrix is tested on physical devices.
- [ ] VoiceOver order/names/values/hints/focus/live updates and rotor headings pass for every critical flow.
- [ ] Dynamic Type through the largest accessibility size, Bold Text, increased contrast, dark mode, Button Shapes, Reduce Motion, and differentiate-without-color pass.
- [ ] Orientation, safe areas, keyboard appearance, interrupted/backgrounded tasks, low memory/storage, and permission denial/revocation behave safely.
- [ ] Web critical flows pass keyboard-only, visible focus, screen-reader semantics, 200%/400% zoom and 320 CSS-pixel reflow on supported Safari/Chrome/Firefox.
- [ ] Text, touch targets, contrast, form labels/errors, status announcements, non-map alternatives, and plain-language recovery meet WCAG 2.2 AA/product requirements.
- [ ] Dates/times are correct across device zones, IANA event zones, DST gap/fold, locale, 12/24-hour settings, and year boundaries.
- [ ] User testing with organizers, volunteers, site leads, and accessibility participants has actionable findings resolved or owned.

Evidence:

- [ ] Device/browser/accessibility matrix:
- [ ] Manual VoiceOver/keyboard report:
- [ ] Usability/pilot findings:

## Gate 5 — performance, operations, and recovery

- [ ] Approved SLOs/error budgets exist for availability, registration/check-in latency, job completion, moderation/takedown, and crash-free sessions.
- [ ] Production-shaped burst/load tests pass with p50/p95/p99, errors, saturation, and correctness invariants reported.
- [ ] Database capacity/connection limits, indexes/query plans, queue backpressure, provider quotas, object/CDN limits, and cost alerts are reviewed.
- [ ] Metrics, traces, redacted logs, dashboards, synthetic probes, and actionable alerts exist for every critical dependency and journey.
- [ ] On-call ownership, support runbook, incident severity, child-safety/media/location escalation, provider failure, and status communication are rehearsed.
- [ ] Forward migration and production-shaped restore/recovery rehearsal pass; recovery time and data-loss objectives are recorded.
- [ ] Feature flags have owner, purpose, safe default, expiry, telemetry, and tested rollback.
- [ ] Server/client compatibility and forced/minimum upgrade behavior are tested across the supported window.
- [ ] Degraded/offline behavior is clear and does not claim success before durable commit.

Evidence:

- [ ] Load/performance report:
- [ ] Dashboard/alert and synthetic-probe links:
- [ ] Migration/restore/rollback rehearsal:

## Gate 6 — Apple/App Store and production configuration

- [ ] Apple Developer team, bundle ID, capabilities, signing certificates, provisioning, App Store Connect record, and least-privileged access are correct.
- [ ] Release archive uses the intended scheme/configuration, contains no preview/mock endpoints, and has reproducible version/build numbers and dSYMs.
- [ ] Development, staging, and production endpoints/projects/buckets/callbacks/keys are separate; production uses publishable client configuration only.
- [ ] `Info.plist` permission strings are specific, contextual, and present only for used capabilities.
- [ ] Privacy manifests and required-reason API declarations cover app and SDK behavior.
- [ ] App Privacy answers, age rating, export compliance, UGC/moderation answers, and encryption statements are accurate.
- [ ] Sign in with Apple is available when required by the configured equivalent login options.
- [ ] In-app account deletion initiates deletion without requiring a support-only path.
- [ ] Live privacy policy and support URLs match the candidate; report/block/support contact is reachable.
- [ ] Store metadata, screenshots, preview, localization, and accessibility claims match behavior and contain no real personal data.
- [ ] Review notes and dedicated synthetic demo accounts make every gated role/flow testable without revealing production data.
- [ ] Terms, waiver, guardian/child privacy, retention, safety, and jurisdiction language have recorded legal approval.

Evidence:

- [ ] Archive validation/signing report:
- [ ] App Store Connect/privacy-manifest review:
- [ ] Live policy/support URLs and legal approval:

## Gate 7 — internal alpha

Entry: Gates 0–3 pass for enabled slices; no Critical/High; synthetic data only.

- [ ] Limited named internal users and devices; production credentials/data are not used.
- [ ] Crash/error/feedback collection is redacted and monitored daily.
- [ ] Rollback/disable path and support owner are on call.
- [ ] Alpha exit criteria, defects, and newly discovered tests are recorded.

Decision: [ ] Go  [ ] No-go  
Approvers/evidence:

## Gate 8 — TestFlight beta and organizer pilot

Entry: Gates 0–6 pass; staging is production-shaped; privacy/legal/security approve beta data handling.

- [ ] Internal TestFlight first, then a bounded external cohort with explicit feedback/support instructions.
- [ ] Pilot organizations, events, roles, devices, accessibility participants, and data-handling expectations are documented.
- [ ] Server/client dashboards, crash-free sessions, latency, notification, moderation, and support volume are reviewed at least daily.
- [ ] Stop thresholds include security/privacy incident, tenant isolation anomaly, guardian/minor failure, data loss/corruption, safety-cap violation, or critical-journey regression.
- [ ] Beta feedback is triaged by severity; fixed bugs receive regression tests and retest.
- [ ] Beta exit report shows objectives, metrics, defects, residual risk, and production recommendation.

Decision: [ ] Go  [ ] No-go  
Approvers/evidence:

## Gate 9 — App Store submission

Entry: all applicable Gates 0–8 pass for the exact archive; no unresolved Critical/High.

- [ ] Release candidate is frozen except for reviewed release fixes; any code/config change restarts affected gates.
- [ ] App Store validation/upload succeeds and uploaded build checksum/version matches release record.
- [ ] Reviewer demo accounts/data, notes, contacts, and backend environment remain available throughout review.
- [ ] Rejection/clarification owner and response plan are assigned.
- [ ] Production database/API/media/jobs are deployed compatibly but dormant or safely backward compatible until rollout.

Decision: [ ] Submit  [ ] Hold  
Approvers/evidence:

## Gate 10 — phased production rollout

Entry: Apple approval, final change review, production readiness approval, and rollback rehearsal complete.

- [ ] Backup/restore point and migration checkpoint confirmed immediately before change.
- [ ] Deploy backend/schema with compatibility monitoring before enabling dependent clients/features.
- [ ] Start with the smallest practical cohort/flag percentage; do not auto-expand without a health review.
- [ ] At each phase review security events, tenant authorization anomalies, correctness reconciliations, crash-free sessions, API p95/p99/errors, database/queue saturation, notifications, moderation/takedown, deletion/export, and support volume.
- [ ] Stop/rollback thresholds and authorized decision maker are explicit; rollback includes schema/data/job/client compatibility.
- [ ] Public status/support teams receive accurate release and known-issue information.
- [ ] Final expansion is approved only after the observation window meets SLOs and has no unexplained anomalies.

Phase plan: [ ] 1%/internal production  [ ] 10%  [ ] 25%  [ ] 50%  [ ] 100% (adjust to actual platform controls)  
Decision/approvers/evidence:

## Gate 11 — post-release verification and improvement

- [ ] Synthetic probes and canonical data reconciliation pass after each deployment/phase.
- [ ] Release owner confirms dashboards, alerts, jobs, backups, CDN/media access, notification callbacks, and account-request queues.
- [ ] Privacy/security/support review finds no undisclosed behavior or sensitive telemetry.
- [ ] Review store/user/support feedback for confusion, accessibility, failure recovery, and abuse patterns.
- [ ] Conduct a 24-hour and 7-day review; assign every follow-up with severity, owner, and date.
- [ ] Close the release only after evidence is archived and documentation/status/roadmap reflect reality.

## Final sign-off

- [ ] Product/Delivery
- [ ] Lead Architect
- [ ] Engineering/Integration
- [ ] Automated Test Engineering
- [ ] Functional QA
- [ ] Edge/Abuse QA
- [ ] Security/Privacy
- [ ] Accessibility
- [ ] Operations/Support
- [ ] Legal/Policy where applicable
- [ ] Human owner/release authority

Final decision: [ ] Go  [ ] No-go  
Decision time and rationale:  
Residual risks with owner/date:  
Rollback authority and trigger:  
