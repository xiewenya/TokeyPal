#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/.build/app/TokeyPal.app"

cd "$ROOT"
swift test
swift build
"$ROOT/scripts/build-app.sh" >/dev/null

test -x "$APP_DIR/Contents/MacOS/TokeyPal"
test -f "$APP_DIR/Contents/Info.plist"
test -f "$APP_DIR/Contents/Resources/tokeypal-mac_TokeyPalNativeApp.bundle/BrandIcons/brand-claude.png"
test -x "$APP_DIR/Contents/Resources/bin/ccusage"
test -d "$APP_DIR/Contents/Resources/assets/start"
test -d "$APP_DIR/Contents/Resources/data/t-rex"

echo "TokeyPal smoke checks passed."
