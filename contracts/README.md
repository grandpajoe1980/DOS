# Day of Service v1 contracts

This directory is the versioned interface boundary shared by the iOS app, web
surfaces, Supabase migrations/Edge Functions, and integration tests.

## Source of truth

- `openapi/v1.yaml` defines HTTPS request and response contracts.
- `schemas/realtime-event.schema.json` defines the minimal realtime envelope.
- `fixtures/manifest.json` maps representative valid and invalid payloads to
  their schemas.
- `baseline/v1-contract-surface.json` records the reviewed compatibility
  surface for v1.
- `validate_contracts.py` validates the OpenAPI document, JSON Schemas,
  deterministic email/URI fixture formats, operation IDs, mutation idempotency,
  tenant exclusion across the complete request-schema graph, privacy and Safety
  Share boundaries, and compatibility with the reviewed baseline.

Clients may generate types from these files, but generated files must name the
source version and regeneration command. PostgreSQL remains the source of truth.
Tenant-owned response resources expose immutable, server-derived
`organization_id`; create requests do not accept a caller-selected tenant ID.
Participant display names are also server-derived from the authenticated
profile or selected dependent rather than accepted from registration callers.

## Media audience contract

Media has three independent state dimensions:

- `processing_state` describes private upload validation and derivative work.
- `event_feed_state` controls the authenticated event/group feed. A validated
  adult upload becomes `visible` as soon as processing succeeds; it does not
  wait for platform approval.
- `public_gallery_state` controls the anonymous gallery and has a separate
  review/publish lifecycle.

Minors cannot upload. A successful report response means the event-feed item
was atomically moved to `quarantined` before the response was returned. Feed and
public-gallery delivery use separate routes and response shapes. Neither shape
exposes storage keys, upload URLs, object metadata, EXIF, moderation notes, or
private contact information.

## Validation

Requires Python 3.10 or newer.

```bash
python -m pip install -r contracts/requirements.txt
python contracts/validate_contracts.py
```

To inspect the current surface without modifying the reviewed baseline:

```bash
python contracts/validate_contracts.py --print-baseline
```

Do not replace the checked-in baseline as a routine response to a compatibility
failure. A baseline change is an explicit contract decision and must be reviewed
with the affected server and client work.

The foundation CI issue (#5) must run the same command for every pull request.

## Compatibility rules

- Existing paths and operation IDs cannot be removed or reassigned in v1.
- Existing properties and required response guarantees cannot be removed.
- New required request fields and removed enum values are breaking changes.
- Additive response fields are allowed. Clients must ignore unknown fields.
- Schemas validate the currently supported enum values strictly. Clients must
  still preserve an `unknown` fallback for forward-compatible rollout.
- Requests reject unknown fields to prevent over-posting.
- Breaking behavior requires a new API version and an overlap window.

## Requirement coverage

| Requirement | Contract surface |
|---|---|
| FR-001–FR-004 | Profile, organization, invitation acceptance/revocation, membership-role lifecycle, personal export/deletion, and job schemas. Provider authentication remains implementation work. |
| FR-101–FR-106 | Event create/edit/preview/publish, public discovery, household/dependent/team lifecycle, registration, legal-document retrieval, consent lifecycle, and assignment read. |
| FR-201–FR-206 | Roster, assignment/directions, attendance, announcement reads, incidents, authorized Safety Share recipient/location reads, and realtime redaction. |
| FR-301–FR-305 | Signed adult upload, independent processing/feed/gallery states, authenticated event feed, atomic report quarantine, anonymous gallery, and audience-specific delivery. |
| FR-401 | Export request and asynchronous job status. |

This table records interface coverage, not feature completion. The 27 manifest
fixtures are representative regressions, not a positive/negative pair for each
of the 60 operations. Authentication, authorization/RLS, media atomicity,
storage/derivative execution, asynchronous jobs, and generated-client or
per-operation integration coverage remain implementation work for issue #7 and
subsequent feature issues.
