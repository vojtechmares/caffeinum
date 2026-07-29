#!/bin/bash
#
# Builds Caffeinum.app. No Xcode required - SwiftPM plus a hand-assembled bundle.
#
#   ./scripts/build-app.sh              release build for this Mac's architecture
#   CONFIGURATION=debug ./scripts/build-app.sh
#   UNIVERSAL=1 ./scripts/build-app.sh  arm64 + x86_64
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Caffeinum"
CONFIGURATION="${CONFIGURATION:-release}"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

BUILD_ARGS=(--configuration "$CONFIGURATION")
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
	BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi

echo "==> Building ($CONFIGURATION)"
swift build "${BUILD_ARGS[@]}"
BINARY="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/$APP_NAME"

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Rendering icon"
ICONSET="$DIST/AppIcon.iconset"
rm -rf "$ICONSET"
if swift "$ROOT/scripts/make-icon.swift" "$ICONSET" >/dev/null 2>&1 &&
	iconutil --convert icns "$ICONSET" --output "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null; then
	rm -rf "$ICONSET"
else
	echo "    (skipped - icon rendering failed, the app still runs)"
	rm -rf "$ICONSET"
fi

# Ad-hoc signature. SMAppService (launch at login) refuses to register an
# unsigned bundle, and macOS re-uses the signature to recognise the app across
# rebuilds without re-prompting for permissions.
echo "==> Signing (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 ||
	echo "    (codesign failed - launch at login may not work)"

echo "==> Built $APP"
