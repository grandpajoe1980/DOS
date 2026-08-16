# Forms and user flows

## Principles

Every field has a visible label, inline error, accessible hint, semantic content type, and server validation. Preserve safe progress, never clear a form after a recoverable failure, identify required fields before submission, and provide a non-map alternative.

## Volunteer flow

1. Open organization page and select an occurrence.
2. Review schedule, work, accessibility, age rules, location precision, and availability.
3. Sign in or create an account.
4. Choose individual or team registration; create/join a team if needed.
5. Add named dependents only as their authenticated guardian.
6. Select site/preferences and disclose only operational accommodations.
7. Review the current waiver; type/sign acceptance and record evidence.
8. Complete separately authenticated guardian consent for every minor.
9. Confirm registration and receive assignment status.
10. On event day view details, get directions, check in/out, complete tasks, and receive announcements.

## Core forms

- **Profile:** preferred/display name, contact channel, locale/time zone, accessibility preferences; date of birth only when policy requires it.
- **Organization:** legal/display names, slug, contacts, branding, time zone, privacy/support links.
- **Event definition:** title, description, eligibility, default waiver version, registration policy.
- **Occurrence:** local schedule plus IANA time zone, registration window, state, public summary.
- **Site:** name, approximate/public location, precise operations address, accessibility, arrival notes, soft target, optional hard safety limit, emergency contact.
- **Registration:** occurrence, participants, team mode, preferences, accommodations, emergency contact, acknowledgements.
- **Consent:** document version/hash, signer identity, signer relationship, participant, timestamp, locale, method, revoked/superseded state.
- **Media:** asset, occurrence/site, caption, participant visibility attestations, moderation state.
- **Incident:** category, severity, description, immediate action, people affected, restricted attachments.

## Organizer flows

Create tenant → invite staff → create reusable event → create occurrence/sites/tasks → preview/publish → monitor registrations → assign → operate attendance/communications → moderate media → publish impact report → archive.

Destructive or externally visible actions require confirmation and show scope. Draft previews must be clearly marked and inaccessible to public indexing.
