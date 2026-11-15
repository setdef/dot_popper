#!/bin/bash
# Builds ios/store_check, the test of the iOS store (Store.swift) against
# StoreKit's local test session, and its tests, as the commit at HEAD holds
# them, for the Simulator, on a Mac with Xcode and XcodeGen
# (mise.ios.toml):
#
#   MISE_ENV=ios mise install                           # once
#   MISE_ENV=ios mise exec -- script/ios_store_check.sh
#
# It runs `xcodebuild build-for-testing` and runs no test, so it needs no
# Simulator: it shows that the real ios/host/Host/Store.swift and the
# tests compile with this Xcode. Running them (`xcodebuild test` on a
# Simulator, doc/design/store-and-pro.md) is by hand, and no CI job runs
# either. Everything is built in a temporary folder that is deleted at the
# end. Written for macOS's own bash 3.2 and tools.
set -euo pipefail

[ $# = 0 ] || { echo "usage: script/ios_store_check.sh" >&2; exit 2; }
[ "$(uname -s)" = Darwin ] || { echo "script/ios_store_check.sh builds on a Mac" >&2; exit 2; }
for tool in xcodebuild xcodegen; do
  command -v "$tool" > /dev/null || { echo "no $tool here: MISE_ENV=ios mise install (mise.ios.toml), and Xcode" >&2; exit 2; }
done

repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/dot_popper-store-check.XXXXXX")
trap 'rm -rf "$work"' EXIT
started=$(date +%s)
say() { echo "[$(($(date +%s) - started)) s] $*"; }
say "commit $(git -C "$repo" rev-parse --short HEAD), $(xcodebuild -version | head -1), XcodeGen $(xcodegen --version 2>&1 | tail -1 | sed 's/^Version: //')"

git -C "$repo" archive HEAD ios | tar -x -C "$work"
cd "$work/ios/store_check"
xcodegen generate --quiet
log=$work/xcodebuild.log
xcodebuild -project StoreCheck.xcodeproj -scheme StoreCheck -sdk iphonesimulator -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$work/derived" build-for-testing CODE_SIGNING_ALLOWED=NO > "$log" 2>&1 || { tail -60 "$log"; exit 1; }
grep -q "TEST BUILD SUCCEEDED" "$log" || { tail -20 "$log"; exit 1; }
grep -c "warning:" "$log" | sed 's/$/ warnings (the log is deleted with the folder)/' || true
say "script/ios_store_check.sh: the store check and its tests built (not run)"
