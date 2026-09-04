#!/bin/sh
# Builds ClaudeUsageBar.app into ./dist. Run ./dist/ClaudeUsageBar.app or copy it to /Applications.
set -eu
cd "$(dirname "$0")"
swift build -c release 2>&1 | grep -v "^\[" || true
BIN=$(swift build -c release --show-bin-path)
APP=dist/ClaudeUsageBar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/ClaudeUsageBar" "$APP/Contents/MacOS/"
cp Sources/ClaudeUsageBar/Resources/logo-white.png "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "built $APP"
