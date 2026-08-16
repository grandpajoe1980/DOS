# Security, privacy, and App Store

## Security baseline

Use threat modeling, least privilege, RLS tests, TLS, managed encryption at rest, Keychain tokens, dependency scanning, secret scanning, secure headers, rate limits, input/output validation, and immutable audit trails. Service keys are server-only and rotated. Logs are structured and redacted. Production access is just-in-time with MFA and recorded reason.

High-risk reviews cover tenant escape, IDOR, invitation takeover, consent forgery, capacity races, signed URL leakage, malicious uploads, notification abuse, precise-location exposure, and offline replay. Security reports have an owned response process.

## Privacy

Maintain a data inventory with purpose, lawful basis, sensitivity, retention, processors, and deletion behavior. Provide clear just-in-time notices for location, photos, notifications, guardianship, and public publication. Support access/export/correction/deletion and guardian requests. Backups expire on schedule; deletion tombstones prevent accidental restoration. Analytics is minimal and cannot reconstruct sensitive journeys.

## App Store release checklist

- Privacy policy and support URL are live and match behavior.
- App Privacy answers include SDK collection and server processing.
- Required-reason APIs and privacy manifests are complete.
- Sign in with Apple is offered when policy requires an equivalent login.
- In-app account deletion initiates deletion without requiring support contact.
- Location/photo/notification purpose strings are specific; permission is requested in context.
- Moderated user content includes filtering, reporting, blocking where applicable, and reachable contact information.
- Review notes and demo credentials make every gated flow testable.
- Accessibility, age rating, export compliance, screenshots, metadata, and data retention are reviewed.
- TestFlight validates candidates; production ships through App Store review.

Legal counsel must approve waiver, guardian, child privacy, retention, and jurisdiction-specific language.
