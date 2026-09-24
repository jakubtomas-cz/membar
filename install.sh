#!/bin/bash
# Builds MemBar and installs it to /Applications, replacing any previous copy.
# Use when you've settled on a version; build.sh is for day-to-day iteration.
set -euo pipefail
cd "$(dirname "$0")"

DEST="/Applications/MemBar.app"

./build.sh

# Quit every running copy (the dev build and the installed one).
pkill -f 'MemBar.app/Contents/MacOS/MemBar' 2>/dev/null || true
sleep 1

rm -rf "$DEST"
ditto MemBar.app "$DEST"

# The app re-registers Launch at login on startup if you had it on.
open "$DEST"
echo "Installed and launched $DEST"
