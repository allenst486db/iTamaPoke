// The Pokédex thumbnail atlas (mons/thumbs.bin), ported from Sources/Shared/
// TPThumbs.swift -- itself translated from TamaPoke by Quique Tortosa, MIT
// licensed: https://github.com/socquique/TamaPoke (sdmon.cpp `SdThumbs`,
// `drawThumb` in TamaPoke.ino). See LICENSE.
//
// One small still per species, all in one file, kept resident: the gallery
// draws 16 at once. A species you haven't registered yet shows as an
// ink-black silhouette, exactly as upstream does -- which is the whole
// reason the grid needs this atlas rather than the full sprites (those are
// only drawn for species you've raised or caught).
//
// Format: "TPTH", u16 count, u32 offset per species; at each offset
// w:u8 h:u8 palCount:u8, pal[palCount]:u16 RGB565, then w*h palette
// indices (0xFF transparent). Stored in the same IndexedDB as the sprites
// under the key "thumbs.bin" (sprites.js's importSpriteFiles accepts it).

let thumbsBytes = null;
let thumbsCount = 0;
const thumbCache = new Map();

function parseThumbs(buf) {
  const b = new Uint8Array(buf);
  if (b.length <= 6 || b[0] !== 0x54 || b[1] !== 0x50 || b[2] !== 0x54 || b[3] !== 0x48) return false;
  const n = b[4] | (b[5] << 8);
  if (6 + n * 4 > b.length) return false;
  thumbsBytes = b;
  thumbsCount = n;
  thumbCache.clear();
  return true;
}

// Re-reads the atlas from the asset store; called at startup and after a
// "Load sprites…" import.
async function refreshThumbs() {
  try {
    const buf = await loadSpriteAsset("thumbs.bin");
    if (buf) parseThumbs(buf); else { thumbsBytes = null; thumbsCount = 0; thumbCache.clear(); }
  } catch (e) {
    console.warn("[thumbs] load failed:", e);
  }
}

function thumbsLoaded() { return thumbsBytes !== null; }

function thumbOffset(dex) {
  if (!thumbsBytes || dex < 1 || dex > thumbsCount) return -1;
  const i = 6 + 4 * (dex - 1);
  const b = thumbsBytes;
  return (b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)) >>> 0;
}

// ImageData for one thumb (real colours, or ink silhouette), cached.
function thumbImageData(dex, silhouette) {
  const key = dex * 2 + (silhouette ? 1 : 0);
  if (thumbCache.has(key)) return thumbCache.get(key);
  const off = thumbOffset(dex);
  const b = thumbsBytes;
  if (off < 0 || off + 3 > b.length) return null;
  const w = b[off], h = b[off + 1], palCount = b[off + 2];
  if (w <= 0 || h <= 0 || palCount <= 0) return null;
  const palStart = off + 3, dataStart = palStart + palCount * 2;
  if (dataStart + w * h > b.length) return null;

  const px = new Uint8ClampedArray(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    const idx = b[dataStart + i];
    if (idx === 0xff || idx >= palCount) continue;
    const c = silhouette ? 0x18C4 : (b[palStart + idx * 2] | (b[palStart + idx * 2 + 1] << 8));
    px[i * 4 + 0] = Math.round(((c >> 11) & 0x1f) * 255 / 31);
    px[i * 4 + 1] = Math.round(((c >> 5) & 0x3f) * 255 / 63);
    px[i * 4 + 2] = Math.round((c & 0x1f) * 255 / 31);
    px[i * 4 + 3] = 255;
  }
  const img = { data: new ImageData(px, w, h), w, h };
  thumbCache.set(key, img);
  return img;
}

// Draws a species' thumb centred in a `box`-sized square at (x, y), scaled
// by whole pixels like PetScreen.swift's drawThumb. Returns false when the
// atlas has no entry, so the caller can fall back.
function drawThumb(dex, x, y, box, silhouette) {
  const t = thumbImageData(dex, silhouette);
  if (!t) return false;
  let s = Math.max(1, Math.floor(box / Math.max(t.w, t.h)));
  const w = t.w * s, h = t.h * s;
  frameCanvas.width = t.w; frameCanvas.height = t.h;
  frameCtx.putImageData(t.data, 0, 0);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(frameCanvas, x + (box - w) / 2, y + (box - h) / 2, w, h);
  return true;
}
