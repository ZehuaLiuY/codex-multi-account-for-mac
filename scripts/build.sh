#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/swift-module-cache"
swift build --disable-sandbox --cache-path "$PROJECT_ROOT/.build/cache" --config-path "$PROJECT_ROOT/.build/config" --security-path "$PROJECT_ROOT/.build/security" -c release
BIN_DIRECTORY="$(swift build --disable-sandbox --cache-path "$PROJECT_ROOT/.build/cache" --config-path "$PROJECT_ROOT/.build/config" --security-path "$PROJECT_ROOT/.build/security" -c release --show-bin-path)"
APP_BUNDLE="$PROJECT_ROOT/dist/Codex Accounts.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIRECTORY/CodexAccounts" "$APP_BUNDLE/Contents/MacOS/CodexAccounts"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp -R "$BIN_DIRECTORY/CodexAccounts_CodexAccounts.bundle" "$APP_BUNDLE/Contents/Resources/"
if [ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi
codesign --force --sign - "$APP_BUNDLE"
printf '\nBuilt: %s\n' "$APP_BUNDLE"
