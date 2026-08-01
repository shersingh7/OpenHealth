#!/usr/bin/env bash
# Run Foundation-only OpenHealthCore tests without Xcode.
# The default SwiftPM XCBuild system requires a full Xcode install on this host;
# --build-system native works with Apple Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."
swift run --build-system native OpenHealthCoreTests "$@"
