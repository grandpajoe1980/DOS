# DOS

Day of Service (DOS) is a native Apple application project.

## Technology

- Swift
- SwiftUI
- Xcode
- Git / GitHub

## Repository structure

```text
DOS/
├── DOS/                 # Application source
│   ├── DOSApp.swift     # SwiftUI application entry point
│   ├── Views/           # Screens and reusable views
│   ├── Models/          # Domain and data models
│   ├── Services/        # API, persistence, authentication, integrations
│   ├── Utilities/       # Shared helpers and extensions
│   └── Resources/       # App resources that are not managed in Assets.xcassets
├── DOSTests/            # Unit tests
├── DOSUITests/          # UI tests
├── docs/                # Architecture and development notes
├── .gitignore
└── LICENSE
```

## Getting started

1. Clone this repository on a Mac with Xcode installed.
2. In Xcode, create a new **iOS App** project named `DOS` using **SwiftUI** and **Swift**.
3. Save the Xcode project at the repository root so `DOS.xcodeproj` sits beside this README.
4. Use the existing `DOS/` source directory as the app source structure rather than creating a second nested source tree.
5. Commit the generated Xcode project and asset catalog.

## Initial architecture

The first layer intentionally separates UI, models, services, utilities, and resources while avoiding premature framework choices. Business logic and external integrations should be added only as requirements become clear.

Sensitive credentials, API keys, signing material, and environment-specific secrets must not be committed to this repository.
