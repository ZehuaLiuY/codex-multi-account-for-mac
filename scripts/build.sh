#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/swift-module-cache"

usage() {
    printf 'Usage: %s [--universal | --arch arm64 | --arch x86_64]\n' "$0"
}

case "${1:-}" in
    "") ARCHITECTURES=("$(uname -m)") ;;
    --universal)
        [ "$#" -eq 1 ] || { usage >&2; exit 1; }
        ARCHITECTURES=(arm64 x86_64)
        ;;
    --arch)
        [ "$#" -eq 2 ] || { usage >&2; exit 1; }
        ARCHITECTURES=("$2")
        ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
esac
for architecture in "${ARCHITECTURES[@]}"; do
    case "$architecture" in
        arm64|x86_64) ;;
        *) printf 'Unsupported architecture: %s\n' "$architecture" >&2; exit 1 ;;
    esac
done

BUILD_OPTIONS=(--disable-sandbox --cache-path "$PROJECT_ROOT/.build/cache"
               --config-path "$PROJECT_ROOT/.build/config" --security-path "$PROJECT_ROOT/.build/security" -c release)
mkdir -p "$PROJECT_ROOT/dist"
BUILD_STAGING="$(mktemp -d "$PROJECT_ROOT/dist/.build-app.XXXXXX")"
trap 'rm -rf "$BUILD_STAGING"' EXIT
STAGED_APP="$BUILD_STAGING/Codex Accounts.app"
APP_BUNDLE="$PROJECT_ROOT/dist/Codex Accounts.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
EXECUTABLES=()
for architecture in "${ARCHITECTURES[@]}"; do
    swift build "${BUILD_OPTIONS[@]}" --triple "$architecture-apple-macosx14.0"
    BIN_DIRECTORY="$(swift build "${BUILD_OPTIONS[@]}" --triple "$architecture-apple-macosx14.0" --show-bin-path)"
    EXECUTABLES+=("$BIN_DIRECTORY/CodexAccounts")
done
if [ "${#EXECUTABLES[@]}" -eq 1 ]; then
    cp "${EXECUTABLES[0]}" "$STAGED_APP/Contents/MacOS/CodexAccounts"
else
    lipo -create "${EXECUTABLES[@]}" -output "$STAGED_APP/Contents/MacOS/CodexAccounts"
fi
cp "$PROJECT_ROOT/Resources/Info.plist" "$STAGED_APP/Contents/Info.plist"
cp -R "$BIN_DIRECTORY/CodexAccounts_CodexAccounts.bundle" "$STAGED_APP/Contents/Resources/"
if [ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$STAGED_APP/Contents/Resources/"
fi
codesign --force --sign - "$STAGED_APP"
codesign --verify --strict "$STAGED_APP"
rm -rf "$APP_BUNDLE"
mv "$STAGED_APP" "$APP_BUNDLE"
printf '\nBuilt: %s\n' "$APP_BUNDLE"
printf 'Architectures: %s\n' "$(lipo -archs "$APP_BUNDLE/Contents/MacOS/CodexAccounts")"
