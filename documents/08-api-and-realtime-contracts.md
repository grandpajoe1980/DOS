# API and realtime contracts

## Conventions

JSON over HTTPS; UTC RFC 3339 timestamps plus IANA time zones; cursor pagination; stable error codes; request IDs; optimistic concurrency tokens; and `Idempotency-Key` for retried mutations. Errors expose safe field pointers and never internal SQL or policy details.

## Representative endpoints

- `GET /v1/public/organizations/{slug}/occurrences`
- `GET /v1/public/occurrences/{id}`
- `POST /v1/registrations` and `PATCH /v1/registrations/{id}`
- `POST /v1/registrations/{id}/submit`
- `POST /v1/consents` and `POST /v1/guardian-consents`
- `POST /v1/assignments/plan` and `POST /v1/assignments/{id}/confirm`
- `POST /v1/attendance-events`
- `POST /v1/announcements`
- `POST /v1/safety-shares`, `DELETE /v1/safety-shares/{id}`
- `POST /v1/media/uploads`, `POST /v1/media/{id}/complete`
- `POST /v1/media/{id}/moderation-actions` and `POST /v1/media/{id}/reports`
- `POST /v1/exports`; `GET /v1/jobs/{id}`

## Mutation contract

Requests state expected resource version. The server authenticates, authorizes resource scope, validates state transition, executes atomically, appends audit/outbox entries, and returns the canonical resource. A repeated idempotency key with the same payload returns the first result; a different payload returns a conflict.

## Realtime

Channels are tenant and resource scoped, never global. Events carry event ID, type, organization ID, aggregate ID/version, occurred time, and a minimal redacted payload. Subscribers refetch canonical state. Reconnect uses a cursor or full reconciliation. Do not broadcast incident details, consent payloads, precise location, contact data, or minor data.

## Versioning

Additive fields are backward compatible. Breaking changes use a new API version and overlap through the supported client upgrade window. State enums have an unknown-safe client fallback.
