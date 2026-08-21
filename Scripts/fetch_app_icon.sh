#!/usr/bin/env bash
#
# Copies an app icon image into both targets' asset catalogs, REPLACING
# whatever icon is there now -- including the default mascot icon
# (Resources/DefaultAppIcon.png, committed, generic, no third-party IP) that
# Scripts/ensure_app_icon.sh puts there automatically when nothing else has
# been set. Running this script is what changes the app icon away from that
# default; there is no separate "activate my icon" step.
#
# Like Resources/mons/, a Pokemon character image here is fan art: fine to
# build onto your own device, not fine to commit or redistribute. The
# AppIcon.png destinations stay gitignored for exactly that reason, so your
# custom icon never accidentally gets committed -- only Resources/
# DefaultAppIcon.png (the generic one) is tracked. See README "App icon".
#
#   Scripts/fetch_app_icon.sh path/to/icon.png
#
# The source must be a single square image, ideally 1024x1024 -- Xcode's
# "single size" App Icon derives every smaller size from it at build time,
# so nothing else needs generating. It may have an alpha channel; iOS/watchOS
# mask their own rounded-corner shape over it regardless.

set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -ne 1 ]; then
  echo "usage: $0 path/to/icon.png" >&2
  exit 2
fi

SRC="$1"
[ -f "$SRC" ] || { echo "error: no such file: $SRC" >&2; exit 1; }

W=$(sips -g pixelWidth "$SRC" 2>/dev/null | awk '/pixelWidth/{print $2}')
H=$(sips -g pixelHeight "$SRC" 2>/dev/null | awk '/pixelHeight/{print $2}')
if [ "$W" != "$H" ]; then
  echo "warning: $SRC is ${W}x${H}, not square -- Xcode will letterbox or reject it" >&2
fi
if [ "$W" -lt 1024 ] 2>/dev/null; then
  echo "warning: $SRC is ${W}px -- 1024x1024 is what Xcode expects to downscale from" >&2
fi

for dst in \
  Sources/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png \
  Sources/watchOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png
do
  cp "$SRC" "$dst"
  echo "  $dst"
done

echo
echo "Regenerate the project so Xcode sees it:  xcodegen generate"
