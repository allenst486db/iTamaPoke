#!/usr/bin/env python3
"""Packs shiny TPK2 sprites (psNNN.bin) straight into Resources/mons/.

upstream's own tools/pack_pmd.py already knows how to build these -- shiny is
just a different SpriteCollab subfolder (/0000/0001). This wrapper reuses that
packer verbatim and only redirects where it writes, because upstream/ is a
pinned submodule and its tools/sdcard/mons is not ours to fill in.

The gen 2-3 normal sprites in Resources/mons came from that same packer (their
bytes match upstream's own output exactly for every species both have), so the
shiny files this produces are palette- and format-identical siblings, not a
second art pipeline.

  python3 Scripts/pack_shiny_sprites.py            # 1..386
  python3 Scripts/pack_shiny_sprites.py 152 386    # a range
  python3 Scripts/pack_shiny_sprites.py 25 25      # one species

Not every species has a shiny sheet in SpriteCollab. A miss is a supported
state, not a failure: TPSprite.load falls back to the normal sprite, so the
creature still shows up, just not recoloured. Misses are listed at the end.

A shiny sheet can also carry fewer animations than the normal one -- a dozen
species have no shiny Eat or Sit, for instance. That is fine too: every draw
site guards with TPSprite.has() and falls back to Idle, so a shiny of one of
those simply reuses its idle pose where the normal form had a bespoke one.

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
        dest = os.path.join(pack_pmd.OUT, 'ps%03d.bin' % n)
        if os.path.exists(dest):
            had += 1
            continue
        try:
            print('#%03d shiny' % n, flush=True)
            pack_pmd.pack(n, True)
            made += 1
        except Exception as e:
            print('  no shiny sheet: %s' % e, flush=True)
            misses.append(n)
    print('\npacked %d, already present %d, no shiny sheet %d' % (made, had, len(misses)))
    if misses:
        print('missing: ' + ' '.join(str(n) for n in misses))


if __name__ == '__main__':
    main(sys.argv[1:])
