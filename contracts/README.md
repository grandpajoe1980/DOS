# Day of Service v1 contracts

This directory is the versioned interface boundary shared by the iOS app, web
surfaces, Supabase migrations/Edge Functions, and integration tests.

## Source of truth

- `openapi/v1.yaml` defines HTTPS request and response contracts.
- `schemas/realtime-event.schema.json` defines the minimal realtime envelope.
- `fixtures/manifest.json` maps representative valid and invalid payloads to
  their schemas.
- `validate_contracts.py` validates the OpenAPI document, JSON Schemas,
  fixtures, operation IDs, and mutation idempotency requirements.

Clients may generate types from these files, but generated files must name the
source version and regeneration command. PostgreSQL remains the source of truth.
Tenant-owned response resources expose immutable, server-derived
`organization_id`; create requests do not accept a caller-selected tenant ID.

## Validation

Requires Python 3.10 or newer.

```bash
python -m pip install -r contracts/requirements.txt
python contracts/validate_contracts.py
```

The foundation CI issue (#5) must run the same command for every pull request.

## Compatibility rules

- Existing paths, operation IDs, required request fields, and response fields
  cannot be removed in v1.
- Additive response fields are allowed. Clients must ignore unknown fields.
- Response state strings may gain values. Clients must preserve an `unknown`
  fallback instead of failing the whole resource.
- Requests reject unknown fields to prevent over-posting.
- Breaking behavior requires a new API version and an overlap window.

## Requirement coverage

| Requirement | Contract surface |
|---|---|
| FR-001–FR-004 | Profile, organization, membership, invitation, export/job schemas |
| FR-101–FR-106 | Public occurrences, event details, registration, consent, assignment |
| FR-201–FR-206 | Attendance, announcements, Safety Sharing, realtime redaction |
| FR-301–FR-305 | Signed media upload, completion, moderation, reports |
| FR-401 | Export request and asynchronous job status |

Authorization and database enforcement are deliberately outside the contract
implementation. They are acceptance requirements for issue #7.
