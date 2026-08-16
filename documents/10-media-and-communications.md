# Media and communications

## Media lifecycle

`draft → uploaded_private → scanning → review_pending → approved|rejected → published → unpublished|removed`.

An adult requests a short-lived, size/type-bound signed upload. The backend records an expected checksum and opaque object key. Completion verifies ownership, checksum, MIME sniffing, dimensions/duration, and malware/format processing. Strip EXIF/GPS, create safe derivatives, and keep originals private. Failed or abandoned uploads expire.

Approval requires tenant scope, subject/guardian visibility policy, and moderator action with reason. Public galleries serve only approved derivatives through a controlled delivery URL. Publication can be reversed immediately after a report, guardian change, or policy decision. Do not use face recognition.

Apple Sensitive Content Analysis may provide on-device intervention where supported, but is defense in depth—not the sole moderation, consent, or child-safety control.

## Communications

V1 supports transactional email/push and organizer-to-audience announcements. Audience selection is role checked and previewed with estimated recipients. Recipient lists and addresses are never disclosed. Store template/version, audience query, requestor, provider message ID, status, and opt-out category.

Emergency notices are clearly labeled and use a dedicated authorized path. Marketing consent is separate. Quiet hours and time zones apply to non-emergency messages. Deep links authenticate before revealing private content.

## Operational controls

Rate limit uploads, reports, invitations, and sends. Prevent duplicate notifications using outbox IDs. Provider webhooks require signatures and replay prevention. Retention jobs delete rejected/abandoned originals and expired signed access; legal holds are explicit and audited.
