# Functional requirements

Requirements use stable identifiers for implementation and tests.

## Identity and tenancy

- **FR-001:** Users can authenticate with configured providers and manage sessions.
- **FR-002:** Tenant selection and every tenant mutation are authorization checked.
- **FR-003:** Owners can invite, expire, revoke, and role-scope members.
- **FR-004:** Users can export and request deletion of eligible personal data.

## Events and registration

- **FR-101:** Organizers manage reusable events, occurrences, sites, shifts, tasks, eligibility, and publish state.
- **FR-102:** Public discovery exposes only published, non-sensitive fields.
- **FR-103:** Adults can register individually or in teams and state togetherness constraints.
- **FR-104:** The allocator respects hard safety limits, eligibility, accessibility, shift overlap, and `must_stay_together`; soft targets may be exceeded.
- **FR-105:** Waitlist and assignment transitions are atomic, idempotent, auditable, and communicated.
- **FR-106:** Every required participant has valid evidence for the active document versions before confirmation.

## Operations

- **FR-201:** Authorized leads can view assigned rosters and check participants in/out.
- **FR-202:** Scan/manual check-in is idempotent and supports an offline queue with conflict feedback.
- **FR-203:** Organizers publish targeted announcements without exposing recipient lists.
- **FR-204:** Users can open directions in a chosen maps application without enabling background tracking.
- **FR-205:** Voluntary Safety Sharing expires automatically and visibly indicates active sharing.
- **FR-206:** Incident records are restricted, append-audited, and excluded from normal analytics.

## Media and reporting

- **FR-301:** Adult users obtain short-lived upload authorization for validated media.
- **FR-302:** New objects remain private through processing/moderation.
- **FR-303:** Moderators approve, reject, redact, unpublish, and record reason codes.
- **FR-304:** Guardians control minor visibility; a minor cannot be an uploader.
- **FR-305:** Approved galleries use transformed derivatives and never reveal storage keys or EXIF location.
- **FR-401:** Organizers view/export attendance, hours, tasks, and impact aggregates with privacy thresholds.
