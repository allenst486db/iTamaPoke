#!/usr/bin/env python3
#
# Adds one more language column to upstream-expanded/dex.h's DEX_NAMES table,
# fetched from PokeAPI (https://pokeapi.co) -- species *names* only (short,
# and already committed in six languages for the existing rows), not the
# flavour-text descriptions Scripts/fetch_dex_entries.sh handles, which stay
# gitignored and per-user. Bumps DEX_LANG_COUNT and appends the new row in
# the same "?", NAME, NAME, ... layout as the existing six.
#
#   Scripts/add_dex_lang.py ko KO   # PokeAPI language code, C comment label
#
# Re-run for a different language the same way; running it twice for a
# language already present is not guarded against, so don't.

import json
import re
import sys
import time
import urllib.request

DEX_H = "upstream-expanded/dex.h"
API = "https://pokeapi.co/api/v2/pokemon-species/{}/"


def fetch_name(dex: int, lang: str) -> str:
    req = urllib.request.Request(API.format(dex), headers={"User-Agent": "iTamaPoke-localization-script"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                data = json.load(r)
            break
        except Exception:
            if attempt == 2:
                raise
            time.sleep(1)
    for entry in data.get("names", []):
        if entry.get("language", {}).get("name") == lang:
            return entry["name"]
    raise RuntimeError(f"no '{lang}' name for dex {dex}")


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: add_dex_lang.py <pokeapi-lang-code> <C-comment-label>", file=sys.stderr)
        sys.exit(2)
    pokeapi_lang, label = sys.argv[1], sys.argv[2]

    with open(DEX_H, "r", encoding="utf-8") as f:
        src = f.read()

    m = re.search(r"#define DEX_COUNT (\d+)", src)
    dex_count = int(m.group(1))

    names = ["?"]
    for dex in range(1, dex_count + 1):
        name = fetch_name(dex, pokeapi_lang)
        names.append(name)
        print(f"  . #{dex}: {name}")
        time.sleep(0.2)

    row = "  { " + ", ".join(f'"{n}"' for n in names) + " },\n"

    src = re.sub(r"#define DEX_LANG_COUNT (\d+)",
                 lambda m2: f"#define DEX_LANG_COUNT {int(m2.group(1)) + 1}", src, count=1)

    marker = "\nstatic const int16_t CLASSIC_DEX"
    idx = src.index(marker)
    close_idx = src.rfind("};", 0, idx)
    src = src[:close_idx] + f"  // {label}\n" + row + src[close_idx:]

    with open(DEX_H, "w", encoding="utf-8") as f:
        f.write(src)

    print(f"\nwrote {len(names) - 1} names, bumped DEX_LANG_COUNT, appended '{label}' row to {DEX_H}")


if __name__ == "__main__":
    main()
