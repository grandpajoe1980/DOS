# Day of Service living documentation

These documents describe the application as it exists and the delivery controls
required to make it deployable. The source requirements and original product
handoff remain under `documents/`; accepted ADRs and this directory record later
clarifications and implementation decisions.

## Product and delivery

- [Product requirements](PRODUCT_REQUIREMENTS.md) — normalized requirements,
  invariants, and requirement-to-work/test traceability.
- [Roadmap](ROADMAP.md) — milestones, dependencies, prioritized backlog, and
  currently parallel work.
- [Implementation status](IMPLEMENTATION_STATUS.md) — evidence-based snapshot of
  what is implemented, partial, blocked, or under review.
- [Team operating model](TEAM_OPERATING_MODEL.md) — role ownership, handoffs,
  path ownership, review independence, and anti-stalling rules.

## Engineering and assurance

- [Architecture](ARCHITECTURE.md) — system boundaries, modules, trust boundaries,
  data flow, conventions, and implementation packets.
- [Test strategy](TEST_STRATEGY.md) — test layers, adversarial matrices,
  commands, evidence, and release policy.
- [Security and privacy](SECURITY_AND_PRIVACY.md) — threat model, controls, risk
  register, and review cadence.
- [Release checklist](RELEASE_CHECKLIST.md) — staged build, security, privacy,
  accessibility, operations, beta, and production gates.

## Decisions and owner actions

- [Architecture decision records](adr/) — significant decisions, status,
  compatibility, security, tests, rollout, and rollback.
- [Human action required](HUMAN_ACTION_REQUIRED.md) — consolidated account,
  legal, policy, pilot, and release work that cannot be completed by agents.

Update the implementation status and requirement traceability whenever a pull
request changes observable behavior. A feature is not complete because a model,
contract, or user interface exists; it must pass the repository's definition of
done and applicable release gates.
