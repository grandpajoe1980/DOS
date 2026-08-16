# Day of Service

Day of Service is a multi-organization platform for discovering, registering
for, operating, and measuring community service events. The native iPhone app
is written in Swift 6 and SwiftUI. Responsive public, guardian, and organizer
web surfaces and the Supabase/PostgreSQL backend are separate delivery
milestones.

The repository currently contains an iOS preview vertical slice and testable
domain core. Production authentication, backend integrations, web surfaces, and
environment provisioning are not yet implemented.

## Requirements

- macOS with Xcode 16.4 or newer
- An installed iOS 17 or newer simulator runtime
- Swift 6, included with the supported Xcode toolchain
- Python 3.10 or newer when validating API contracts

CI uses the `macos-15` runner and the named `iPhone 16 Pro` simulator
destination. No Apple Developer membership, signing certificate, or provisioning
profile is required for simulator verification.

## Repository structure

```text
DOS/                 iOS application and Swift domain source
DOSTests/            Swift unit tests shared by SwiftPM and Xcode
DOSUITests/          empty UI-test target reserved for future critical-flow tests
DOS.xcodeproj/       committed Xcode project and shared DOS scheme
Configuration/       non-secret Debug, Staging, and Production xcconfig files
contracts/           versioned OpenAPI, realtime schemas, and fixtures
docs/                living architecture and delivery documentation
documents/           original product and engineering handoff
scripts/ci/          local/CI verification commands
.github/             pull-request workflow, review map, and templates
```

## Fresh-clone verification

Run from the repository root.

### Platform-independent checks

```bash
python3 scripts/ci/check_repository_policy.py
python3 scripts/ci/check_secrets.py
bash scripts/ci/validate_contracts.sh
```

Contract validation creates an isolated virtual environment under the runner's
temporary directory and installs the exact versions in
`contracts/requirements.txt`. Before the contract package is integrated, the
contract command reports that validation is deferred and exits successfully.

### Swift package tests

```bash
swift test --parallel -Xswiftc -warnings-as-errors
```

`Package.swift` intentionally excludes SwiftUI app and preview files so domain,
validation, networking, and persistence seams remain testable independently.

### iOS simulator build, test, and analysis

The complete CI-equivalent Apple check is:

```bash
bash scripts/ci/xcode_ci.sh
```

Its underlying named simulator test command is:

```bash
xcodebuild \
  -project DOS.xcodeproj \
  -scheme DOS \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  test \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO
```

The script also builds Staging and Production for a generic iOS Simulator and
runs `xcodebuild analyze`. Open `DOS.xcodeproj` and select the shared `DOS`
scheme for interactive development.

## Build configurations

| Configuration | Compilation condition | Bundle identifier | API host |
|---|---|---|---|
| Debug | `DEBUG` | `org.dayofservice.app.debug` | `api-debug.dayofservice.invalid` |
| Staging | `STAGING` | `org.dayofservice.app.staging` | `api-staging.dayofservice.invalid` |
| Production | `PRODUCTION` | `org.dayofservice.app` | `api.dayofservice.invalid` |

The `.invalid` hosts are deliberate fail-closed placeholders. API hosts are
non-secret build configuration and can be supplied with an approved environment
later. Credentials, private keys, Supabase service-role keys, signing material,
and provider tokens must never be placed in `.xcconfig`, Info.plist, source,
fixtures, workflow files, or build logs.

The generated Info.plist exposes only:

- `DOSAppEnvironment`
- `DOSAPIScheme`
- `DOSAPIHost`

Production application composition must reject missing or `.invalid`
configuration; it must never fall back to preview data.

## Xcode project maintenance

The Xcode project is committed, not generated. This avoids an additional
project-generator dependency in clean checkouts and CI. When adding or moving a
Swift source or resource, update its project reference and target membership in
`DOS.xcodeproj/project.pbxproj` in the same pull request. Keep identifiers and
ordering stable and avoid unrelated project-file reformatting.

The shared scheme maps tests and normal launches to Debug, profiling and
archives to Production, and permits explicit Staging builds. Build settings
shared by all targets remain in `Configuration/*.xcconfig` rather than being
duplicated in user-specific Xcode data.

## Pull-request gates

Every pull request to `main` runs:

- foundation script syntax, repository policy, and redacted credential-pattern
  scanning;
- OpenAPI, JSON Schema, and contract fixture validation when contracts exist;
- GitHub dependency review, blocking High and Critical findings;
- SwiftPM tests with compiler warnings treated as errors;
- iOS simulator tests on `iPhone 16 Pro`;
- Staging and fail-closed Production simulator builds; and
- Xcode static analysis.

GitHub Actions are pinned to full commit SHAs. CI checks out without persisting
credentials and does not consume repository secrets. Scanners report only a
rule and file location; they do not print matched credential values.

Use `.github/PULL_REQUEST_TEMPLATE.md` to record requirement IDs, exact test
commands/results, security and privacy impact, compatibility, rollout,
observability, known gaps, and rollback. Review responsibilities are defined in
`.github/CODEOWNERS` and `.github/REVIEW_MAP.md`.

## Foundation rollback

This foundation has no production state. Rollback consists of reverting the
Xcode project, configuration, workflow, repository-policy scripts, and README
patch together. Do not roll back a failing security check by broadening
permissions, adding secrets, disabling RLS, or suppressing the finding.
