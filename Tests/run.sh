#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/duogami-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -module-cache-path "$test_dir/cache" \
  Sources/Core/PaperGeometry.swift Sources/Core/Pattern.swift Tests/CoreTests.swift \
  -o "$test_dir/core-tests"
"$test_dir/core-tests"
xcrun swiftc -module-cache-path "$test_dir/cache" -default-isolation MainActor \
  Sources/Core/PaperGeometry.swift Sources/Core/Pattern.swift \
  Sources/Core/WorkshopSession.swift Tests/SessionTests.swift -o "$test_dir/session-tests"
"$test_dir/session-tests"
