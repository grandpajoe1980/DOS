## Summary and requirements

<!-- What user or system outcome changes? Include stable FR/issue IDs. -->

- Requirements:
- Parent issue:

## Files and ownership

<!-- List material paths changed and confirm that another active work packet does not own them. -->

- Files changed:
- Coordinated shared files:

## Decisions and assumptions

<!-- Link an ADR for significant design changes. State assumptions explicitly. -->

## API, data, and migration compatibility

- [ ] No contract, schema, migration, event, or generated-client change
- [ ] Compatible change with versioned fixtures and migration/recovery evidence below
- [ ] Breaking change approved through a new API version and ADR

Details:

## Security and privacy

<!-- Cover tenant/role scope, minors, consent, precise location, media, logging, and secrets as applicable. -->

- [ ] Authorization is server-enforced and affected RLS allow/deny cases pass
- [ ] No credential, personal data, precise location, consent payload, incident text, object key, or private media URL appears in code, fixtures, logs, or analytics
- [ ] New dependencies and permissions are justified and reviewed

## Verification

<!-- Record exact commands and results. Do not write only "tests pass." -->

```text
command:
result:
```

- [ ] Unit/contract tests
- [ ] Integration/RLS/concurrency tests where applicable
- [ ] iOS/web critical-flow tests where applicable
- [ ] Accessibility: VoiceOver/Dynamic Type or keyboard/focus/contrast as applicable
- [ ] Failure, retry, offline, conflict, and permission-denied behavior considered
- [ ] Screenshots attached for perceptible UI changes
- [ ] CI output reviewed for sensitive values

## Rollout, observability, and rollback

- Feature flag/owner/expiry:
- Metrics, alerts, and redaction:
- Rollout:
- Rollback command or procedure:

## Known gaps and follow-up

<!-- Link owned issues. Critical or High security defects block merge. -->

## Reviewer handoff

- Architecture:
- Contract/data/security:
- iOS/web:
- QA/accessibility:
- Release/operations:

