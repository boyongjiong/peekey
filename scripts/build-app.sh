#!/usr/bin/env bash
# Builds a Universal (arm64 + x86_64) Peekey.app into ./build
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/build/Peekey.app"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc; set to "Developer ID Application: ..." for distribution

echo "▸ Building universal release binary…"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Peekey"

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Peekey"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$APP/Contents/Info.plist"

ICNS="$ROOT/build/AppIcon.icns"
if [[ ! -f "$ICNS" || scripts/make-icon.swift -nt "$ICNS" ]]; then
  echo "▸ Rendering icon…"
  TMP="$(mktemp -d)"
  swift scripts/make-icon.swift "$TMP/icon.png" >/dev/null
  ICONSET="$TMP/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$ICNS"
  rm -rf "$TMP"
fi
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Signing ($SIGN_IDENTITY)…"
codesign --force --options runtime --entitlements Resources/Peekey.entitlements --sign "$SIGN_IDENTITY" "$APP"

echo "✓ Built $APP"
lipo -archs "$APP/Contents/MacOS/Peekey"
