#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'Usage: %s [--universal | --arch arm64 | --arch x86_64]\n' "$0"
    printf 'Builds a universal app by default, then creates DMG, ZIP and SHA-256 checksums in dist/.\n'
    exit 0
fi
if [ "$#" -eq 0 ]; then
    "$PROJECT_ROOT/scripts/build.sh" --universal
else
    "$PROJECT_ROOT/scripts/build.sh" "$@"
fi

APP_BUNDLE="$PROJECT_ROOT/dist/Codex Accounts.app"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
APP_ARCHITECTURES="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/CodexAccounts")"
case "$APP_ARCHITECTURES" in
    "arm64 x86_64"|"x86_64 arm64") PACKAGE_ARCH=universal ;;
    arm64|x86_64) PACKAGE_ARCH="$APP_ARCHITECTURES" ;;
    *) printf 'Unexpected architectures: %s\n' "$APP_ARCHITECTURES" >&2; exit 1 ;;
esac
PACKAGE_NAME="Codex-Accounts-$APP_VERSION-macOS-$PACKAGE_ARCH"
PACKAGE_STAGING="$(mktemp -d "$PROJECT_ROOT/dist/.package.XXXXXX")"
trap 'rm -rf "$PACKAGE_STAGING"' EXIT

# Package the built app, never the source tree or the user's account data.
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$PACKAGE_STAGING/$PACKAGE_NAME.zip"
DMG_CONTENTS="$PACKAGE_STAGING/image"
mkdir -p "$DMG_CONTENTS"
ditto "$APP_BUNDLE" "$DMG_CONTENTS/Codex Accounts.app"
ln -s /Applications "$DMG_CONTENTS/Applications"
hdiutil create -volname 'Codex Accounts' -srcfolder "$DMG_CONTENTS" -fs HFS+ -format UDZO \
    "$PACKAGE_STAGING/$PACKAGE_NAME.dmg"
hdiutil verify "$PACKAGE_STAGING/$PACKAGE_NAME.dmg"
mv "$PACKAGE_STAGING/$PACKAGE_NAME.zip" "$PROJECT_ROOT/dist/"
mv "$PACKAGE_STAGING/$PACKAGE_NAME.dmg" "$PROJECT_ROOT/dist/"
(
    cd "$PROJECT_ROOT/dist"
    shasum -a 256 "$PACKAGE_NAME.zip" "$PACKAGE_NAME.dmg" > "$PACKAGE_NAME.sha256"
)
printf '\nDownload packages:\n  %s\n  %s\n  %s\n' \
    "$PROJECT_ROOT/dist/$PACKAGE_NAME.dmg" "$PROJECT_ROOT/dist/$PACKAGE_NAME.zip" \
    "$PROJECT_ROOT/dist/$PACKAGE_NAME.sha256"
