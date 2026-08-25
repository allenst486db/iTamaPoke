#!/usr/bin/env bash
#
# Copies TPK2 sprites out of the pinned upstream checkout into Resources/mons/,
# where the Xcode project picks them up as bundle resources.
#
# Resources/mons/ is gitignored on purpose. The art is Pokemon fan work derived
# from PMD SpriteCollab (CC BY-NC): fine to build onto your own device, not fine
# to commit or redistribute. See README "Legal".
#
#   Scripts/fetch_sprites.sh 7           # one species (Squirtle)
#   Scripts/fetch_sprites.sh 1 4 7       # several
#   Scripts/fetch_sprites.sh all         # every species upstream ships
#   Scripts/fetch_sprites.sh --shiny 7   # include the shiny variant
#
# upstream/ carries the gen-1 151 only. Gen 2-3, and the shiny variants for
# them, are built with Scripts/pack_shiny_sprites.py, which writes into the
# same Resources/mons/ this script fills.
#
# A species with no file here simply falls back to the firmware's own
# "No sprites" notice, so copying a subset is a supported state, not a broken one.

set -euo pipefail

cd "$(dirname "$0")/.."

SRC="upstream/tools/sdcard/mons"
DST="Resources/mons"

if [ ! -d "$SRC" ]; then
  echo "error: $SRC not found -- run: git submodule update --init --recursive" >&2
  exit 1
fi

shiny=0
if [ "${1-}" = "--shiny" ]; then
  shiny=1
  shift
fi

if [ $# -eq 0 ]; then
  echo "usage: $0 [--shiny] <dex-number>... | all" >&2
  exit 2
fi

mkdir -p "$DST"

copy_one() {
  local f="$1"
  if [ -f "$SRC/$f" ]; then
    cp "$SRC/$f" "$DST/$f"
    echo "  $f"
  else
    echo "  $f (not in upstream, skipped)" >&2
  fi
}

if [ "$1" = "all" ]; then
  echo "copying all species -> $DST"
  for f in "$SRC"/p[0-9]*.bin; do
    cp "$f" "$DST/"
  done
  [ "$shiny" -eq 1 ] && cp "$SRC"/ps*.bin "$DST/"
else
  echo "copying -> $DST"
  for dex in "$@"; do
    printf -v n '%03d' "$dex"
    copy_one "p$n.bin"
    [ "$shiny" -eq 1 ] && copy_one "ps$n.bin"
  done
fi

# The Pokedex grid reads this one atlas rather than the per-species files, so it is
# worth having even when only a few species were copied.
if [ -f "$SRC/thumbs.bin" ]; then
  cp "$SRC/thumbs.bin" "$DST/thumbs.bin"
  echo "  thumbs.bin (Pokedex grid)"
fi

echo
echo "$DST now holds $(find "$DST" -name '*.bin' | wc -l | tr -d ' ') sprite(s), $(du -sh "$DST" | cut -f1)"
echo "Regenerate the project so Xcode sees them:  xcodegen generate"
