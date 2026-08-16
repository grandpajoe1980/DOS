# V1 contract-to-data and authorization map

Status: implementation design; no migrations have been created  
Last reviewed: 2026-08-16  
Contract reviewed: contracts/openapi/v1.yaml (60 operations)

## Purpose and authority

This document turns the v1 HTTP contract into a concrete PostgreSQL data,
authorization, transaction, retention, and verification design. It is the
handoff for migration and policy implementation; it is not evidence that the
controls exist.

Authority remains, in order, the product decision log, accepted ADRs, the
versioned contract, docs/ARCHITECTURE.md, and this map. ADR-003 defines the
deny-by-default authorization boundary, ADR-004 defines reactive media
quarantine, and proposed ADR-005 defines the database command transaction.
When a contract question is unresolved, this map fails closed and records the
question instead of inventing a permissive path.

## Database and actor vocabulary

### Namespaces and roles

| Name | Purpose | Access rule |
|---|---|---|
| app_private | Authoritative domain tables | Not API-exposed; no direct anon or authenticated grant |
| api_v1 | Contract-shaped views and command/query functions | Only reviewed entry points; explicit column and execute grants |
| policy | Boolean actor/resource predicates | Safe search path, qualified objects, false on absent context |
| ops_private | Idempotency, audit, outbox, jobs, support and reconciliation | Worker- or operator-specific grants; never general tenant access |
| dos_context_query role family | Non-login owners for reviewed read views/query functions | One role per bounded context; no BYPASSRLS; not a base-table owner; only context-required base-column SELECT grants |
| dos_context_command role family | Non-login owners for approved command functions | One role per bounded context; no BYPASSRLS; not a base-table owner; no cross-context table grants; forced RLS still applies |
| dos_media_worker, dos_notification_worker, dos_export_worker, dos_retention_worker | Narrow worker identities | Can claim only their queues and invoke named transitions |

Every tenant base table has non-null organization_id, a unique
(organization_id, id) key, and tenant-composite foreign keys. Global rows are
limited to identities, actor-owned households, and actor privacy lifecycle.
They use explicit owner/guardian scope and are never assigned a fake tenant.

### Actor predicates

These names are design commitments; migration authors may add parameters but
must not weaken their meaning.

| Predicate | Server-owned facts checked |
|---|---|
| policy.actor_profile_id() | auth.uid() maps to one active profile; otherwise NULL |
| policy.actor_is_adult() | Current, non-revoked adult assurance/capability; not a body flag |
| policy.is_active_member(org_id) | Active profile and active membership in the exact organization |
| policy.has_org_role(org_id, role_names[]) | Active membership plus current normalized role grants |
| policy.has_site_scope(org_id, site_id) | Owner/organizer whole-tenant scope, or active site-lead assignment to the exact tenant/site |
| policy.is_guardian_of(dependent_id) | Current explicit household-guardian relationship; never team membership |
| policy.controls_registration(registration_id) | Registration controller, self participant, guardian of every affected dependent, or authorized organizer path |
| policy.is_assigned_participant(assignment_id) | Actor profile participant or guardian-controlled dependent is in the confirmed assignment |
| policy.can_view_occurrence_feed(occurrence_id) | Owner/organizer/media moderator, assigned site lead, or adult with submitted/assigned participation; excludes draft, cancelled and waitlisted-only participation by default |
| policy.has_support_grant(scope_type, scope_id, capability) | Current platform identity, MFA/JIT grant, matching ticket/reason/capability/resource, not expired/revoked |

org_owner, organizer, media_moderator, and site_lead are organization roles.
Adult, guardian, participant, and team leader are resource capabilities, not
organization roles. Dependents never authenticate. Organization owners cannot
grant platform capabilities.

### Common policy behavior

- Missing actor, inactive/suspended membership, foreign tenant, wrong site,
  archived/deleted resource, expired grant, and failed guardian checks deny.
- Sensitive foreign and nonexistent IDs return the same safe not-found result
  where the contract permits; logs retain only a request ID and reason code.
- Every command derives organization through the loaded parent chain. A path
  organization_id is a lookup/scope assertion, never sufficient authority.
- Expected versions are checked after locking the resource. Stale writes return
  a conflict and make no audit/outbox business event.
- Ordinary user commands use the JWT actor context and forced RLS. Support and
  workers call separate named functions; no user handler uses an unrestricted
  service key.
- Read views are contract-column allowlists. Public, realtime, logs, audit, and
  outbox never contain precise addresses/location, dependent rosters, consent
  payloads, incident text, media object keys/private URLs, or report contacts.

## Authoritative object catalog

Table names below are plural and live in app_private unless listed as platform
control, which lives in ops_private. Restricted subrecords are kept separate so
a routine tenant select cannot accidentally include them.

| Context | Authoritative tables | Reviewed views/functions |
|---|---|---|
| Identity and tenancy | profiles, profile_assurances, organizations, organization_memberships, membership_role_grants, membership_site_assignments, organization_invitations, organization_invitation_contacts | my_profile and organization_membership views; profile, organization, invitation and membership commands |
| Event programming | legal_documents, event_definitions, event_occurrences, occurrence_legal_requirements, sites, site_private_locations, public_site_locations, shifts, service_tasks | private preview, public occurrence/site views; event create/update/publish commands |
| Household and teams | households, household_guardians, dependents, teams, team_members | guardian-scoped household/dependent and member-scoped team views; household/dependent/team commands |
| Registration and consent | registrations, registration_participants, consent_evidence, consent_revocations, consent_supersessions | controller-scoped registration, legal-document and effective-consent views; registration/consent commands |
| Assignment and operations | assignment_plans, assignments, attendance_events, announcements, incidents, incident_participants, notification_endpoints | assignment detail/directions, scope-filtered roster/announcement views; planning, confirmation, attendance, announcement and incident commands |
| Safety Sharing | safety_shares, safety_share_recipients, safety_share_current_locations | subject/recipient-scoped share and current-location views; create/update/stop/expire commands |
| Media | media_assets, media_upload_leases, media_objects, media_derivatives, media_reports, media_report_contacts, media_moderation_actions, media_publication_clearances, media_delivery_revocations | authenticated feed, public gallery and delivery authorization views/functions; upload, complete, processor-result, report and moderation commands |
| Impact and lifecycle | account_deletion_requests, deletion_steps, jobs, job_artifacts, legal_holds | actor/tenant-scoped job views; personal export, tenant export, deletion and artifact-authorization commands |
| Platform control | idempotency_records, audit_events, outbox_events, outbox_deliveries, support_grants, reconciliation_runs | no general read view; queue claim/complete and tightly scoped support/audit functions |

## Contract operation map: data and authorization

### Identity and tenancy

| Operations | Authoritative objects / API read model | Tenant derivation | Deny-by-default allow rule |
|---|---|---|---|
| getMyProfile, updateMyProfile | profiles; api_v1.my_profile; cmd_update_my_profile | Global actor row from auth.uid() | Actor may read/update only their active profile. Update locks profile and checks expected_version; accessibility values are allowlisted. No organization role confers profile access. |
| createPersonalExport, createAccountDeletionRequest | jobs, job_artifacts, account_deletion_requests, deletion_steps, legal_holds; privacy commands | Actor scope from auth.uid(); no tenant accepted from request | Active actor only, with recent reauthentication for deletion and artifact download. Actor requests only eligible personal data. Guardian export/deletion needs a separate explicit contract and is not inferred. Legal holds may block a step but never disclose another subject. |
| createOrganization | organizations, memberships and role grants; cmd_create_organization | Newly generated organization ID inside the command | Any authenticated adult may create. The transaction creates exactly one active org_owner membership for the actor. Slug is normalized/globally unique. No platform role can be created. |
| createOrganizationInvitation, revokeOrganizationInvitation | organization_invitations and restricted organization_invitation_contacts; invitation commands | Organization path or invitation row, then current membership | Active org_owner only. Roles are limited to the OpenAPI organization-role enum. Assigned sites must be same tenant and appear only with site_lead. Store token hash, normalized email hash and display hint; keep the encrypted delivery address in the separate contact row and put only invitation ID in outbox. Never store the token. Revoke/expiry/accept are exclusive under row lock. |
| acceptOrganizationInvitation | Invitation, membership, role and site-assignment rows; cmd_accept_invitation | Invitation row selected by ID plus token hash | Authenticated actor with matching normalized verified email; token current, unused and unrevoked; inviter/organization still valid. Definer function reveals no invitation row. Acceptance consumes once and grants only invited roles/sites. |
| updateOrganizationMembership | Membership and normalized role/site grants; cmd_update_membership | Membership row | Active org_owner in same organization. Block platform roles, foreign sites, empty roles for active members, and removal/demotion/suspension of the last active owner. Self-change has no bypass. |

### Event programming and public discovery

| Operations | Authoritative objects / API read model | Tenant derivation | Deny-by-default allow rule |
|---|---|---|---|
| createEventDefinition, updateEventDefinition | event_definitions, referenced active legal_documents; definition commands | Organization path for create; definition row for update | Active owner or organizer in same organization. Default document must be same tenant and eligible kind/state. Expected version is required for update. |
| createEventOccurrence, updateEventOccurrence | Occurrence/site/shift/task tree plus restricted site_private_locations and derived public_site_locations; occurrence commands | Definition or occurrence row | Active owner/organizer. Validate IANA zone, UTC ordering, registration window, nested shift bounds, task ages and capacity. Precise address is separated from public text; verified geocoding creates the private point and a policy-coarsened/withheld public point. Because update supplies no nested IDs, replacing sites is draft-only and forbidden after registrations/plans. |
| previewEventOccurrence | api_v1.event_occurrence_preview over full private tree | Occurrence row | Active owner/organizer only. Preview includes precise fields, is private/no-store, never indexed, and is not available through a public view. |
| publishEventOccurrence | Occurrence plus public allowlist views; cmd_publish_occurrence | Occurrence row | Active owner/organizer. Lock occurrence; require draft/current version, confirmation, complete tree, current required documents, valid public fields and coherent dates. Publishing never exposes precise addresses or internal limits. |
| listPublicOccurrences, getPublicOccurrence | api_v1.public_occurrences and api_v1.public_sites | Organization slug or occurrence resolves a published tenant row | Anonymous select only for published state and explicit PublicOccurrence/PublicSite columns. No draft existence, precise address, hard limit, roster, contact or private document data. Cursor binds query/sort and has short signature/expiry. |

### Households, teams, registration, and consent

| Operations | Authoritative objects / API read model | Tenant derivation | Deny-by-default allow rule |
|---|---|---|---|
| createHousehold, getHousehold | households, household_guardians; guardian-scoped view | Global actor-owned household | Authenticated adult guardian only. Create binds actor as initial guardian. Read requires current guardian relation. Tenant staff and team leaders receive no household access. |
| createDependent, updateDependent, archiveDependent | dependents and guardian relation; dependent commands | Global household/dependent chain | Current guardian only. Eligibility birth data/media visibility are Restricted. Archive/update lock the dependent, check version when supplied, and preserve consent/registration history. Visibility downgrade emits takedown reconciliation. |
| createTeam, getTeam, updateTeam | teams, team_members; member-scoped view | Occurrence for create; team thereafter | Create requires adult and open published occurrence permitting teams. Read is active adult members, guardians of member dependents, and same-tenant owner/organizer. Update is team leader or owner/organizer; organizer authority does not grant guardian rights. |
| addTeamMember, removeTeamMember | team_members; member commands | Team to occurrence to organization | Exact-one profile/dependent. Adult adds/removes self; guardian adds/removes own dependent; leader may remove an adult but cannot add an unrelated profile or act as guardian. Owner/organizer may remove for operations with audit. Active participant uniqueness is enforced. |
| createRegistration, updateRegistration | registrations, registration_participants; controller view and commands | Occurrence for create; registration thereafter | Authenticated adult controls only self and current guardian-controlled dependents. Participant sources, team and site must be same occurrence/tenant. Organizer-assisted registration denies until separately consented. Draft/current lifecycle and versions apply. Accommodations are Restricted and excluded from general views. |
| submitRegistration | Registration, participant, occurrence, requirement and effective-consent views; submission command | Registration chain | Controller only. Lock registration/occurrence; require open window, current occurrence, eligibility, exact active evidence per participant, guardian evidence for dependents, and consistent team. Submission does not consume hard capacity; result is submitted or policy waitlist. |
| listOccurrenceLegalDocuments, getLegalDocument | legal_documents, occurrence_legal_requirements; contract legal views | Occurrence/document relationship | Owner/organizer may read tenant documents. Registering adult reads only active documents required by accessible published occurrence/owned registration. Unrelated IDs deny. Content/hash/version are immutable after publication. |
| createConsent | Immutable evidence plus registration/document facts; consent command | Registration participant to registration/occurrence/organization | Actor must be adult profile represented by participant. ID, label and hash exactly match active requirement. Accepted name is evidence, not identity proof; trusted actor/time/method/locale bind on insert. |
| createGuardianConsent | Evidence plus guardian/dependent relation | Participant/dependent registration chain | Actor is current guardian of exact dependent and participant references that dependent. Team lead, emergency contact and organization role do not satisfy guardian authority. Store asserted relationship without claiming external verification. |
| revokeConsent, supersedeConsent | consent_evidence and append-only revocation/supersession tables | Original evidence row | Original signer may act; current guardian only for evidence tied to their dependent; support/legal path needs its own grant. Lock evidence root, validate version/new document hash, append history, trigger participation/media re-evaluation. Never rewrite accepted record. |

### Assignment and event operations

| Operations | Authoritative objects / API read model | Tenant derivation | Deny-by-default allow rule |
|---|---|---|---|
| planAssignments | assignment_plans, proposed assignments, registration/site/shift/task facts; planning command | Occurrence row | Active owner/organizer only. Requested registrations are same tenant/occurrence or default to eligible submitted rows. Planner checks eligibility, accessibility, overlap, team mode and hard limit. Plans/proposals expire and are not participant-visible as confirmed work. |
| confirmAssignment | Proposed assignment/plan, registration and capacity roots; confirmation command | Assignment chain | Active owner/organizer only. Proposal is current/unexpired and expected version current. Lock occurrence then sites in UUID order, count participant slots, confirm registration as one atomic group and update registration. One assignment owns a must-stay-together registration group. |
| getRegistrationAssignment, getAssignmentDirections | Assignment detail/directions allowlist views | Registration/assignment chain | Registration controller, represented adult, guardian of represented dependent, same-tenant owner/organizer, or assigned site lead. Precise directions require confirmed/current assignment; lead must match site. Team membership alone grants no other registration directions. Private/no-store. |
| listAssignedRoster | Scope-filtered api_v1.assigned_roster | Occurrence and each assignment/site row | Owner/organizer sees tenant occurrence; site lead sees only rows for currently assigned sites. No ordinary participant access. Only minimized display/type/attendance fields; no contacts, accommodations, consent, exact birth date, incidents or household data. |
| createAttendanceEvent | Append-only attendance_events, assignment/participant facts; attendance command | Assignment to site/occurrence/organization | Current owner/organizer; site lead for assigned site; or assigned adult/guardian checking only self/controlled dependent if self-service is enabled for the occurrence. Reauthorize at replay. organization/client_operation_id is unique; legal sequence derives from accepted events. |
| createAnnouncement, listAnnouncements | announcements and outbox delivery; audience-filtered view | Occurrence row | Create is owner/organizer only; audience shape matches kind and sites/roles are same tenant. List is active recipients only: registered/assigned adult, guardian as applicable, or current role/site recipient. Recipient identities/addresses are never returned. Emergency priority does not alter authority. |
| createIncident | incidents, incident_participants; restricted intake command | Occurrence/site rows | Owner/organizer or site lead assigned to exact site. Affected participants belong to occurrence/site. Response is minimal reference; text never enters audit, outbox, normal analytics, roster or exports. No contract read endpoint exists. |

### Safety Sharing

| Operations | Authoritative objects / API read model | Tenant derivation | Deny-by-default allow rule |
|---|---|---|---|
| createSafetyShare | safety_shares, safety_share_recipients; create command | Occurrence/site rows | Actor is an adult participant or authorized event staff at that occurrence/site and always shares only their own location. Minor/dependent and on-behalf creation deny. Recipients are current owner/organizer or assigned site leads explicitly selected by actor. Expiry is bounded by server maximum/event end. |
| updateSafetyShareLocation | safety_share_current_locations; update command | Share row | Share subject only while active/unexpired. Validate coordinate, accuracy and time; replace only if captured_at is newer. Keep one sample, not movement history. Outbox/realtime carries only an invalidation ID. |
| getSafetyShare, getSafetyShareLocation | Subject/recipient-scoped share/current-location views | Share and recipient rows | Subject or explicitly listed, still-authorized recipient only. Location additionally requires active/unexpired share and current recipient role/site. Audit Restricted reads without coordinates. Expired/stopped reads deny despite stale client state. |
| stopSafetyShare | Share/current sample; stop command | Share row | Subject may always stop. Current owner/organizer may emergency-stop with reason/audit but gains no location read. Stop/automatic expiry locks share, transitions once, removes current sample and emits recipient invalidation. |

### Media

| Operations | Authoritative objects / API read model | Tenant derivation | Deny-by-default allow rule |
|---|---|---|---|
| listEventMediaFeed | api_v1.event_media_feed over ready/visible assets and safe derivatives | Occurrence row | can_view_occurrence_feed plus active occurrence/resource tenant. Default excludes draft/cancelled/waitlisted-only actors. Moderator reads current-tenant review; site lead is occurrence/site scoped. Recheck dependent/guardian policy. No URLs/object keys are listed. |
| getEventFeedMediaDelivery | Delivery function over asset/derivative/revocation epoch | Media row | Same feed audience, processing ready, feed visible, current guardian/policy clearance and safe derivative. Recheck at issuance; return short-lived audience-bound capability with no object key. Audit opaque asset/audience/expiry only. |
| listPublicMediaGallery | api_v1.public_gallery | Published occurrence and asset rows | Anonymous only when occurrence published, public state published, asset not quarantined/removed, derivative approved, and required publication clearances current. Contract allowlist only. |
| getPublicGalleryMediaDelivery | Public delivery function | Media/occurrence/publication rows | Same public predicate at issuance. Return short-lived derivative capability. Quarantine, guardian downgrade, unpublish or removal increments delivery epoch and emits purge/invalidation. Never sign an original or expose R2 key. |
| createMediaUpload | media_assets, one-use media_upload_leases, private media_objects; upload command | Occurrence and optional site | Authenticated adult current eligible event member or authorized staff in exact occurrence; minors, suspended actors and foreign sites deny. Server binds uploader, tenant, key, type, bytes, checksum, expiry and nonce. Attestation is recorded but does not replace guardian policy. |
| completeMediaUpload | Upload lease/object/asset; complete command and processing outbox | Media row | Original uploader only. Lock media, require unused/current lease and lifecycle, verify R2 object identity/HEAD, bytes/checksum and actual type. Mark private upload complete once and enqueue scan/transform; do not make feed/public visible here. A replay reuses the committed lease/media identity and never allocates another object. |
| createMediaReport | media_reports, encrypted/restricted report contact/details, media state and delivery revocation; report command | Media row; optional actor context | Anonymous may report a currently public item; authenticated member may report an item they can view. Rate-limit/deduplicate with non-enumerating errors. Valid report locks media, appends report, atomically quarantines feed and withdraws/rejects public state before response, increments delivery epoch and emits purge/review. |
| createMediaModerationAction | Append-only moderation, media state, clearances and revocation | Media row | Current owner/organizer/media moderator in same tenant; transition and expected version valid. Restore never publishes publicly. Public approval/publication also requires recorded subject/guardian clearance. Notes stay Restricted. Removal is irreversible through this endpoint. |

The media processor is not an HTTP contract operation. dos_media_worker invokes
a named result function with a claimed job ID. Under media row lock, a
successful verified adult asset becomes ready/visible only when no report,
quarantine or removal exists. Report and processor races therefore end
quarantined when a valid report commits after, or is already present before,
the processor transaction.

### Exports and jobs

| Operations | Authoritative objects / API read model | Tenant derivation | Deny-by-default allow rule |
|---|---|---|---|
| createExport | jobs, job_artifacts; export command and privacy-thresholded source views | Occurrence row | Active owner/organizer in same tenant. Export reads requested occurrence/kind and approved policy only; excludes incidents, consent payloads, precise Safety Sharing, object keys and unnecessary minor identity. CSV cells are formula-safe. |
| getJob | Actor/tenant-scoped api_v1.jobs; artifact authorization function | Job owner and, for tenant jobs, immutable organization ID | Personal job is requesting actor only. Tenant job is requestor plus current owner/organizer authority. Result authorization is rechecked per call/download, short-lived, no-store and audited. Expired/failed artifacts never return URL. |

## Transaction, audit, outbox, idempotency, and retention map

ADR-005 command sequencing applies to every mutation: claim idempotency, derive
scope, lock, reauthorize, validate version/invariants, mutate, append audit and
outbox, store safe outcome, commit.

| Family | Atomic roots and invariants | Audit and outbox | Idempotency | Retention class |
|---|---|---|---|---|
| Profile/privacy | Lock profile/deletion request; one active deletion workflow; legal-hold step cannot be skipped | Audit profile/security changes; enqueue export/deletion without data payload | Actor + operation + key; deletion retries return same request/job | RET-10, RET-60, RET-70 |
| Organization/membership | Lock organization before membership; at least one active owner; invitation single-use/email-bound | Audit role/site/status; invitation notification and auth-cache invalidation | Actor + operation + key; accept also unique token hash | RET-10, RET-20, RET-80, RET-70 |
| Event programming | Lock definition/occurrence; draft-only topology replacement; publish all-or-nothing | Audit configuration/publish; public-cache/realtime invalidation | Actor + operation + key + expected version/hash | RET-20, RET-70 |
| Household/dependent/team | Lock resource; preserve references; exact-one team participant; no guardian inference | Audit visibility/archive/team change; media reconciliation on downgrade | Actor + operation + key; active membership uniqueness | RET-10, RET-30, RET-70 |
| Registration/consent | Lock registration/evidence root; exact source; active document per participant; append-only lifecycle | Audit evidence without names/content; assignment/notification/media invalidation | Actor + operation + key; unique effective evidence per requirement | RET-20, RET-30, RET-70 |
| Assignment | Lock occurrence then sites sorted UUID; reservations expire; count participant slots; one active assignment/registration | Audit plan/confirm/waitlist; assignment notification/roster invalidation | Actor + operation + key; replay plan/assignment outcome | RET-20, RET-80, RET-70 |
| Attendance | Lock assignment/participant; append legal state event; reject invalid sequence | Audit opaque action; roster/impact invalidation | HTTP key plus unique organization/client_operation_id | RET-20, RET-70 |
| Announcement | Audience resolution and queued record commit together; recipients server-derived | Audit creator/audience kind/count; one outbox effect per recipient/provider dedupe | Actor + operation + key; unique notification effect key | RET-20, RET-60, RET-70 |
| Incident | Incident and affected same-scope links commit; reference-only response | Restricted audit without text; redacted escalation job ID | Actor + operation + key | RET-30, RET-70 |
| Safety Sharing | Lock share; current-sample compare/swap; stop/expiry removes access atomically | Audit create/read/stop without text/coordinates; redacted invalidation | Actor + operation + key; sample compares capture time/hash | RET-40, RET-70, RET-80 |
| Media | Lock media for completion, worker result, report, moderation, delivery epoch; report dominates races | Audit opaque state/reason; processing/purge/review/storage effects use safe IDs | Principal + operation + key; checksum/lease nonce/version add dedupe | RET-50, RET-60, RET-70, RET-80 |
| Tenant export/job | Job/artifact record commits before worker; source snapshot/version recorded; result reauthorized | Audit request/download/expiry; outbox contains IDs/kind only | Actor + operation + key; artifact unique by job/attempt | RET-60, RET-70 |

### Retention classes

Durations are deliberately not specified: production values require the
owner/legal decisions in docs/SECURITY_AND_PRIVACY.md and
docs/HUMAN_ACTION_REQUIRED.md. Migrations tag every table with a class and the
retention worker implements the approved schedule.

| Class | Data | Required behavior before durations are approved |
|---|---|---|
| RET-10 Account | Profile, organization membership, household | Active lifecycle plus approved closure period; honor export/correction/deletion and legal hold |
| RET-20 Event operations | Events, registrations, teams, assignments, attendance, announcements, aggregates | Event/business retention; de-identify where possible; do not inherit incident/consent retention |
| RET-30 Restricted evidence | Dependents, eligibility, accommodations, consent, incidents, report details | Separate schedule/access; preserve append-only evidence where required; explicit legal hold |
| RET-40 Precise ephemeral | Safety Share/current location | Strict maximum; keep one current sample; stop/expiry removes access; purge due rows before restored service |
| RET-50 Media lifecycle | Leases, originals, derivatives, reports, moderation/clearance | Separate abandoned upload/original/derivative/public/report/takedown schedules; reconcile R2/CDN |
| RET-60 Async artifacts | Announcement delivery, jobs, exports, deletion steps | Short-lived artifact access; expire URL/object; minimal job status only if approved |
| RET-70 Audit/security | Audit, support use, deletion tombstone, access ledger | Immutable/restricted approved schedule; no sensitive changed payload |
| RET-80 Ephemeral control | Invitation hash, idempotency, outbox lease/dead letter, cursor/nonce | Keep through replay/diagnostic window; no raw token; monitored purge |

## Migration order and dependency rules

All migrations are forward-only, additive where possible, and transactional.
A table's RLS, force-RLS, indexes, constraints and initial deny tests ship with
the table before any API grant.

1. **M000 platform:** required extensions, UUID/time-zone helpers, empty
   namespaces, non-login roles, ownership/grant defaults, and enum/check-domain
   strategy. Do not expose a schema yet.
2. **M010 identity/tenancy:** profiles, adult assurances, organizations,
   memberships, normalized organization roles/site grants, invitations and
   support grants. Add actor/membership/role predicates and two-tenant tests.
3. **M020 control plane:** idempotency, audit, outbox/delivery/dead-letter and
   reconciliation tables/functions. Validate command-role forced-RLS behavior
   before a business command uses them.
4. **M030 legal and event programming:** immutable legal documents, event
   definitions, occurrences, requirements, sites, shifts and tasks. Add public
   allowlist views only after draft/private-field denial tests pass.
5. **M040 household and teams:** household/guardian/dependent and team/member
   rows plus guardian/member policies. Tenant staff get no access to global
   household tables.
6. **M050 registration and consent:** registrations/participants and append-only
   consent/revocation/supersession. Add submit/effective-requirement functions
   after guardian-forgery and stale-document tests pass.
7. **M060 assignment:** plans, expiring proposed assignments, capacity lock
   functions, confirmation/waitlist transitions and deterministic concurrency
   tests.
8. **M070 event operations:** attendance, announcements, incidents, Safety
   Sharing/current-location and narrowly scoped read models.
9. **M080 media:** private asset/lease/object/derivative tables, independent
   state dimensions, report/contact/moderation/clearance/revocation, worker
   grants, feed/gallery views and delivery functions. Upload remains disabled
   until report quarantine and delivery invalidation tests pass.
10. **M090 lifecycle and impact:** privacy-thresholded source views, jobs,
    artifacts, deletion requests/steps and legal holds.
11. **M100 API/realtime exposure:** complete api_v1 contract mappings, minimal
    realtime publications, grants and schema inspection. Enable only slices
    whose API/RLS/concurrency tests are green.

Feature migrations may interleave command/view additions with this order, but
they may not reference a later context or expose a table early. Cross-context
writers call the owning context's function and communicate external effects by
outbox; they never update another context's tables directly.

## Recovery and reconciliation

- **Database:** encrypted backup/PITR restores happen in isolation. Apply
  current migrations, due expiry/deletion/quarantine work, and the two-tenant
  policy suite before promotion.
- **Outbox/jobs:** stable effect keys make replay safe. Stuck leases expire;
  retries resume. Dead-letter replay is authorized/audited. Provider receipts
  never become business source of truth.
- **Idempotency:** committed outcomes survive response loss. In-progress claims
  live in the business transaction, so abort leaves no permanent claim. Purge
  only after the supported retry window.
- **Media/R2:** inventory reconciliation finds database-without-object and
  object-without-database cases, keeps unknown objects private, and never makes
  an asset visible from object presence. Restore reapplies report, guardian and
  publication state before delivery.
- **Safety Sharing:** restored expired/stopped shares and samples are purged or
  unreadable before clients connect. Backups are not a live-location source.
- **Deletion/export:** each step has a stable replay key. Reconcile identity,
  database, R2/CDN, notification providers, artifacts and tombstones; report
  retained/held categories truthfully.
- **Rollback:** disable route/feature/worker and deploy the last reviewed
  function/policy. Never disable RLS, broaden a role, expose base tables, make a
  bucket public, or rewrite evidence to restore service.

## Required two-tenant and concurrency tests

### Shared fixture

Create organizations A and B with owner, organizer, media moderator, assigned
and unassigned site lead, adult participant/guardian, dependent, suspended
member, removed member, and unrelated authenticated actor. Add anonymous,
expired support, valid resource-scoped support, and each worker identity. Use
opaque IDs from both tenants in every path/body reference position.

Every API surface gets API-level and direct-database coverage:

1. Intended actor succeeds for the exact row and columns.
2. Equivalent actor in the other tenant cannot read, write, subscribe, export,
   download, or infer existence.
3. No-member, suspended/removed, wrong-role and unassigned-site actors deny.
4. Guardian succeeds only for their dependent; team leader and tenant staff do
   not gain guardian scope.
5. Public responses and realtime envelopes match closed allowlists.
6. A definer function invoked directly cannot change actor/tenant through
   parameters, GUC/search-path tricks, or foreign resource IDs.
7. Worker A cannot claim worker B's queue or invoke its transition.
8. Audit/outbox/idempotency rows are scoped and contain no banned payload.

### Family scenarios

| Family | Two-tenant / abuse assertions | Separate-session concurrency assertions |
|---|---|---|
| Organization | Foreign membership/invitation/site IDs deny; organizer cannot manage owners; token/email mismatch does not enumerate | Two accepts create one membership; accept vs revoke has one winner; concurrent owner demotions keep one owner; same key/different payload conflicts |
| Event/public | Tenant B cannot preview/edit/publish A; anonymous cannot infer drafts/precise fields | Two updates/publishes with one version have one winner; public row appears only after full publish commit; cursor cannot replay against other query |
| Household/team | Tenant staff cannot read household; team leader cannot alter another guardian's dependent; foreign occurrence/member deny | Concurrent dependent update/archive respects version; duplicate joins create one active row; remove vs registration revalidates |
| Registration/consent | Participant/dependent substitution deny; wrong document/hash/guardian/team authority deny | Duplicate create/submit replays once; submit vs participant update has one winner; consent duplicate/revoke/supersede preserves one effective chain/all evidence |
| Assignment | B registrations/sites cannot enter A plan; unassigned lead cannot read directions/roster | Burst plans/confirms at one remaining slot never exceed limit; expired proposal releases once; deterministic lock order avoids deadlock; must-stay group never splits |
| Attendance | Wrong tenant/site/participant denies; roster remains minimized | Same client operation creates one event; check-in/out race yields one legal sequence; replay after suspension returns prior identical outcome but denies a new operation |
| Announcement/incident | Foreign audience/site/participant denies; recipient and incident text never leak | Duplicate announcement/provider retry sends once per recipient; incident retry creates one reference; role suspension before lock denies |
| Safety Sharing | Minor/on-behalf/foreign recipient/wrong-site denies; stopped/expired/former recipient cannot read | Older sample cannot overwrite newer; update vs stop/expiry leaves no readable sample; duplicate stop replays; restore purges overdue sample |
| Media | Minor/foreign/nonmember upload denies; feed/gallery/delivery audiences differ; keys/EXIF absent | Complete vs lease reuse makes one job; processor vs report ends quarantined; report denies new delivery; restore vs second report cannot expose; publish vs guardian downgrade ends withdrawn |
| Export/deletion/job | Foreign job/occurrence and stale authority deny; artifact reauthorization/CSV injection safe | Duplicate request creates one job; authority removal prevents download; deletion/export follows snapshot/hold policy; worker retry makes one artifact |

Concurrency tests inspect final rows, versions, unique constraints, capacity,
effective state, audit count, outbox effect keys, and idempotent response—not
only status codes. Run randomized schedules in CI and a higher-volume staging
suite before beta.

## Unresolved risks and required decisions

| ID | Risk/gap | Fail-closed implementation position | Required owner |
|---|---|---|---|
| DA-001 | createPersonalExport has no organization selector but returns Job. | **Resolved**: Job schema updated so `organization_id` is nullable (`oneOf: [UUID, null]`). Personal export jobs return `null` while tenant-scoped export jobs return their tenant UUID. Contract baseline, schemas, and boundary tests updated. | Contract + product + privacy (Complete) |
| DA-002 | Media request has an attestation but no subject list or guardian-clearance capture. Dependent media_visibility, especially public publication, cannot be proven. | Keep originals private; allow event feed only under accepted attestation/report policy; deny public publication involving identifiable dependent without separate current clearance. Add approved clearance workflow/contract before gallery launch. | Product + privacy/legal + contract |
| DA-003 | Contract reads legal documents but has no authoring/publishing/occurrence-requirement mutation. Organizer authoring cannot be fully self-service through v1. | Seed/admin-import in non-production only; no direct organizer table access. Add reviewed contract operations before production self-service. | Product + contract |
| DA-004 | EventOccurrenceUpdate sites are create-shaped with no stable IDs. Safe published topology edits cannot map without reference churn. | Permit whole-tree replacement only in draft before dependent records; reject published replacement. Add ID-based operations if post-publish edits are required. | Product + contract |
| DA-005 | Attendance authority differs between the user outcome (adult self check-in/out) and FR-201 (site leads check participants); the occurrence contract has no self-service policy field. | Implement organizer/site-lead first. Participant/guardian self-service stays behind an unreleased platform flag default off and requires acceptance criteria plus a contract policy field before enablement. | Product + contract |
| DA-006 | Aggregate suppression thresholds and production retention durations are not approved. | No production export/public aggregate; conservative synthetic/non-production cleanup only. Do not encode guessed legal durations. | Owner + privacy/legal |
| DA-007 | A direct R2 signed URL cannot be revoked instantly after report. | Use authorization-aware delivery/edge capability with media delivery epoch and purge path; bounded TTL. No durable direct object URL. Define/test maximum revocation window before media beta. | Platform + security + product |
| DA-008 | Incidents have intake but no v1 read/review lifecycle operation. | Store Restricted and return minimal creation reference; review needs approved internal contract, not direct table access. | Product + contract + safety operations |
| DA-009 | The server-owned source and assurance level for adult status are unspecified, while organization creation, uploads and Safety Sharing require an adult. | Keep profile_assurances as the policy source and use synthetic status only outside production. Do not enable adult-only production actions until collection, notice, verification and revocation behavior are approved. | Product + identity + privacy/legal |
| DA-010 | AssignmentDirections requires latitude/longitude, but site authoring supplies only a precise address; public approximate coordinates also have no input. | Store address separately, geocode server-side, require organizer verification before precise directions, and derive/withhold the public point by policy. Do not invent coordinates or copy the precise point into the public view. | Product + platform + privacy |

DA-002 blocks anonymous public gallery launch. DA-006 blocks production export/retention claims. Other items proceed with the documented fail-closed positions.

