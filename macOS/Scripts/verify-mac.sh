#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then echo 'Install full Xcode and select it in Xcode → Settings → Locations.'; exit 1; fi
xcodebuild -project LockIn.xcodeproj -scheme LockIn -configuration Debug -derivedDataPath Build build
swift test
if command -v node >/dev/null; then for test_file in Tests/*.test.js; do node "$test_file"; done; fi
printf '\nBuild and core checks finished. Open Build/Build/Products/Debug/LockIn.app\n'
