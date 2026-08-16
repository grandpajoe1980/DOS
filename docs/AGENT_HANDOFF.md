# Day of Service agent handoff

Checkpoint date: 2026-08-16  
Repository: `grandpajoe1980/DOS`  
GitHub is the authoritative source of truth.

## Read this first

This repository is a tested prototype and engineering foundation, not a
deployable or release-ready product. Do not infer feature completion from the
presence of an OpenAPI operation, Swift model, UI screen, ADR, or migration.
Use the repository definition of done in `docs/TEAM_OPERATING_MODEL.md` and the
release gates in `docs/RELEASE_CHECKLIST.md`.

The detailed body of `docs/IMPLEMENTATION_STATUS.md` is a historical baseline
written before the latest merges. This handoff records the current checkpoint.

## Durable GitHub checkpoint

| Ref | Commit | State | Purpose |
|---|---|---|---|
| `main` before this handoff commit | `e82dab1ba2d694509cee4b2ffb2c7acca7f70b5a` | Integrated | All checkpoint work through merged PR #27 |
| PR #26 / `agent/checkpoint-m000-m010-data-boundary` | `c98131125271ba8e7002a0130356b6a37cbf50d0` | Merged; implementation is still explicitly partial | Complete M000 database boundary plus a deliberately partial, non-site M010 identity/tenancy slice |
| PR #27 / `agent/checkpoint-production-composition` | `dd31012c2afb5285c27de5e014c5ff3c759792a4` | Merged; pull-request CI run 31967683513 was still running at handoff | Explicit app dependency composition and fail-closed non-Debug runtime configuration |

Merged work:

- PR #12: hardened v1 OpenAPI/realtime contracts, 27 fixtures, compatibility
  baseline, validator, and independent boundary tests.
- PR #16: living product, architecture, delivery, security, privacy, test,
  release, human-action, ADR, and authorization-map documentation.
- PR #17: checked-in Xcode project, SwiftPM/iOS CI, environment configuration,
  repository policy, secret scan, and regression tests.

The orchestration ledger is GitHub issue #3. The durable save-point comment is
`#issuecomment-5309262691`.

## What currently works

### Contracts and boundaries

- `contracts/openapi/v1.yaml` contains 60 versioned operations.
- `contracts/schemas/realtime-event.schema.json` defines the redacted realtime
  envelope.
- `contracts/fixtures/manifest.json` contains 27 representative valid and
  invalid fixtures.
- `contracts/baseline/v1-contract-surface.json` is the reviewed compatibility
  boundary. Do not regenerate it merely to silence a breaking-change failure.
- The validator enforces formats, idempotency expectations, request tenant
  exclusion, sensitive-field boundaries, selected policy invariants, and the
  checked compatibility surface.
- The independent Python harness has passed 16 contract/repository assertions.

Contract coverage is interface coverage only. Authentication, RLS, database
transactions, uploads, background jobs, notifications, and feature workflows
remain implementation work.

### Swift and iOS foundation

- The Swift prototype supports event discovery/detail, a limited adult
  registration flow, local validation, an offline attendance-operation queue,
  authorization/allocation/media/Safety Share domain models, and unit tests.
- `DOS.xcodeproj`, its shared scheme, and Debug/Staging/Production configuration
  are checked in.
- Pull-request CI runs repository policy, secret scanning, contract validation,
  SwiftPM tests, iOS simulator tests, Staging and Production builds, and Xcode
  analysis.
- PR #27 removes implicit preview-service composition from production. Debug
  explicitly selects preview dependencies; non-Debug reads
  `DOSAppEnvironment`, `DOSAPIScheme`, and `DOSAPIHost` from the bundle and
  fails closed if the values are missing, unsupported, insecure, placeholder,
  or invalid.

The live API client remains narrow. It does not yet provide authentication,
refresh, full v1 type mapping, production caching, realtime integration, or the
complete server error envelope.

### Database checkpoint

Merged PR #26 contains:

- `20260816000000_m000_platform.sql`: complete checkpoint for extension/schema
  bootstrap, hardened `NOLOGIN`/`NOINHERIT`/`NOBYPASSRLS` roles, revoked default
  privileges, and server-JWT actor derivation. `api_v1` intentionally exposes no
  objects.
- `20260816001000_m010_identity_tenancy.sql`: partial non-site identity/tenancy
  slice with profiles, adult assurances, organizations, memberships,
  organization roles, invitation skeleton, policy helpers, forced RLS, and
  selected integrity guards.

The merged PR #26 work does **not** contain a complete M010 or any M020 work. It
has no site joins, `site_lead`, support grants, complete command/API functions,
seed data, or executable database/RLS tests. Only static validation was
available; the migrations have not been executed against PostgreSQL or
Supabase.

## Binding product and security invariants

- Tenant identity and actor identity are server-derived. Never accept a caller
  selected `organization_id` as authority.
- PostgreSQL/RLS is the authorization source of truth. Client authorization
  helpers are advisory UX only.
- Minor participants require attributable, versioned guardian-consent evidence.
- Minors cannot upload media.
- A processed adult upload becomes visible automatically to authorized
  event/group members; it does not wait for platform preapproval.
- A successful media report atomically quarantines/hides the item before the
  response returns.
- Anonymous public-gallery publication is a separate state and requires its own
  subject/guardian clearance and moderation policy.
- Safety Sharing is explicit, time bounded, limited to an authorized recipient
  in the same occurrence, and revocable.
- Never expose precise operational addresses, private contacts, storage keys,
  upload URLs, EXIF/object metadata, moderation notes, incident details, or
  precise location through public DTOs or realtime payloads.
- The repository is currently public. Use synthetic data only and never commit
  credentials, signing material, real participant records, incidents, private
  media, or precise live location.

## Open release and implementation blockers

| Issue | Priority | Required resolution |
|---|---|---|
| #24 | Critical for anonymous gallery | Model server-resolved media subjects plus adult/guardian publication clearance, evidence, withdrawal behavior, and mixed-subject tests. Do not block the authorized member-feed rule while resolving this. |
| #23 | High for personal export | Resolve whether personal export jobs are actor-scoped or tenant-scoped. The current response requires `organization_id` even when the request cannot select a tenant. Update the contract, authorization map, fixtures, and baseline intentionally. |
| #25 | High for migration ordering | Keep site-scoped membership/invitation joins out of M010. Sites arrive in M030; add site joins/policies only after their tenant-composite foreign keys exist. |
| #18 | Release governance | Repository owner must enable the dependency graph and set Actions variable `DEPENDENCY_GRAPH_ENABLED=true`, prove a High-severity dependency is rejected, then remove the warning-only fallback. |
| #22 | Release governance | PR #12 is now integrated. Repository owner must set Actions variable `CONTRACTS_REQUIRED=true`, prove deleting the validator fails CI, and eventually remove the deferral path. |

Issues #20 and #21 have contract fixes and regressions in merged PR #12 but were
still open at handoff. Verify their acceptance criteria against `main`, then
close them rather than reimplementing the fixes.

Broader open work remains in #7–#11 and #14–#15. There is no deployed backend,
hosted authentication, organizer web app, media-processing pipeline,
notification provider, production observability, or release configuration.

## Recommended continuation order

1. Inspect PR #27's final CI result and the next `main` CI run. The narrow
   composition checkpoint is merged, but do not close all of #8; secure
   auth/session storage, complete contract mapping, cache/realtime, navigation,
   and UI automation remain.
2. Resolve #23 and #24 as explicit contract/architecture decisions. Update the
   OpenAPI contract, fixtures, compatibility baseline only when deliberately
   approved, `DATA_AUTHORIZATION_MAP.md`, ADRs, and tests together.
3. Start the next database branch from current `main`. Execute the merged
   M000/M010 checkpoint in an isolated local Supabase/PostgreSQL environment.
   Add seed data and adversarial two-tenant RLS tests before treating any
   database slice as complete.
4. Correct #25 in the migration plan, finish the non-site M010 command/API
   boundary, and keep later-context tables/functions out until their migrations.
5. Implement M020 idempotency, HMAC handling, audit, outbox, dead-letter, and
   reconciliation as a separate reviewed slice. Exclude unresolved personal
   export and media semantics.
6. Extend iOS from the accepted v1 fixtures and implement live authentication
   only after server-derived membership/role enforcement exists.
7. Keep the test engineer and independent auditor active on cross-tenant,
   concurrency, offline/retry, accessibility, privacy, and abuse cases.
8. Complete human-owned setup in `docs/HUMAN_ACTION_REQUIRED.md` before hosted
   staging, real-user data, TestFlight, or release.

## Validation commands

Run from a fresh clone. Do not rely on the prior transient workspace.

```bash
python3 -m pip install -r contracts/requirements.txt
PYTHONDONTWRITEBYTECODE=1 python3 contracts/validate_contracts.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py' -v
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/ci -p 'test_*.py' -v
python3 scripts/ci/check_repository_policy.py
python3 scripts/ci/check_secrets.py
swift test --parallel -Xswiftc -warnings-as-errors
bash scripts/ci/xcode_ci.sh
```

The Swift/Xcode commands require the macOS/Xcode environment pinned by CI. The
database checkpoint additionally requires PostgreSQL/Supabase tooling and new
runtime tests; no successful database execution is claimed in this handoff.

## Human actions and secrets

`docs/HUMAN_ACTION_REQUIRED.md` is the owner-action source of truth. The two
immediate repository controls are #18 and #22. Apple enrollment, domain/brand,
Supabase/Cloudflare ownership, identity-provider setup, legal/privacy/media and
retention decisions, App Store configuration, and physical-device pilots are
later human gates.

Never ask the owner to paste passwords, tokens, private keys, certificates,
provisioning profiles, recovery codes, real participant data, or private media
into chat, issues, pull requests, or source control.

## Copy/paste prompt for the next delivery agent

> Resume the Day of Service App from `grandpajoe1980/DOS`. Read
> `docs/AGENT_HANDOFF.md`, `docs/PRODUCT_REQUIREMENTS.md`,
> `docs/ARCHITECTURE.md`, `docs/DATA_AUTHORIZATION_MAP.md`, all ADRs,
> `docs/TEST_STRATEGY.md`, `docs/SECURITY_AND_PRIVACY.md`, and issue #3 before
> changing code. Treat GitHub as authoritative. Verify `main`, merged PRs #26
> and #27, open issues, and CI before assigning work. Preserve the binding media,
> tenant, guardian-consent, Safety Share, and public-data invariants. Do not call
> the product complete; continue from the recommended order and maintain living
> docs, tests, review evidence, and the human-action register with every slice.

## Handoff completion statement

All completed work from the orchestration session is durably represented by
`main` or GitHub issue/documentation artifacts.
Nothing in the transient workspace is required to reconstruct the current
project state.
