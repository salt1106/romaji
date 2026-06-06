#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/Romaji.app"
INSTALL_APP="/Applications/Romaji.app"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/Romaji" "$APP/Contents/MacOS/Romaji"
cp "$ROOT/App/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/App/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
SIGNING_IDENTITY="${ROMAJI_SIGNING_IDENTITY:--}"
codesign --force --deep --sign "$SIGNING_IDENTITY" --identifier jp.romaji.Romaji "$APP"
rm -rf "$INSTALL_APP"
ditto "$APP" "$INSTALL_APP"

echo "$INSTALL_APP"
