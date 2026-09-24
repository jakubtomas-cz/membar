#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="MemBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -parse-as-library \
    -target arm64-apple-macos14.0 \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/MemBar"

# Ad-hoc signature: enough to run locally, no Developer account needed.
codesign --force --sign - "$APP"

echo "Built $(pwd)/$APP"
