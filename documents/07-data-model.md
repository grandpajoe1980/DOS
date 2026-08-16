# Data model

All identifiers are UUIDs; timestamps are UTC `timestamptz`; displayed schedules retain an IANA time-zone identifier. Tenant tables include `organization_id` and appropriate composite uniqueness/FKs.

## Identity and tenancy

`profiles`, `organizations`, `organization_memberships`, `organization_invitations`, `role_grants`, `support_access_grants`, `audit_events`.

## Programming and operations

`event_definitions` hold reusable content. `event_occurrences` hold dated schedule/state. `sites` hold public and restricted location fields. `shifts`, `tasks`, `site_assignments`, `announcements`, `incidents`, and `safety_shares` support operations.

## Participation

`households`, `dependents`, `teams`, `team_members`, `registrations`, `registration_participants`, `participant_preferences`, `assignments`, `attendance_events`, and `impact_entries`.

A dependent belongs to a guardian-controlled household and is not represented as an independently empowered account. A registration participant references exactly one adult profile or dependent. Team membership does not imply guardian authority.

## Consent

`legal_documents(id, organization_id, kind, version, locale, content_hash, published_at, retired_at)` and `consent_evidence(id, document_id, participant_id, signer_profile_id, relationship, accepted_at, method, evidence_payload, revoked_at, superseded_by)` preserve an append-only trail. Required evidence is derived from policy and active version; never overwrite history.

## Media

`media_assets` tracks uploader, object key, checksum, MIME, bytes, scan/processing state, and retention. `media_derivatives`, `media_subject_attestations`, `media_moderation_actions`, `media_publications`, and `media_reports` separate storage, consent, decisions, publication, and takedown.

## Constraints/indexes

Use partial unique indexes for active memberships/assignments, exclusion or transaction checks for shift collisions, geography indexes for site queries, indexes on tenant plus lifecycle state, and append-only triggers/policies for evidence/audit records. Hard capacity is enforced transactionally; soft targets are informational.
