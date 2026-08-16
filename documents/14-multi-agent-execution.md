# Multi-agent execution protocol

## Work partitioning

Partition by bounded vertical slices with explicit file ownership: contracts/data, backend policy, iOS, web, media/jobs, quality/security, and documentation. A coordinator owns the dependency graph and integration branch; agents do not edit shared contracts independently.

## Task packet

Every assignment includes objective, source requirements, in/out of scope, owned paths, dependencies, API/schema version, acceptance tests, commands, security/privacy notes, and expected handoff. Unknown product decisions are escalated rather than silently invented.

## Contract-first sequence

1. Propose schema/API/event changes in a small reviewable contract patch.
2. Database/security owner validates constraints and RLS.
3. Client/backend agents implement against shared fixtures.
4. Quality owner runs cross-tenant, failure, accessibility, and compatibility tests.
5. Coordinator integrates only after contract and migration checks pass.

## Coordination rules

One writer per file at a time. Rebase before handoff; do not overwrite another agent's work. Use stable requirement IDs in commits/PRs. Communicate a changed assumption immediately. Generated files name their source and regeneration command. Avoid broad formatting changes.

## Handoff template

- Summary and requirement IDs
- Files changed
- Decisions/assumptions
- Migration/API compatibility
- Security/privacy impact
- Tests with exact commands/results
- Known gaps and rollback

## Completion

An agent is complete only when its owned tests pass, affected docs/contracts are updated, no secrets or debug artifacts remain, and the coordinator can reproduce the result. Integration completion follows the project-wide [definition of done](15-definition-of-done.md).
