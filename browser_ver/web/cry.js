// A species' cry, previewable from the Pokedex detail view. Ported from
// Sources/Shared/TPCry.swift.
//
// Exactly like the sprites and dex entries, this is Nintendo / Game Freak's
// audio, so it is NOT committed to this repository and never fetched: the
// user picks their own `psnd<dex>.m4a` files (what Scripts/fetch_cries.sh
// writes) and they're kept in this browser's own IndexedDB. With no such
// file for a species the play control simply does not appear.
//
// The iOS build reads these through AVAudioPlayer; here they go through the
// same AudioContext audio.js already stands up for the chip-tune effects,
// so there's one audio graph rather than two.

const CRY_DB = "itamapoke-cries";
const CRY_STORE = "cries";

function openCryDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(CRY_DB, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(CRY_STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

// Which dex numbers have a cry stored. Read once at startup (and refreshed
// after an import) so `hasCry` can answer synchronously -- it gates whether
// the button is drawn at all, and that runs inside the render loop.
const cryAvailable = new Set();

async function refreshCryIndex() {
  cryAvailable.clear();
  try {
    const db = await openCryDb();
    const names = await new Promise((res, rej) => {
      const req = db.transaction(CRY_STORE, "readonly").objectStore(CRY_STORE).getAllKeys();
      req.onsuccess = () => res(req.result || []);
      req.onerror = () => rej(req.error);
    });
    for (const name of names) {
      const m = /^psnd(\d{1,3})\./i.exec(String(name));
      if (m) cryAvailable.add(parseInt(m[1], 10));
    }
  } catch { /* no DB yet: nothing installed, every hasCry() is false */ }
  return cryAvailable.size;
}

function hasCry(dex) {
  return cryAvailable.has(dex);
}

// Accepts files named like the iOS build's own mons/psnd<dex>.m4a; anything
// else is skipped, same lenient-filter approach as importSpriteFiles.
async function importCryFiles(files) {
  const db = await openCryDb();
  let n = 0;
  for (const file of files) {
    if (!/^psnd\d{1,3}\.(m4a|mp3|wav|ogg)$/i.test(file.name)) continue;
    const buf = await file.arrayBuffer();
    await new Promise((res, rej) => {
      const tx = db.transaction(CRY_STORE, "readwrite");
      tx.objectStore(CRY_STORE).put(buf, file.name.toLowerCase());
      tx.oncomplete = res;
      tx.onerror = () => rej(tx.error);
    });
    n++;
  }
  cryBufferCache.clear();
  await refreshCryIndex();
  return n;
}

async function loadCryBytes(dex) {
  const db = await openCryDb();
  const base = `psnd${String(dex).padStart(3, "0")}`;
  for (const ext of ["m4a", "mp3", "wav", "ogg"]) {
    const buf = await new Promise((res) => {
      const req = db.transaction(CRY_STORE, "readonly").objectStore(CRY_STORE).get(`${base}.${ext}`);
      req.onsuccess = () => res(req.result || null);
      req.onerror = () => res(null);
    });
    if (buf) return buf;
  }
  return null;
}

// dex -> decoded AudioBuffer (or null once decoding has been tried and
// failed, so a file the browser can't handle isn't re-decoded on every tap).
const cryBufferCache = new Map();

let crySource = null;      // the AudioBufferSourceNode currently playing
let cryPlayingDex = null;
let cryStartedAt = 0;      // audioCtx.currentTime when it started
let cryDuration = 0;

function stopCry() {
  if (crySource) {
    try { crySource.stop(); } catch { /* already ended */ }
    crySource.onended = null;
    crySource = null;
  }
  cryPlayingDex = null;
  cryDuration = 0;
}

// Bound to the same sound-mode setting as every other effect, matching
// TPCry.swift's own guard: OFF (and VIBRATE-only) mutes cries too, since
// this is a preview of the creature rather than narration that should
// survive muting.
async function playCry(dex) {
  if (soundMode !== SOUND_FULL || !hasCry(dex)) return;
  const ctx = ensureCtx();
  stopCry();

  let buf = cryBufferCache.get(dex);
  if (buf === undefined) {
    const bytes = await loadCryBytes(dex);
    if (!bytes) { cryBufferCache.set(dex, null); return; }
    try {
      // decodeAudioData detaches the ArrayBuffer it's handed, so decode a
      // copy -- the stored one has to stay usable for a later replay.
      buf = await ctx.decodeAudioData(bytes.slice(0));
    } catch {
      buf = null;  // container/codec this browser won't take
    }
    cryBufferCache.set(dex, buf);
  }
  if (!buf) return;

  const src = ctx.createBufferSource();
  src.buffer = buf;
  src.connect(ctx.destination);
  src.onended = () => { if (crySource === src) stopCry(); };
  crySource = src;
  cryPlayingDex = dex;
  cryStartedAt = ctx.currentTime;
  cryDuration = buf.duration;
  src.start();
}

/// 0..1 while `dex`'s cry is the one playing, else null -- null also covers
/// "nothing is playing" and "a different species is playing", both of which
/// draw the control at rest. Mirrors TPCryPlayer.progress(forDex:).
function cryProgress(dex) {
  if (cryPlayingDex !== dex || !cryDuration || !audioCtx) return null;
  const t = (audioCtx.currentTime - cryStartedAt) / cryDuration;
  return t < 0 ? 0 : t > 1 ? 1 : t;
}
