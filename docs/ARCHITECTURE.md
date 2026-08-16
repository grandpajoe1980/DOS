# Architecture

## Implemented foundation

DOS is a native iOS application using Swift and SwiftUI. The first vertical slice now supports public event discovery, accessible event detail, registration validation, version-aware waiver acceptance, confirmation, and an idempotent offline attendance queue.

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

## Current boundaries

- The app targets iOS 17 and uses Swift structured concurrency.
- `EventServing` isolates the UI from preview and production HTTP implementations.
- `APIClient` implements the documented JSON, idempotency, status mapping, and ISO-8601 contracts without embedding credentials.
- `OfflineAttendanceQueue` owns deduplication, persistence hooks, and reconciliation. Production must supply encrypted-at-rest persistence (Keychain-protected key) before event-day release.
- Views include loading, empty, retry, validation, and success states and use semantic SwiftUI controls for Dynamic Type and VoiceOver.
- Authentication, live Supabase configuration, guardian web consent, maps, media, notifications, and organizer surfaces remain server/environment-integrated milestones rather than simulated privileged client behavior.

## Local verification

Core behavior is packaged independently of SwiftUI so it can be tested on macOS and Linux with `swift test`. The iOS application files remain directly consumable by an Xcode iOS app target.
