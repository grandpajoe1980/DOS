# Human action required

Owner liaison: Human Liaison / Owner Representative  
Last reviewed: 2026-08-16

## Executive summary

Development can continue now on contracts, CI, local database policy, app architecture, test planning, and non-production scaffolds. No credential or account action is required to continue that local work.

The owner will eventually need to establish the legal/account ownership, public domain, cloud projects, identity providers, operating policy, and Apple release path. The earliest external blocker is live identity/staging integration in M1–M2; the largest lead-time item is Apple Developer organization enrollment. Never send passwords, private keys, client secrets, certificates, provisioning profiles, or recovery codes through issues, pull requests, chat, or source control.

## Action register

| ID | Human-only action | Needed by | Can development continue without it? | State |
|---|---|---|---|---|
| HAR-001 | Confirm repository ownership, visibility, and open-source posture | Before infrastructure/operational details are added | Yes, with synthetic data and no secrets | Action required now |
| HAR-002 | Enroll the intended legal publisher in the Apple Developer Program and delegate access | Before live Sign in with Apple/TestFlight; start during M0 because verification can take time | Yes for local/simulator work | Action required soon |
| HAR-003 | Select the official domain, support mailbox, and organization-facing brand identity | Before OAuth verification, public web hosting, privacy/support URLs, and App Store record | Yes for local work | Action required before M2 |
| HAR-004 | Create owner-controlled Supabase and Cloudflare accounts/projects and approve billing | Before hosted M1/M2 integration and media pipeline | Yes for local Supabase/contracts; no for hosted integration | Action required before hosted staging |
| HAR-005 | Configure Apple and Google identity-provider applications | Before #10 live identity acceptance | Yes for mocked/local identity interfaces | Blocked on HAR-002/HAR-003 and deployed callbacks |
| HAR-006 | Approve legal/privacy/retention/minor/media/incident policies and obtain counsel review | Before real-user pilot and production data collection | Yes behind non-production flags with synthetic data | Action required before pilot |
| HAR-007 | Create and complete the App Store Connect app record and release declarations | Before external TestFlight/App Review | Yes until release preparation | Action required in M8 |
| HAR-008 | Provide physical-device and organizer/volunteer pilot participation | Before beta acceptance and phased release | Yes until beta | Action required in M8 |

## HAR-001 — Repository ownership and visibility

**What:** Decide whether `grandpajoe1980/DOS` is intentionally public under the existing MIT license or should become private while the product and operating model are developed.

**Why:** GitHub currently reports the repository as public. Public source is compatible with this product only if all operational data, provider identifiers that should remain internal, incident playbooks, and secrets remain elsewhere. A visibility change is an owner/governance decision.

**When:** Now, before cloud project details, deployment runbooks, or real organization/pilot data are added.

**Steps:**

1. Confirm who owns the product/IP and who is authorized to accept licenses and provider terms.
2. Review the MIT license and decide whether public redistribution is intended.
3. In GitHub, open **Settings → General → Danger Zone → Change repository visibility** if the repository should be private. Read GitHub's stated effects before confirming.
4. In either case, require two-factor authentication for collaborators, use least-privileged repository roles, and enable secret/dependency scanning when #5 adds the automated gates.
5. Enable GitHub's dependency graph and applicable Dependabot alerts/security updates, then add repository Actions variable `DEPENDENCY_GRAPH_ENABLED=true`; verify the pinned dependency-review gate runs and rejects a temporary High-severity dependency change as tracked in #18.
6. Immediately after PR #12 is integrated, add repository Actions variable `CONTRACTS_REQUIRED=true` and prove that deleting the contract validator fails CI as tracked in #22.
7. Do not commit cloud credentials, Apple signing material, real participant records, real incidents, waiver signatures, precise live location, or private media.

**Return to the team:** `Public/MIT approved` or `Private`; legal product owner name; names/GitHub handles authorized to approve security, release, and policy changes. Do not return credentials.

**Can work continue?** Yes. Use only synthetic fixtures and avoid operational/provider-sensitive material until confirmed.

## HAR-002 — Apple Developer Program and team access

**What:** Enroll the legal publisher and grant the minimum team roles needed for development and release.

**Why:** An owner-controlled membership is needed for device signing, Sign in with Apple configuration, TestFlight, App Store Connect, agreements, and production distribution. Apple's current enrollment page states that organization enrollment requires legal authority, a legal entity, a work email/domain, a functional public website, and normally a D-U-N-S number; government entities are treated differently. The listed program price is currently USD 99 per membership year, with possible fee waivers for qualifying nonprofits, educational institutions, and government entities.

**When:** Start during M0. It must be complete before #10 integrates Sign in with Apple and before external TestFlight.

**Steps:**

1. Decide the App Store seller/legal entity. Do not enroll under an individual if an organization should own the app.
2. Prepare an Apple Account using the authorized person's legal name, organization email, and two-factor authentication.
3. Gather the legal entity name, public website/domain, business address/phone, legal-authority confirmation, and D-U-N-S number if Apple requires one.
4. Follow [Apple Developer Program enrollment](https://developer.apple.com/programs/enroll/), accept the agreement, and complete payment or an eligible fee-waiver request.
5. After approval, the Account Holder/Admin should use [Apple's team invitation steps](https://developer.apple.com/help/account/access/invite-team-members/) to invite named staff as Developer or Admin only as required. Do not share the Account Holder login.
6. Keep agreement acceptance, membership renewal, and Account Holder succession owned by the organization.

**Return to the team:** Legal seller name; Apple Team ID; membership state/renewal owner; invited team-member names and roles; whether automatic signing is permitted. Do not return certificates, keys, passwords, or recovery codes.

**Can work continue?** Yes for local/simulator development. Live Apple identity, device signing, TestFlight, and App Store release remain blocked.

## HAR-003 — Domain, support contact, and brand identity

**What:** Provide the official product/domain identity used for public web, OAuth, privacy, support, and App Store metadata.

**Why:** Apple organization enrollment and OAuth verification expect a functional organization-associated website. The product also requires reachable privacy/report/support channels.

**When:** Before M2 live identity configuration and before production web/App Store records.

**Steps:**

1. Choose and register/assign an organization-controlled domain.
2. Choose the user-facing app name and confirm who may approve branding and public copy.
3. Create monitored mailboxes or aliases for user support, privacy/data requests, security reports, and media/abuse reports. Document response ownership and coverage; do not publish personal addresses.
4. Choose intended public hosts, for example `www`, `app`, and `api`, but let the Architect finalize technical hostnames.
5. Arrange owner-controlled DNS access with MFA and named backups. Do not share registrar credentials; make the required DNS changes when provided as reviewed records.

**Return to the team:** Approved app/display name, legal organization name, domain, public support/privacy/security/report email addresses, and DNS change approver. No login credentials.

**Can work continue?** Yes with placeholder/example domains. OAuth verification and production links cannot finish.

## HAR-004 — Supabase and Cloudflare R2 ownership/billing

**What:** Create organization-owned provider accounts and separated non-production/production projects when the platform plan is approved.

**Why:** The selected architecture uses Supabase Auth/PostgreSQL/PostGIS and Cloudflare R2. Account ownership, billing, recovery, MFA, access delegation, and data-processing terms require human authority and may create cost.

**When:** A local Supabase implementation can begin in M1. Create hosted development/staging before M1 integration; create production only after architecture/security review and budget approval. R2 is required before WP-MED-01 integration.

**Steps:**

1. Choose an organization-controlled billing owner and backup administrator for each provider.
2. Create an organization/team rather than a developer's personal long-term project; enable MFA and least-privileged invitations.
3. Review current pricing, regions/data residency, backups, support, logging, egress, retention, and data-processing terms. Approve a budget/alert threshold before enabling paid use.
4. Create separate development, staging, and production projects/buckets only according to the accepted environment design. Never reuse credentials or buckets across environments.
5. Configure values directly in the provider and approved CI/hosting secret stores. Commit only `.env.example` names and publishable values explicitly approved for clients.
6. Enable billing/usage alerts and name the person who responds to cost or service alerts.

**Return to the team:** Provider organization names; non-secret project references/URLs; chosen regions; names of configured CI secret variables (not values); access/billing owners; budget/alert limits; confirmation that development/staging are ready. Share any required secret value only through the approved secret manager, never in GitHub/chat.

**Can work continue?** Yes locally. Hosted identity/database/media integration is blocked until the corresponding environment exists.

## HAR-005 — Apple and Google sign-in configuration

**What:** Authorize and configure production-owned Apple and Google identity applications after callback URLs and bundle identifiers are accepted.

**Why:** Provider console terms, verified domains, consent branding, keys/secrets, and account ownership require human-controlled accounts. Sign in with Apple is part of the approved login design and may be required when another third-party login is offered.

**When:** During #10 after HAR-002/HAR-003 and the Architect supplies reviewed bundle IDs, service IDs, origins, and callback URLs.

**Steps:**

1. Apple Account Holder/Admin registers the approved App ID/bundle identifier and enables Sign in with Apple; register the web Service ID/domain/return URL if required by the final web/session design.
2. Generate provider keys/secrets only when requested by the integration owner. Put them directly in the approved server secret store and record rotation/expiry ownership; never download/share them casually.
3. In an organization-owned Google Cloud project, configure the [Google Auth Platform branding](https://support.google.com/cloud/answer/15549049), support/privacy links, audience, verified domains, and the exact reviewed iOS/web client types and redirect URIs.
4. Submit provider verification if required; request only identity scopes approved in the contract.
5. Add test accounts through provider-supported mechanisms and test cancellation/failure without supplying personal credentials to developers.

**Return to the team:** Apple Team ID, bundle/App/Service IDs, Google project/client IDs, approved domains/callbacks, verification state, and confirmation that secrets are configured under the named secret variables. No private keys or client secrets.

**Can work continue?** Interfaces and mocked tests can. Live provider acceptance cannot.

## HAR-006 — Legal, privacy, child-safety, media, retention, and operating policy

**What:** Approve the real-world policies and legal text that the software must enforce.

**Why:** The product records waiver/guardian evidence, handles minors, optional precise location, incident information, user-generated media, and account/privacy requests. The repository explicitly requires legal counsel approval for waiver, guardian, child-privacy, retention, and jurisdiction-specific language.

**When:** Policy data models and test fixtures can be built now. Final text and operating ownership must be approved before a real-user pilot, and before a feature collecting that data is enabled.

**Steps:**

1. Engage qualified counsel for intended jurisdictions and organization types; identify the legal entity/data controller.
2. Approve versioned waiver and guardian-consent text, signer/relationship attestation, age/eligibility data, revocation/supersession, and record-retention rules.
3. Treat the accepted member event-feed rule as fixed product behavior: adult uploads become visible to authorized event/group members after successful upload validation/processing without platform preapproval; minors cannot upload; a report immediately hides the item pending review. With counsel and the operating owner, approve the distinct anonymous public-gallery eligibility criteria and moderation procedure.
4. Define retention/deletion/legal-hold periods for accounts, consent, audit, incident, precise Safety Sharing samples, media originals/derivatives/metadata, reports, exports, logs, backups, and tombstones. Confirm whether retained upload metadata/geodata has a defined necessity, access scope, and deletion period.
5. Name trained owners and response targets for media reports, child-safety escalation, threats/imminent danger, incidents, privacy/data requests, security reports, and production support.
6. Approve privacy notice, terms, support/reporting contact, acceptable-use/community rules, and processor/subprocessor disclosures.

**Return to the team:** Approved versioned documents or stable source links; effective dates/locales; required acceptance rules; retention matrix; named operational owners/escalation windows; jurisdictions; counsel sign-off reference. Do not return real participant data.

**Can work continue?** Yes with synthetic text and disabled feature flags. Real-user collection/publication cannot begin.

## HAR-007 — App Store Connect and release declarations

**What:** Create the app record and complete human/legal product metadata and declarations for beta/release.

**Why:** Apple requires a privacy policy URL and App Store data-handling disclosures. Release also needs screenshots/metadata, age rating, support information, review access, export-compliance answers, agreements, and an accountable release owner.

**When:** Create the record after the bundle ID/name are stable; complete it during M8 before external TestFlight/App Review.

**Steps:**

1. In App Store Connect, create the app with the approved name, primary language, bundle ID, SKU, and organization ownership.
2. Publish working privacy and support URLs. Apple documents the required privacy-policy URL and data-practice disclosures under [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).
3. Complete App Privacy using the final data inventory, including server processing and third-party SDK/provider behavior; do not guess from early designs.
4. Complete age rating, category, territories, accessibility information, screenshots, description, keywords, review notes, and reachable contact.
5. Answer export-compliance questions based on the final build and qualified guidance. Apple explains the determination under [export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/).
6. Provide safe demo accounts/data that exercise gated flows without real minors, incidents, private media, or live precise location.
7. Account Holder accepts current agreements; release owner reviews privacy, content-moderation/reporting, account deletion, permission-purpose strings, and phased-release settings before submission.

**Return to the team:** App Store Connect numeric app ID, final bundle ID/name/SKU, metadata/territory/age-rating decisions, privacy questionnaire approval, review-contact owner, agreement status, export-compliance result/reference, and submission authority. No reviewer password in source or issues; store demo access in the approved secure release channel.

**Can work continue?** Yes until external beta/release. Submission cannot.

## HAR-008 — Physical-device and pilot participation

**What:** Supply representative devices and real organizer/volunteer pilot participants under an approved test plan.

**Why:** Simulator and automated tests cannot fully prove camera/photo permissions, push delivery, maps handoff, Keychain/offline behavior, poor connectivity, Dynamic Type/VoiceOver on devices, event-day load, or the clarity of organizer/guardian workflows.

**When:** Internal device testing begins once #8 launches; structured organizer/volunteer pilot occurs in M8 before production rollout.

**Steps:**

1. Name a pilot owner, organizer group, site-lead group, adult volunteers, and guardians; do not use real minor records unless counsel and the approved pilot protocol permit it.
2. Provide a supported-device matrix including older supported iPhone hardware and current iOS versions, plus assistive-technology participants where practical.
3. Schedule a controlled rehearsal for intermittent connectivity, repeated scans/taps, partial uploads, permission denial, assignment changes, incident escalation, media report/hide/review, and support handoff.
4. Use synthetic or expressly authorized test data and provide informed pilot notices.
5. Record defects in GitHub with redacted reproduction steps; never attach sensitive screenshots, location, contact, consent, incident, or private-media data.
6. Approve or reject progression from internal TestFlight to external pilot and from pilot to phased App Store release based on the release checklist.

**Return to the team:** Pilot owner, participants by role (not sensitive profiles), device/OS matrix, rehearsal window, approved synthetic data, acceptance findings, and go/no-go decision with owned defects.

**Can work continue?** Yes until beta acceptance; production readiness cannot be declared without it.

## Communication protocol

The Human Liaison consolidates owner requests here and reports only decisions that require legal authority, spending, external-account access, real-world operating ownership, or irreversible release action. Engineers should not ask the owner to choose routine class names, libraries, implementation patterns, test coverage, or obvious bug fixes. Completed human actions are recorded with dates and non-secret references; credentials remain in the designated provider/secret store.
