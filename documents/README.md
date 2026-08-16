# Day of Service engineering handoff

Version 1.0. This package turns the Day of Service product decisions into implementation contracts for the iPhone app, organizer web console, public web flows, and backend.

## Product baseline

Day of Service is a nationwide, multi-organization platform. Organizations create reusable event programs and dated occurrences, publish service sites, register individuals or teams, collect versioned waivers and guardian consent, coordinate day-of-service work, and share moderated impact media.

## Document map

1. [Product scope](01-product-scope.md)
2. [Decision log](02-decision-log.md)
3. [Roles and permissions](03-roles-and-permissions.md)
4. [Forms and user flows](04-forms-and-user-flows.md)
5. [Functional requirements](05-functional-requirements.md)
6. [System architecture](06-system-architecture.md)
7. [Data model](07-data-model.md)
8. [API and realtime contracts](08-api-and-realtime-contracts.md)
9. [Safety, location, and minors](09-safety-location-and-minors.md)
10. [Media and communications](10-media-and-communications.md)
11. [Security, privacy, and App Store](11-security-privacy-app-store.md)
12. [Testing and quality plan](12-testing-and-quality-plan.md)
13. [Delivery plan](13-delivery-plan.md)
14. [Multi-agent execution](14-multi-agent-execution.md)
15. [Definition of done](15-definition-of-done.md)

## Non-negotiable invariants

- Every tenant-owned row carries an organization identifier and is protected by server-side authorization and PostgreSQL RLS.
- A reusable event definition is distinct from each dated event occurrence.
- Consent is attributable, versioned evidence—not a mutable Boolean.
- Guardians control a minor's participation and visibility; minors never publish media.
- Precise location sharing is voluntary, time-bounded, purpose-limited, and off by default.
- Media is private on upload and becomes public only through the approved moderation lifecycle.
- Secrets and privileged service credentials never ship in a client.
- Public release uses App Store review; TestFlight is only a pre-release channel.

## Suggested implementation order

Establish contracts, migrations, RLS, and generated fixtures first. Build identity/tenant isolation next, then event discovery and registration, day-of-service operations, media, reporting, and hardening. Each vertical slice must include accessibility, analytics, observability, tests, and documentation.
