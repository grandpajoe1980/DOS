# Decision log

| ID | Decision | Rationale |
|---|---|---|
| D-001 | Self-service multi-organization product | Avoid city/year forks and support national reuse. |
| D-002 | Separate event templates from dated occurrences | Preserve reusable programming while making schedules immutable and auditable. |
| D-003 | Native Swift/SwiftUI iPhone app plus responsive web surfaces | Optimize volunteer day-of experience while keeping guardian and organizer work accessible. |
| D-004 | Supabase Auth and PostgreSQL/PostGIS | Relational integrity, geospatial queries, realtime, and row-level security. |
| D-005 | Cloudflare R2 for media; store only object keys in Postgres | Private, scalable object delivery with explicit signed access. |
| D-006 | Sign in with Apple and Google; email fallback if required | Accessible identity choices and App Store compliance. |
| D-007 | Versioned, attributable waiver/consent evidence | A Boolean cannot prove who accepted which text and when. |
| D-008 | Teams support `prefer_together` and `must_stay_together` | Assignment needs differ across families, schools, and community groups. |
| D-009 | Published capacity is a soft target; optional site safety limit is hard | Keep registration welcoming without violating physical safety constraints. |
| D-010 | Adult uploads may enter moderation immediately; minors cannot upload | Reduce child-safety and consent risk. |
| D-011 | Reactive takedown remains available after publication | Approval does not eliminate later privacy or safety reports. |
| D-012 | Precise Safety Sharing is voluntary, scoped, and expiring | Location is sensitive and must never become passive surveillance. |
| D-013 | No peer direct messages in v1 | Use organizer-controlled announcements and support channels to reduce abuse risk. |
| D-014 | Public App Store release; TestFlight only for beta | TestFlight is not a production distribution workaround. |

Changes require an ADR that states migration, privacy, security, test, rollout, and rollback effects.
