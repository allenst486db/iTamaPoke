#!/usr/bin/env bash
#
# Builds Resources/mons/psnd<dex>.m4a -- the cry the Pokedex detail view's
# first page can preview -- from the PokeAPI/cries repo, the same source
# upstream already uses for battle stats (dex.h) and this port already uses
# for the dex entries (fetch_dex_entries.sh).
#
# Resources/mons/ is gitignored on purpose. Cries are Nintendo / Game Freak's
# audio, same rule as the sprites and dex entries: fine to fetch onto your own
# device, not fine to commit or redistribute. See README "Cries".
#
#   Scripts/fetch_cries.sh              # every species
#   Scripts/fetch_cries.sh 1 4 7        # just these three
#   Scripts/fetch_cries.sh all          # every species (same as no args)
#
# A species with no cry file here just hides the play control instead of a
# broken screen, so fetching a subset is a supported state.
#
# PokeAPI/cries ships .ogg, which AVFoundation cannot decode on iOS/watchOS --
# so this converts every clip to .m4a (AAC) with ffmpeg on the way in. Install
# it first: `brew install ffmpeg`.

set -euo pipefail

cd "$(dirname "$0")/.."

DST="Resources/mons"
API="https://pokeapi.co/api/v2/pokemon"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "error: ffmpeg is required to convert .ogg cries to .m4a -- install with: brew install ffmpeg" >&2
  exit 1
fi

if [ "${1-}" = "all" ]; then
  shift
fi

if [ $# -eq 0 ]; then
  # Default to whatever this build's dex holds, read from dex.h rather than
  # repeated here, so extending the dex extends the fetch with it.
  set -- $(seq 1 "$(sed -n 's/^#define DEX_COUNT \([0-9]*\).*/\1/p' upstream-expanded/dex.h)")
fi

mkdir -p "$DST"

tmp_ogg="$(mktemp)"
trap 'rm -f "$tmp_ogg"' EXIT

missing=0
for dex in "$@"; do
  printf -v n '%03d' "$dex"
  out="$DST/psnd$n.m4a"
  if [ -f "$out" ]; then
    printf '  .  #%s (already have it)\n' "$n"
    continue
  fi

  json="$(curl -fsSL --retry 3 --retry-delay 2 "$API/$dex/" 2>/dev/null || true)"
  cry_url="$(printf '%s' "$json" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    cries = data.get("cries") or {}
    print(cries.get("latest") or cries.get("legacy") or "")
except Exception:
    print("")
' 2>/dev/null || true)"

  if [ -z "$cry_url" ]; then
    echo "  !  #$n: no cry listed, skipping" >&2
    missing=$((missing + 1))
    sleep 0.2
    continue
  fi

  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tmp_ogg" "$cry_url" 2>/dev/null; then
    echo "  !  #$n: download failed, skipping" >&2
    missing=$((missing + 1))
    sleep 0.2
    continue
  fi

  if ffmpeg -y -loglevel error -i "$tmp_ogg" -c:a aac -b:a 96k "$out" </dev/null; then
    printf '  .  #%s\n' "$n"
  else
    echo "  !  #$n: ffmpeg conversion failed, skipping" >&2
    rm -f "$out"
    missing=$((missing + 1))
  fi
  sleep 0.2
done

count="$(find "$DST" -maxdepth 1 -name 'psnd*.m4a' | wc -l | tr -d ' ')"
echo
echo "$DST now holds $count cry file(s)"
if [ "$missing" -gt 0 ]; then
  echo "$missing species had no cry or failed to convert -- they hide the play control."
fi
echo "Rebuild to bundle it, or copy it into Files -> On My iPhone -> iTamaPoke/mons/."
