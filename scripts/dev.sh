#!/usr/bin/env bash
# Carddex dev automation.
#   scripts/dev.sh gen      regenerate the Xcode project from project.yml
#   scripts/dev.sh build    generate + build for the simulator
#   scripts/dev.sh test     generate + run the test suite
#   scripts/dev.sh run      build + install + launch in the simulator
#   scripts/dev.sh shot     run + screenshot to /tmp/carddex.png
#   scripts/dev.sh watch    rebuild on every change (needs fswatch)
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Carddex"
PROJECT="Carddex.xcodeproj"
SIM="${CARDDEX_SIM:-iPhone 17}"
DEST="platform=iOS Simulator,name=${SIM}"
DERIVED="build"
BUNDLE_ID="com.carddex.app"
APP="${DERIVED}/Build/Products/Debug-iphonesimulator/${SCHEME}.app"

gen()  { xcodegen generate >/dev/null && echo "✓ project generated"; }

build() {
  gen
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DEST" -derivedDataPath "$DERIVED" build 2>&1 \
    | grep -iE "error:|warning: .*deprecated|BUILD SUCCEEDED|BUILD FAILED" || true
}

run_tests() {
  gen
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DEST" -derivedDataPath "$DERIVED" test 2>&1 \
    | grep -iE "error:|✔|✘|passed|failed|TEST SUCCEEDED|TEST FAILED" || true
}

launch() {
  build
  xcrun simctl boot "$SIM" 2>/dev/null || true
  open -a Simulator
  xcrun simctl install booted "$APP"
  xcrun simctl launch booted "$BUNDLE_ID"
  echo "✓ launched $BUNDLE_ID"
}

shot() {
  launch
  sleep 2
  xcrun simctl io booted screenshot /tmp/carddex.png && echo "✓ /tmp/carddex.png"
}

watch() {
  build
  if command -v fswatch >/dev/null 2>&1; then
    echo "👀 watching Carddex/ + project.yml (Ctrl-C to stop)…"
    fswatch -o Carddex project.yml | while read -r _; do clear; build; done
  else
    echo "fswatch not found — 'brew install fswatch' to enable auto-rebuild."
  fi
}

case "${1:-build}" in
  gen)   gen ;;
  build) build ;;
  test)  run_tests ;;
  run)   launch ;;
  shot)  shot ;;
  watch) watch ;;
  *) echo "usage: scripts/dev.sh [gen|build|test|run|shot|watch]"; exit 1 ;;
esac
