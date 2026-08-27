#!/usr/bin/env bash
#
# One entry point for every gitignored, license-risky asset under
# Resources/mons/ -- normal sprites, shiny sprites, and cries. It is a thin
# orchestrator over the existing per-asset scripts (fetch_sprites.sh,
# pack_normal_sprites.py, pack_shiny_sprites.py, fetch_cries.sh); it does not
# talk to any network or SD-card source itself.
#
#   Scripts/fetch_assets.sh                       # everything, every species
#   Scripts/fetch_assets.sh 1 4 7                 # everything, just these three
#   Scripts/fetch_assets.sh --only sprites        # normal sprites only
#   Scripts/fetch_assets.sh --only shiny,sound    # shiny + cries, no normal
#   Scripts/fetch_assets.sh --only sound 25 25    # just Pikachu's cry
#
# Each underlying script has its own rules about what "fine to fetch, not fine
# to commit" means for that asset -- see README "Sprites" / "Cries" and
# Resources/mons/ being gitignored. Re-running this is always safe: every step
# it calls skips files that already exist.

set -euo pipefail

cd "$(dirname "$0")/.."

only="sprites,shiny,sound"
if [ "${1-}" = "--only" ]; then
  only="${2-}"
  shift 2
fi

want_sprites=0
want_shiny=0
want_sound=0
IFS=',' read -ra kinds <<< "$only"
for k in "${kinds[@]}"; do
  case "$k" in
    sprites) want_sprites=1 ;;
    shiny)   want_shiny=1 ;;
    sound)   want_sound=1 ;;
    *)
      echo "error: unknown --only kind '$k' (want sprites, shiny, sound)" >&2
      exit 2
      ;;
  esac
done

# "all" is the same "every species" whether the caller wrote it out or just
# gave no numbers -- kept as one flag so the branches below only differ in
# whether they loop per-species (a short list) or run once over the full
# range (everything, which the .py packers already do faster as one call
# than 386 separate subprocess starts).
all=1
if [ $# -gt 0 ] && [ "$1" != "all" ]; then
  all=0
fi
[ "${1-}" = "all" ] && shift || true

if [ "$want_sprites" -eq 1 ]; then
  echo "== normal sprites =="
  if [ "$all" -eq 1 ]; then
    Scripts/fetch_sprites.sh all
    python3 Scripts/pack_normal_sprites.py
  else
    Scripts/fetch_sprites.sh "$@"
    for dex in "$@"; do python3 Scripts/pack_normal_sprites.py "$dex" "$dex"; done
  fi
  echo
fi

if [ "$want_shiny" -eq 1 ]; then
  echo "== shiny sprites =="
  if [ "$all" -eq 1 ]; then
    Scripts/fetch_sprites.sh --shiny all
    python3 Scripts/pack_shiny_sprites.py
  else
    Scripts/fetch_sprites.sh --shiny "$@"
    for dex in "$@"; do python3 Scripts/pack_shiny_sprites.py "$dex" "$dex"; done
  fi
  echo
fi

if [ "$want_sound" -eq 1 ]; then
  echo "== cries =="
  if [ "$all" -eq 1 ]; then
    Scripts/fetch_cries.sh all
  else
    Scripts/fetch_cries.sh "$@"
  fi
  echo
fi

echo "$(du -sh Resources/mons 2>/dev/null | cut -f1) in Resources/mons total."
echo "Rebuild to bundle it, or copy Resources/mons into Files -> On My iPhone -> iTamaPoke/mons/."
