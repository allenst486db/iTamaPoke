#!/usr/bin/env bash
#
# Run as a build phase (see project.yml) so every build has SOME icon, even a
# fresh checkout that never ran fetch_app_icon.sh: without this, the asset
# catalog's "single size" slot has no file at all and Xcode fails the build
# rather than falling back to a system default.
#
# Resources/DefaultAppIcon.png IS committed (it is original art with no
# third-party IP in it — see README "App icon"), unlike AppIcon.png in each
# asset catalog, which stays gitignored. This script copies the default in
# only when nothing has been placed there yet, so running
# Scripts/fetch_app_icon.sh first (your own custom icon) always wins and is
# never overwritten by this phase.

set -euo pipefail

# Run both as a plain script (Scripts/ensure_app_icon.sh) and as an Xcode
# build phase, where $0 is a copy under DerivedData rather than this checkout
# -- SRCROOT is what Xcode guarantees points back at the real project root.
cd "${SRCROOT:-$(dirname "$0")/..}"

DEFAULT="Resources/DefaultAppIcon.png"
[ -f "$DEFAULT" ] || { echo "error: missing $DEFAULT" >&2; exit 1; }

for dst in \
  Sources/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png \
  Sources/watchOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png
do
  if [ ! -f "$dst" ]; then
    cp "$DEFAULT" "$dst"
    echo "iTamaPoke: no custom app icon at $dst -- using the default (see README \"App icon\")"
  fi
done
