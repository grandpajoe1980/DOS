# System architecture

## Components

- iOS app: Swift 6, SwiftUI, structured concurrency, MapKit/Core Location, PhotosPicker, UserNotifications, Keychain, and an encrypted minimal offline queue.
- Responsive web: public discovery/registration/guardian flows and authenticated organizer console.
- Supabase: authentication, PostgreSQL/PostGIS, row-level security, realtime change delivery, and narrowly scoped Edge Functions.
- Cloudflare R2: private originals, quarantined processing inputs, and approved derivatives accessed with short-lived signed URLs.
- Workers/jobs: media metadata stripping and transformations, notifications, exports, retention, and reconciliation.
- Observability: structured redacted logs, metrics, traces, crash reports, alerts, and immutable audit events.

## Boundaries

Clients use publishable configuration only. Privileged keys stay in server secret management. The API is the policy boundary for complex mutations; PostgreSQL constraints and RLS remain a backstop. Object keys are opaque. Webhooks are signature-verified, replay-protected, and idempotent.

## Availability and consistency

Registration, assignment, attendance, consent, and moderation transitions use database transactions and idempotency keys. Realtime is an optimization, not the system of record; clients reconcile after reconnect. Offline operations use client operation IDs and surface rejected conflicts.

## Environments and delivery

Development, preview, staging, and production have separate projects, buckets, credentials, and identity callbacks. Schema migrations are forward compatible during deployment and tested against a production-shaped snapshot. Feature flags include owner, expiry, telemetry, and rollback. Infrastructure and policy changes require review.

## Geospatial design

PostGIS stores operational coordinates. Public queries return approximate or policy-approved coordinates. Distance queries are bounded and indexed. User location is processed on-device unless a user explicitly activates Safety Sharing.
