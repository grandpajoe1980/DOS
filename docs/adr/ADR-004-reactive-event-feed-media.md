# ADR-004: Publish processed adult uploads to the event feed with reactive quarantine

- Status: Accepted
- Date: 2026-08-16
- Decision owners: Product Owner, Lead Architect, Media/Security owners
- Product decisions: D-005, D-010, D-011
- Requirements: FR-301–FR-305

## Context

Day of Service media is intended to behave like the photo feed of an event
group. An adult's successfully uploaded and processed photo should appear to
event members and organizers without waiting for platform moderation. If an
item is reported, it must disappear immediately pending review; otherwise it
stays visible.

Earlier planning language and the current Swift prototype use one linear media
state that can be read as requiring moderator approval before any audience sees
an upload. That interpretation conflicts with the binding product direction.
It also conflates authenticated event-member visibility with publication to an
anonymous public gallery.

Storage privacy, content processing, event-feed visibility, public-gallery
publication, and report review are different concerns. Making an item visible
in an event feed must not make the underlying R2 object or key public.

## Decision

After upload verification, malware/format checks, metadata stripping, and safe
derivative generation succeed, an upload by a server-verified adult becomes
visible immediately to the authenticated occurrence/event audience and
authorized organizers. No moderator preapproval is required for that event
feed.

Use separate state dimensions:

- `processing_state`: upload pending, scanning/processing, ready, or failed;
- `event_feed_state`: hidden until ready, visible, quarantined, or removed;
- `public_gallery_state`: not published, published, or withdrawn;
- report/review records: append-only reports plus open, restored, rejected, or
  removed review outcomes.

The transition to `processing_state=ready` atomically makes
`event_feed_state=visible` when the uploader is an eligible adult and the item
has not already been reported or removed.

Submitting a valid report atomically changes event-feed visibility to
`quarantined` and public-gallery state to `withdrawn` before returning the
receipt. The review happens afterward. Review may restore the authenticated
event feed, separately authorize anonymous public-gallery publication, keep the
item quarantined, or remove it. An unreported item remains in the event feed.

Anonymous public-gallery publication is a separate organizer/moderator action
and must satisfy subject and guardian visibility policy. It is not implied by
event-feed visibility.

R2 originals and derivatives remain private. Every audience receives only safe
derivatives through an authorization-aware delivery endpoint or short-lived
signed URL. Object keys are never exposed.

## Audience and authority

The event-feed audience is limited to authenticated adults registered for or
assigned to the occurrence and authorized occurrence staff. Exact membership
rules are server derived and deny-by-default. A client cannot declare itself an
adult, an event member, a guardian, or an uploader on another person's behalf.

Minors cannot initiate uploads. An adult may upload a photo containing a minor
only under the subject/guardian visibility rules; that does not make the minor
the uploader. Guardian withdrawal or a qualifying safety/privacy report uses
the same immediate quarantine path.

## Consequences

### Positive

- The feed has the immediate, group-chat-like behavior the product owner wants.
- Reporting removes exposure first and moves investigation off the request
  path.
- Public web publication can remain more selective without slowing the private
  event experience.
- Separate state dimensions avoid invalid combinations hidden by one enum.

### Tradeoffs

- Processing must be fast and observable because it sits before first event
  visibility.
- Reactive moderation allows a processed but objectionable adult upload to be
  visible until reported.
- Report abuse needs rate limits, deduplication, audit, and an appeal/restore
  path without delaying legitimate quarantine.
- Delivery authorization and cache invalidation are more complex than using a
  public bucket.

## Migration and compatibility

There is no production media data. Replace the prototype linear state before
backend or client consumers rely on it. The v1 contract must expose separate
processing, event-feed, and public-gallery state; it must not use the current
`review_pending -> approved -> published` chain as the only visibility path.
If a development database already contains the prototype enum, migrate each row
to explicit state columns with a deterministic mapping and retain moderation
history.

## Privacy and security

- Verify adult uploader eligibility from authenticated server data.
- Keep originals, quarantine inputs, and derivatives private in R2.
- Strip EXIF/GPS and validate MIME, checksum, size, and dimensions/duration
  before visibility.
- Authorize every feed list and delivery request against current event
  membership and current media state.
- Report/quarantine is one atomic, idempotent server transition with audit and
  outbox entries.
- Signed URLs and intermediary caches have bounded expiry; quarantine purges or
  invalidates controlled delivery promptly.
- Realtime only announces a redacted media-state invalidation. It carries no
  image URL, object key, report details, minor identity, or storage metadata.

## Test impact

Automated tests must prove:

- an authenticated adult's safe processed derivative becomes event-visible
  without a moderator action;
- a minor or suspended/unauthorized user cannot request or complete an upload;
- a foreign-tenant or nonmember user cannot list or fetch event media;
- a report immediately prevents subsequent feed and delivery access, including
  concurrent fetch/report races and idempotent report retries;
- review can restore event visibility without implicitly publishing publicly;
- public-gallery reads return only explicitly published derivatives;
- guardian withdrawal and takedown invalidate access within the documented
  cache/signed-URL window; and
- logs, analytics, realtime, errors, and fixtures contain no private media URL,
  object key, GPS metadata, report details, or minor identity.

## Rollout and rollback

Roll out private buckets and the processing pipeline first, then authenticated
feed reads, then the automatic ready-to-visible transition behind a feature
flag. Report/quarantine, delivery invalidation, audit, and alerting are release
prerequisites, not follow-up work.

Rollback disables new uploads and feed publication while preserving uploaded
objects, reports, and audit history privately. Never roll back by making a
bucket public or by bypassing quarantine. Re-enable only after replaying
processing/reconciliation and confirming current visibility state.
