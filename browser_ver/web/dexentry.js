// Pokedex entry text, ported from Sources/Shared/TPDexEntryText.swift.
// Nintendo's writing, so -- exactly like sprites -- it is never bundled or
// fetched: the user picks their own `dex_entries_<lang>.txt` (one file per
// PokeAPI language code, format `<dex>|<text>` per line, `#`-prefixed and
// blank lines ignored) and it's kept in this browser's own IndexedDB.

const DEXENTRY_DB = "itamapoke-dexentries";
const DEXENTRY_STORE = "text";

// Same 8-slot -> PokeAPI language code mapping as TPDexEntryText's
// langCodeForSlot -- slots 6 ("KR") and 7 ("kr") both read Korean text.
const DEXENTRY_LANG_FOR_SLOT = ["es", "en", "fr", "de", "it", "pt", "ko", "ko"];

let dexEntryCache = {}; // langCode -> { dex: text }

function openDexEntryDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DEXENTRY_DB, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(DEXENTRY_STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

function parseDexEntryText(raw) {
  const out = {};
  for (const rawLine of raw.split("\n")) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const sep = line.indexOf("|");
    if (sep < 0) continue;
    const dex = parseInt(line.slice(0, sep).trim(), 10);
    const text = line.slice(sep + 1).trim();
    if (!Number.isNaN(dex) && text) out[dex] = text;
  }
  return out;
}

// Accepts files named like the iOS build's own mons/dex_entries_<lang>.txt
// (Scripts/fetch_dex_entries.sh writes these); anything else is skipped.
async function importDexEntryFiles(files) {
  const entries = [];
  for (const f of files) {
    const m = /^dex_entries_([a-z]{2})\.txt$/i.exec(f.name);
    if (!m) continue;
    const lang = m[1].toLowerCase();
    const text = await f.text();
    entries.push([lang, text]);
  }
  if (entries.length === 0) return 0;

  const db = await openDexEntryDb();
  const tx = db.transaction(DEXENTRY_STORE, "readwrite");
  const store = tx.objectStore(DEXENTRY_STORE);
  for (const [lang, text] of entries) store.put(text, lang);
  await new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  for (const [lang, text] of entries) dexEntryCache[lang] = parseDexEntryText(text);
  return entries.length;
}

async function loadDexEntryLang(lang) {
  if (dexEntryCache[lang]) return dexEntryCache[lang];
  try {
    const db = await openDexEntryDb();
    const text = await new Promise((resolve, reject) => {
      const tx = db.transaction(DEXENTRY_STORE, "readonly");
      const req = tx.objectStore(DEXENTRY_STORE).get(lang);
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => reject(req.error);
    });
    const table = text ? parseDexEntryText(text) : {};
    dexEntryCache[lang] = table;
    return table;
  } catch (e) {
    console.warn("[dexentry] load failed:", e);
    dexEntryCache[lang] = {};
    return {};
  }
}

// Synchronous lookup against whatever's already cached -- dex.js kicks off
// loadDexEntryLang() when the detail screen opens and just redraws once it
// resolves, same pattern ensureSprite() already uses for sprites.
function dexEntryFor(dex) {
  const lang = DEXENTRY_LANG_FOR_SLOT[fns.language()] || "en";
  const table = dexEntryCache[lang];
  if (!table) { loadDexEntryLang(lang); return null; }
  return table[dex] || null;
}
