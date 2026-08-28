#!/usr/bin/env bash
#
# Builds the WASM core (upstream-expanded/*.cpp, untouched, plus this
# folder's platform glue/shims) into browser_ver/web/tp_core.{js,wasm}.
#
# Needs the Emscripten SDK active in this shell first:
#   source /path/to/emsdk/emsdk_env.sh
#
#   browser_ver/build.sh            # release-ish build
#   browser_ver/build.sh --debug    # -O0 -g, assertions on

set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v em++ >/dev/null 2>&1; then
  echo "error: em++ not found -- activate the Emscripten SDK first (source emsdk_env.sh)" >&2
  exit 1
fi

OUT="browser_ver/web/tp_core"
OPT="-O2"
EXTRA=()
if [ "${1-}" = "--debug" ]; then
  OPT="-O0 -g"
  EXTRA+=(-s ASSERTIONS=1 -s SAFE_HEAP=1)
fi

mkdir -p browser_ver/web

em++ -std=c++17 $OPT \
  -I upstream-expanded \
  -I browser_ver/core \
  -I browser_ver/core/shim \
  browser_ver/core/browser_glue.cpp \
  upstream-expanded/pet.cpp \
  upstream-expanded/i18n.cpp \
  upstream-expanded/battle.cpp \
  -s WASM=1 -s MODULARIZE=1 -s EXPORT_NAME=createTPCore \
  -s ENVIRONMENT=web \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","HEAPU8"]' \
  -s EXPORTED_FUNCTIONS='["_malloc","_free"]' \
  "${EXTRA[@]+"${EXTRA[@]}"}" \
  -o "$OUT.js"

echo "wrote $OUT.js / $OUT.wasm"
