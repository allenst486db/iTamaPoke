// Hand-drawn pixel icons and their palette, ported from
// Sources/Shared/TPIcon.swift -- which is itself translated from TamaPoke by
// Quique Tortosa, MIT licensed: https://github.com/socquique/TamaPoke
// (species.h's SPR_ICON_*/SPR_HEART/SPR_POOP glyph maps, and TamaPoke.ino's
// `drawMap`). See LICENSE.
//
// Not species art or Pokemon likenesses -- these are the firmware's own UI
// glyphs (berries, a candy, a heart, a poop), MIT-licensed like the rest of
// the engine, so unlike the sprites they ship with the page.
//
// Every glyph map here is byte-for-byte the iOS build's: row/column order and
// each character match species.h exactly. Keep it that way -- the whole point
// of this build is looking like the iOS app, and these are the one piece of
// art that *can* be identical rather than merely equivalent.

// species.h's `spriteColor`: one character per palette entry, shared by every
// icon below. RGB565 like every colour constant upstream, converted once
// through the same rgb565() main.js uses for the UI palette.
const ICON_PALETTE_565 = {
  k: 0x18C4, w: 0xFFFF, y: 0xFED2, Y: 0xE5CC, o: 0xF427, O: 0xD2E5,
  r: 0xEA87, R: 0xB184, f: 0xFECB, t: 0x8EB6, T: 0x5D71, g: 0x5DCD,
  G: 0x3C49, d: 0x3BEC, p: 0xF454, P: 0xC2F0, b: 0x7E3D, B: 0x4C98,
  N: 0x3B74, M: 0x2A8F, c: 0xB3C8, C: 0x7AA6, l: 0x9D5C, L: 0x6BF7,
  s: 0xAD97, S: 0x7BF1,
};
// Converted on first draw, not at load: this file is parsed before main.js,
// where rgb565() lives, so a top-level conversion loop would throw during
// script load (and leave every icon colourless).
let ICON_PALETTE = null;
function iconPalette() {
  if (!ICON_PALETTE) {
    ICON_PALETTE = {};
    for (const ch in ICON_PALETTE_565) ICON_PALETTE[ch] = rgb565(ICON_PALETTE_565[ch]);
  }
  return ICON_PALETTE;
}

const TPIcon = {
  food: [
    "................",
    "................",
    "...........k....",
    "........k.kk....",
    "........k.......",
    ".......krk......",
    ".....kkrrrkk....",
    "....krwrrrrrk...",
    "....kwrrrrrrk...",
    "...krrrrrrrrRk..",
    "...krrrrrrrrRk..",
    "....krrrrrrrk...",
    "....krrrrrrRk...",
    ".....kkRRRkk....",
    ".......kkk......",
    "................",
  ],
  play: [
    "................",
    "................",
    ".......kkk......",
    ".....kkrrrkk....",
    "....krrrrrrrk...",
    "...krrrrrrrrrk..",
    "...krrrrrrrrrk..",
    "..krrrrkkkrrrRk.",
    "..kkkkkkwkkkkkk.",
    "..krrwwkkkwwrRk.",
    "...kwwwwwwwwwk..",
    "...kwwwwwwwwYk..",
    "...kwwwwwwwwYk..",
    "....kwwwwwwYk...",
    ".....kkkkkkk....",
    "................",
  ],
  light: [
    "................",
    "................",
    "................",
    "......kk....f...",
    "....kkk.........",
    "....kfk......f..",
    "...kffk.........",
    "...kffk.........",
    "...kfffk........",
    "...kffffk.......",
    "...kfffffkk.kk..",
    "....kffffffkk...",
    "....kkfffffkk...",
    "......kkkkk.....",
    "................",
    "................",
  ],
  clean: [
    "................",
    "................",
    "................",
    "...kk......kkk..",
    "...kk.....kwbbk.",
    "...kk.....kbbbk.",
    "......kkk..kkk..",
    "....kkbbbkk.....",
    "...kbwbbbbbk....",
    "...kbbwbbbBk....",
    "...kbbbbbbbk....",
    "...kbbbbbbBk....",
    "...kbbbbbbBk....",
    "....kkBBBkk.....",
    "......kkk.......",
    "................",
  ],
  berryBlue: [
    "................",
    "................",
    "...........k....",
    "........k.k.....",
    "........k.......",
    ".......kbk......",
    ".....kkbbbkk....",
    "....kbwbbbbbk...",
    "....kwbbbbbbk...",
    "...kbbbbbbbbBk..",
    "...kbbbbbbbbBk..",
    "....kbbbbbbbk...",
    "....kbbbbbbBk...",
    ".....kkBBBkk....",
    ".......kkk......",
    "................",
  ],
  berryGreen: [
    "................",
    "................",
    "...........k....",
    "........k.k.....",
    "........k.......",
    ".......kgk......",
    ".....kkgggkk....",
    "....kgwgggggk...",
    "....kwggggggk...",
    "...kggggggggGk..",
    "...kggggggggGk..",
    "....kgggggggk...",
    "....kggggggGk...",
    ".....kkGGGkk....",
    ".......kkk......",
    "................",
  ],
  candy: [
    "................",
    "................",
    "................",
    "................",
    "................",
    "......kkkkk.....",
    "..k..kpwpppk.k..",
    "...kkpwpppppk...",
    "..kpppppPppPpk..",
    "...kkppppPpPk...",
    "..k..kppppPk.k..",
    "......kkkkk.....",
    "................",
    "................",
    "................",
    "................",
  ],
  poop: [
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................k...............",
    ".................k..............",
    "...............kkk..............",
    "..............kccck.............",
    ".............kccccck............",
    "..............kccck.............",
    "..............kCCCk.............",
    "............kkccccckk...........",
    "............kccccccck...........",
    "...........kccccccccCk..........",
    "............kccccccck...........",
    "............kcccccCCk...........",
    "...........kccCCCCCcck..........",
    "..........kccccccccccck.........",
    "..........kccccccccccCk.........",
    ".........kcccccccccccCCk........",
    "..........kccccccccccCk.........",
    "..........kcccccccccCCk.........",
    "...........kkkcCCCCkkk..........",
    "..............kkkkk.............",
    "................................",
    "................................",
    "................................",
  ],
  heart: [
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "........krrrrk....krrrrk........",
    ".......krrrrrrk..krrrrrrk.......",
    "......krrrrrrrrrrrrrrrrrrk......",
    ".....krrrrrrrrrrrrrrrrrrrrk.....",
    ".....krrwwrrrrrrrrrrrrrrRrk.....",
    ".....krwwrrrrrrrrrrrrrrRRrk.....",
    "......krrrrrrrrrrrrrrrrrrk......",
    ".......krrrrrrrrrrrrrrrrk.......",
    "........krrrrrrrrrrrrrrk........",
    ".........krrrrrrrrrrrrk.........",
    "..........krrrrrrrrrrk..........",
    "...........krrrrrrrrk...........",
    "............krrrrrrk............",
    ".............krrrrk.............",
    "..............krrk..............",
    "...............kk...............",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
  ],
};

// Port of upstream's `drawMap` / GraphicsContext.drawIcon: one fillRect per
// non-transparent pixel, scaled by whole pixels, (x, y) at the top-left
// corner. `silhouette` paints every pixel ink-black -- the evolution-flash
// effect reuses the same function this way. Rows are batched into runs of
// the same colour so a 32x32 heart is a few dozen fills, not a thousand.
function drawIcon(map, x, y, scale, silhouette = false) {
  const pal = iconPalette();
  for (let r = 0; r < map.length; r++) {
    const row = map[r];
    let c = 0;
    while (c < row.length) {
      const ch = row[c];
      if (ch === ".") { c++; continue; }
      let run = c + 1;
      while (run < row.length && row[run] === ch) run++;
      const col = silhouette ? UI.ink : pal[ch];
      if (col) {
        ctx.fillStyle = col;
        ctx.fillRect(x + c * scale, y + r * scale, (run - c) * scale, scale);
      }
      c = run;
    }
  }
}
