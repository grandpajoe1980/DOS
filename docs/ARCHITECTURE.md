# Architecture

## Current direction

DOS begins as a native iOS application using Swift and SwiftUI.

The initial source layout separates concerns without locking the project into a large architectural framework before requirements are known:

- **Views** — SwiftUI screens and reusable presentation components.
- **Models** — domain entities and data-transfer models.
- **Services** — networking, persistence, authentication, notifications, and external integrations.
- **Utilities** — focused shared helpers and extensions.
- **Resources** — non-code application resources not managed by the asset catalog.

## Initial principles

1. Keep views focused on presentation and user interaction.
2. Keep credentials and privileged operations out of the client application.
3. Put external-system communication behind service interfaces.
4. Introduce additional patterns such as view models, repositories, dependency injection, or coordinators only when application complexity requires them.
5. Favor Apple platform APIs and Swift concurrency for new native code unless a requirement justifies another dependency.

## Next architectural decisions

These should be decided from actual product requirements rather than assumed during scaffolding:

- supported iOS versions and device classes
- authentication method
- backend/API architecture
- local/offline persistence requirements
- notification requirements
- ServiceNow or other enterprise integrations
- accessibility and localization requirements
- analytics and observability
- deployment model and App Store/TestFlight/enterprise distribution
