#!/bin/bash
#
# Builds Caffeinum.app. No Xcode required - SwiftPM plus a hand-assembled bundle.
#
#   ./scripts/build-app.sh                release build, arm64
#   CONFIGURATION=debug ./scripts/build-app.sh
#   VERSION=1.2.3 ./scripts/build-app.sh  stamp the bundle with a version
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Caffeinum"
CONFIGURATION="${CONFIGURATION:-release}"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

# Apple silicon only. Asking for the arch explicitly keeps the bundle the same
# whichever Mac it is built on.
BUILD_ARGS=(--configuration "$CONFIGURATION" --arch arm64)

echo "==> Building ($CONFIGURATION, arm64)"
swift build "${BUILD_ARGS[@]}"
BINARY="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/$APP_NAME"

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# The checked-in Info.plist carries a placeholder version; released builds are
# stamped with the tag they were built from. BUILD_NUMBER wants to be something
# that only ever goes up - the release workflow passes the commit count.
if [[ -n "${VERSION:-}" ]]; then
	SHORT_VERSION="${VERSION#v}"
	BUILD_NUMBER="${BUILD_NUMBER:-${SHORT_VERSION%%-*}}"
	echo "==> Stamping version $SHORT_VERSION ($BUILD_NUMBER)"
	/usr/libexec/PlistBuddy \
		-c "Set :CFBundleShortVersionString $SHORT_VERSION" \
		-c "Set :CFBundleVersion $BUILD_NUMBER" \
		"$APP/Contents/Info.plist" >/dev/null
fi

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
