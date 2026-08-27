#!/usr/bin/env python3
"""Packs normal TPK2 sprites (pNNN.bin) straight into Resources/mons/.

Sibling to pack_shiny_sprites.py, same reasoning: upstream's tools/pack_pmd.py
already knows how to build these from PMD SpriteCollab, this wrapper just
redirects where it writes. `upstream/` (the pinned submodule) only carries the
gen-1 151 -- Scripts/fetch_sprites.sh copies those straight off disk, no
network needed. This script is for gen 2-3 (152-386), which the submodule
does not carry, so they have to be built the same way the shiny ones are.

  python3 Scripts/pack_normal_sprites.py            # 1..386
  python3 Scripts/pack_normal_sprites.py 152 386    # gen 2-3 only
  python3 Scripts/pack_normal_sprites.py 25 25      # one species

Running this over 1-151 too is harmless -- it skips any pNNN.bin that already
exists, so it will not touch what fetch_sprites.sh already put there.

Resources/mons/ is gitignored -- the art is CC BY-NC fan work, fine to build
onto your own device, not fine to commit or redistribute. See README "Legal".
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'upstream', 'tools'))

import pack_pmd  # noqa: E402

pack_pmd.OUT = os.path.join(ROOT, 'Resources', 'mons')
pack_pmd.CACHE = os.path.join(ROOT, 'build_spritecache')


def dex_count():
    src = open(os.path.join(ROOT, 'upstream-expanded', 'dex.h')).read()
    m = re.search(r'^#define DEX_COUNT\s+(\d+)', src, re.M)
    return int(m.group(1))


def main(argv):
    lo = int(argv[0]) if argv else 1
    hi = int(argv[1]) if len(argv) > 1 else (int(argv[0]) if argv else dex_count())
    misses, made, had = [], 0, 0
    for n in range(lo, hi + 1):
        dest = os.path.join(pack_pmd.OUT, 'p%03d.bin' % n)
        if os.path.exists(dest):
            had += 1
            continue
        try:
            print('#%03d normal' % n, flush=True)
            pack_pmd.pack(n, False)
            made += 1
        except Exception as e:
            print('  no sprite sheet: %s' % e, flush=True)
            misses.append(n)
    print('\npacked %d, already present %d, no sheet %d' % (made, had, len(misses)))
    if misses:
        print('missing: ' + ' '.join(str(n) for n in misses))


if __name__ == '__main__':
    main(sys.argv[1:])
