// TPK2 sprite reader + local asset store. Ports Sources/Shared/TPSprite.swift
// (itself translated from TamaPoke's sdmon.h/.cpp -- see that file's own
// header) to JS, and adds the piece the Swift side gets for free from the
// Documents/mons folder: a local file picker into IndexedDB, since a web
// page has no filesystem of its own to read `mons/` from. See README
// "Asset loading" / roadmap step 5. Sprites are never bundled or fetched
// from anywhere by this file -- same "not distributed" rule as the iOS
// build; see the root LICENSE and NOTICE.

const TPAct = {
  idle: 0, walkL: 1, walkR: 2, sleep: 3, eat: 4, hurt: 5,
  attack: 6, pose: 7, hop: 8, nod: 9, breath: 10, sit: 11,
};

// --- TPK2 parsing ---------------------------------------------------------
//
// "TPK2" | nActs:u8 | palCount:u16 | pal[palCount]:u16 (RGB565)
// per action: id:u8 w:u8 h:u8 frames:u8 | ms[frames]:u16 | w*h*frames bytes
// Pixels are palette indices; 0xFF is transparent. Mirrors TPSprite.swift's
// `init?(data:)` exactly, including its bounds checks.
function parseTPK2(buf) {
  const b = new Uint8Array(buf);
  if (b.length < 7 || b[0] !== 0x54 || b[1] !== 0x50 || b[2] !== 0x4b || b[3] !== 0x32) {
    return null; // not "TPK2"
  }
  const nActs = b[4];
  const pc = b[5] | (b[6] << 8);
  if (pc <= 0 || pc > 256 || 7 + pc * 2 > b.length) return null;

  const palette = new Uint8Array(pc * 4);
  for (let i = 0; i < pc; i++) {
    const c = b[7 + i * 2] | (b[8 + i * 2] << 8);
    palette[i * 4 + 0] = Math.round(((c >> 11) & 0x1f) * 255 / 31);
    palette[i * 4 + 1] = Math.round(((c >> 5) & 0x3f) * 255 / 63);
    palette[i * 4 + 2] = Math.round((c & 0x1f) * 255 / 31);
    palette[i * 4 + 3] = 255;
  }

  const actions = new Array(12).fill(null);
  let p = 7 + pc * 2;
  for (let n = 0; n < nActs; n++) {
    if (p + 4 > b.length) break;
    const id = b[p], w = b[p + 1], h = b[p + 2], nf = b[p + 3];
    p += 4;
    if (id >= actions.length || w <= 0 || h <= 0 || nf <= 0 || nf > 24 ||
        p + nf * 2 + w * h * nf > b.length) {
      return null; // truncated/foreign file -- no partial sprite
    }

    const ms = new Array(nf);
    for (let k = 0; k < nf; k++) ms[k] = b[p + k * 2] | (b[p + k * 2 + 1] << 8);
    p += nf * 2;

    const offset = p;
    p += w * h * nf;

    // Lowest row carrying a pixel in any frame -- see TPSpriteAction.base.
    let base = 1;
    for (let f = 0; f < nf; f++) {
      const fr = offset + f * w * h;
      for (let r = h - 1; r >= 0; r--) {
        let hasPixel = false;
        for (let x = 0; x < w; x++) {
          if (b[fr + r * w + x] !== 0xff) { hasPixel = true; break; }
        }
        if (hasPixel) { base = Math.max(base, r + 1); break; }
      }
    }

    actions[id] = { w, h, frames: nf, base, ms, offset };
  }

  if (!actions.some((a) => a !== null)) return null;
  return { blob: b, palette, palCount: pc, actions };
}

// Upstream's `pmdFrameAt`, bounded against an all-zero ms[] (a hand-made
// file could produce one, which would otherwise spin forever).
function frameIndexAt(a, elapsedMs, loop) {
  const total = a.ms.reduce((s, v) => s + v, 0) || 100;
  if (!loop && elapsedMs >= total) return a.frames - 1;
  let t = elapsedMs % total;
  let i = 0, steps = 0;
  while (t >= a.ms[i]) {
    t -= a.ms[i];
    i = (i + 1) % a.frames;
    steps++;
    if (steps > a.frames) return 0;
  }
  return i;
}

// One frame as an ImageData, cached per (action, frame) on the sprite object.
function frameImageData(sprite, actId, frame) {
  const a = sprite.actions[actId];
  if (!a || frame < 0 || frame >= a.frames) return null;
  sprite._cache = sprite._cache || new Map();
  const key = actId * 256 + frame;
  if (sprite._cache.has(key)) return sprite._cache.get(key);

  const { w, h } = a;
  const px = new Uint8ClampedArray(w * h * 4);
  const src = a.offset + frame * w * h;
  for (let i = 0; i < w * h; i++) {
    const idx = sprite.blob[src + i];
    if (idx === 0xff || idx >= sprite.palCount) continue;
    px[i * 4 + 0] = sprite.palette[idx * 4 + 0];
    px[i * 4 + 1] = sprite.palette[idx * 4 + 1];
    px[i * 4 + 2] = sprite.palette[idx * 4 + 2];
    px[i * 4 + 3] = 255;
  }
  const img = new ImageData(px, w, h);
  sprite._cache.set(key, img);
  return img;
}

// Same whole-pixel zoom rule as TPSprite.scale(for:max:).
function spriteScale(sprite, a, maxS = 5) {
  const idleH = sprite.actions[TPAct.idle] ? sprite.actions[TPAct.idle].h : 0;
  let s = idleH > 0 ? Math.floor(170 / idleH) : maxS;
  s = Math.min(Math.max(s, 2), maxS);
  while (s > 2 && a.h * s > 250) s--;
  return s;
}

// --- Local asset store (IndexedDB) ----------------------------------------
//
// Stands in for the iOS build's Documents/mons folder + TPMonsSource -- a
// web page has no filesystem to read `mons/p004.bin` from, so the user
// picks the files once (multi-select, not `webkitdirectory` -- unreliable
// on iOS Safari) and they're kept here across reloads.

const ASSET_DB = "itamapoke-assets";
const ASSET_STORE = "sprites";

function openAssetDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(ASSET_DB, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(ASSET_STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

// Accepts any FileList/array of File named like upstream's own sprite
// files (p<dex>.bin, ps<dex>.bin for shiny) -- same names Scripts/
// fetch_sprites.sh writes into mons/ on the iOS side. Anything else is
// skipped rather than rejected outright, so a folder-select with mixed
// content still picks up what it can.
async function importSpriteFiles(files) {
  // Read every file (async) *before* opening the transaction: IndexedDB
  // auto-commits a transaction as soon as control returns to the event
  // loop with no pending request on it, so an `await` inside the
  // transaction loop below would silently close it after the first file.
  const entries = [];
  for (const f of files) {
    const m = /^(ps?)(\d{1,3})\.bin$/i.exec(f.name);
    if (!m) continue;
    entries.push([f.name.toLowerCase(), await f.arrayBuffer()]);
  }
  if (entries.length === 0) return 0;

  const db = await openAssetDb();
  const tx = db.transaction(ASSET_STORE, "readwrite");
  const store = tx.objectStore(ASSET_STORE);
  for (const [name, buf] of entries) store.put(buf, name);
  await new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  return entries.length;
}

async function loadSpriteAsset(name) {
  const db = await openAssetDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(ASSET_STORE, "readonly");
    const req = tx.objectStore(ASSET_STORE).get(name);
    req.onsuccess = () => resolve(req.result || null);
    req.onerror = () => reject(req.error);
  });
}

async function assetCount() {
  const db = await openAssetDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(ASSET_STORE, "readonly");
    const req = tx.objectStore(ASSET_STORE).count();
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

// Mirrors TPSprite.load(dex:shiny:)'s fallback: try the shiny file first
// when asked, then the normal one, cached in memory per dex/shiny pair for
// the session (parsing is cheap but no need to redo it every species swap).
const spriteCache = new Map();

async function loadSprite(dex, shiny) {
  const cacheKey = `${dex}:${shiny ? 1 : 0}`;
  if (spriteCache.has(cacheKey)) return spriteCache.get(cacheKey);

  const dexStr = String(dex).padStart(3, "0");
  const names = shiny ? [`ps${dexStr}.bin`, `p${dexStr}.bin`] : [`p${dexStr}.bin`];
  let sprite = null;
  for (const name of names) {
    const buf = await loadSpriteAsset(name);
    if (!buf) continue;
    sprite = parseTPK2(buf);
    if (sprite) break;
  }
  spriteCache.set(cacheKey, sprite);
  return sprite;
}
