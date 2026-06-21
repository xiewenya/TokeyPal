#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/.build/app/TokeyPal.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT"

# Universal (arm64 + Intel) build so the app runs on both Apple Silicon and Intel Macs.
swift build -c release --product TokeyPalNative --arch arm64 --arch x86_64

# Multi-arch builds emit the merged universal products under a separate path
# (.build/apple/Products/Release), NOT .build/release (which points at the host
# arch slice). Resolve it via --show-bin-path so we always copy the universal binary.
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/TokeyPalNative" "$MACOS_DIR/TokeyPal"
cp -R "$ROOT/Resources/." "$RESOURCES_DIR/"
# SwiftPM 资源包(品牌图标 / onboarding 资源)放入 Resources/,
# Bundle.module 会经 Bundle.main.resourceURL 定位 <Package>_<Target>.bundle。
cp -R "$BIN_DIR/tokeypal-mac_TokeyPalNativeApp.bundle" "$RESOURCES_DIR/"
chmod +x "$MACOS_DIR/TokeyPal"
chmod +x "$RESOURCES_DIR/bin/ccusage"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>TokeyPal</string>
  <key>CFBundleExecutable</key>
  <string>TokeyPal</string>
  <key>CFBundleIdentifier</key>
  <string>local.tokeypal.mac</string>
  <key>CFBundleIconFile</key>
  <string>TokeyPal</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>TokeyPal</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
