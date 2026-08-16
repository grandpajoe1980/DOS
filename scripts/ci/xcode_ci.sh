#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "xcode_ci.sh requires macOS with Xcode 16.4 or newer." >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

destination="platform=iOS Simulator,name=iPhone 16 Pro,OS=latest"
common=(
  -project DOS.xcodeproj
  -scheme DOS
  CODE_SIGNING_ALLOWED=NO
  COMPILER_INDEX_STORE_ENABLE=NO
)

echo "Running iOS unit tests on the named simulator destination."
xcodebuild "${common[@]}" \
  -configuration Debug \
  -destination "$destination" \
  test

echo "Building the staging configuration."
xcodebuild "${common[@]}" \
  -configuration Staging \
  -destination "generic/platform=iOS Simulator" \
  build

echo "Building the fail-closed production configuration."
xcodebuild "${common[@]}" \
  -configuration Production \
  -destination "generic/platform=iOS Simulator" \
  build

echo "Running the Xcode static analyzer."
xcodebuild "${common[@]}" \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  analyze

