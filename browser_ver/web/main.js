// Idle-screen MVP: ports the layout/tap logic of the idle branch of
// Sources/Shared/PetScreen.swift + the four action buttons -- no sprites,
// minigames, dex, battle, or settings yet. See browser_ver/README.md.

const rgb565 = (u16) => {
  const r = (u16 >> 11) & 0x1f, g = (u16 >> 5) & 0x3f, b = u16 & 0x1f;
  const r8 = Math.round(r * 255 / 31), g8 = Math.round(g * 255 / 63), b8 = Math.round(b * 255 / 31);
  return `rgb(${r8},${g8},${b8})`;
};

// Mirrors TPGraphics.swift's TP/UI enums.
const TP = { screen: 466, cx: 233, cy: 233, petGround: 304, btnHalf: 26 };
const UI = {
  bgDay: rgb565(0xF77C), bgNight: rgb565(0x10C5),
  ink: rgb565(0x2946), inkNight: rgb565(0xDEFE),
  track: rgb565(0xDE97), barOK: rgb565(0x5DCD),
  barWarn: rgb565(0xED07), barBad: rgb565(0xEA87), white: "#fff",
};

// Same four buttons as PetScreen.swift's `Self.buttons`, in the same order:
// feed / play / light(sleep toggle) / clean.
const BUTTONS = [
  { x: 140, y: 390, label: "FEED", action: () => Module._tp_feed_berry(0) },
  { x: 202, y: 404, label: "PLAY", action: () => { screen = "gamemenu"; } },
  { x: 264, y: 404, label: "LIGHT", action: () => Module._tp_toggle_light() },
  { x: 326, y: 390, label: "CLEAN", action: () => Module._tp_clean() },
];

const canvas = document.getElementById("tp");
const ctx = canvas.getContext("2d");
const statusEl = document.getElementById("status");

let Module = null;
let fns = {};

// idle | settings | gamemenu | game -- ports PetScreen.swift's `screen`
// enum, reduced to the states this MVP has. No swipe gesture yet (see
// roadmap): the gear button and the PLAY button are the only ways in.
let screen = "idle";
let lastFrameT = 0;

// --- Sprite state ----------------------------------------------------
//
// `currentSprite` is the parsed TPK2 for whatever species is currently
// active, refetched (from IndexedDB, see sprites.js) whenever the species
// changes -- `loadingDex` guards against a slow load racing a species
// change and clobbering the wrong sprite in. `poseStart` anchors the idle
// animation's own clock, mirroring GameModel's `pose.elapsedMs`.
let currentSprite = null;
let currentDex = 0;
let loadingDex = 0;
let poseStart = 0;

async function ensureSprite(dex) {
  if (dex === currentDex || dex === loadingDex) return;
  loadingDex = dex;
  const sprite = await loadSprite(dex, false);
  if (loadingDex !== dex) return; // species changed again while awaiting
  currentSprite = sprite;
  currentDex = dex;
  poseStart = performance.now();
}

function roundRect(x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function isNight() {
  const h = new Date().getHours();
  return h < 6 || h >= 20;
}

function drawBar(x, y, label, value) {
  const bx = x + 48, bw = 100, bh = 15;
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 13px monospace";
  ctx.textBaseline = "middle";
  ctx.fillText(label, x, y + bh / 2);
  ctx.fillStyle = UI.track;
  roundRect(bx, y, bw, bh, 4);
  ctx.fill();
  const fill = value >= 50 ? UI.barOK : (value >= 25 ? UI.barWarn : UI.barBad);
  const fw = (bw - 4) * value / 100;
  if (fw > 0) {
    ctx.fillStyle = fill;
    roundRect(bx + 2, y + 2, fw, bh - 4, 3);
    ctx.fill();
  }
}

// Scratch canvas for one frame's ImageData -- ctx.drawImage can't take an
// ImageData directly, so each frame is stamped onto this at native size,
// then blitted onto the main canvas scaled with smoothing off (same look
// as TPSprite's `.interpolation(.none)` on iOS).
const frameCanvas = document.createElement("canvas");
const frameCtx = frameCanvas.getContext("2d");

/// Draws the idle pose standing on TP.petGround, or the "no sprite loaded"
/// placeholder when nothing's been picked yet for this species. Ports the
/// idle branch of PetScreen.swift's drawPet -- no walk/eat/sleep poses or
/// evolution FX yet, just the one animated action.
function drawPet(ink) {
  if (!currentSprite) {
    ctx.font = "bold 64px monospace";
    ctx.fillStyle = ink;
    ctx.fillText("?", TP.cx, TP.petGround - 100);
    ctx.font = "12px monospace";
    ctx.fillText("(no sprite loaded for this species)", TP.cx, TP.petGround - 40);
    return;
  }
  const a = currentSprite.actions[TPAct.idle];
  if (!a) return;
  const elapsed = performance.now() - poseStart;
  const frame = frameIndexAt(a, elapsed, true);
  const img = frameImageData(currentSprite, TPAct.idle, frame);
  if (!img) return;

  const s = spriteScale(currentSprite, a);
  const w = a.w * s, h = a.h * s;
  const x = TP.cx - w / 2;
  const y = TP.petGround - (a.base > 0 ? a.base : a.h) * s;

  frameCanvas.width = a.w;
  frameCanvas.height = a.h;
  frameCtx.putImageData(img, 0, 0);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(frameCanvas, x, y, w, h);
}

// Same 8-slot picker as PetScreen.swift's langCodes/isDexKorean, kept in
// the same order since it's also the raw index tp_set_language() expects.
const LANG_CODES = ["ES", "EN", "FR", "DE", "IT", "PT", "KR", "kr"];
const SND_PILL = { x: 34, y: 296, w: 96, h: 30 };
const LANG_PILL = { x: 336, y: 296, w: 96, h: 30 };
const SND_LABELS = ["OFF", "VIB", "ALL"]; // ports soundModeLabel's S_SND_OFF/VIB/FULL order

function inRect(x, y, r) {
  return x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;
}

/// Ports renderSettings(): same title/clock/sound-pill/language-pill/back-hint
/// layout, minus the clock-setting dial (iOS reads the device clock already,
/// same as PetScreen.swift's own comment explains -- there's even less to
/// set here since the browser has no RTC to disagree with).
function drawSettings() {
  ctx.fillStyle = UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "center";
  ctx.font = "bold 22px monospace";
  ctx.fillText(fns.settingsTitle(), TP.cx, 52);

  const now = new Date();
  const clock = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
  ctx.font = "bold 56px monospace";
  ctx.fillText(clock, TP.cx, 148);
  ctx.font = "13px monospace";
  ctx.fillStyle = UI.track;
  ctx.fillText(Intl.DateTimeFormat().resolvedOptions().timeZone, TP.cx, 214);

  const full = soundMode === SOUND_FULL;
  ctx.fillStyle = full ? UI.barOK : UI.white;
  roundRect(SND_PILL.x, SND_PILL.y, SND_PILL.w, SND_PILL.h, 8);
  ctx.fill();
  ctx.strokeStyle = UI.ink;
  ctx.lineWidth = 2;
  roundRect(SND_PILL.x, SND_PILL.y, SND_PILL.w, SND_PILL.h, 8);
  ctx.stroke();
  ctx.fillStyle = full ? UI.bgDay : UI.ink;
  ctx.font = "bold 13px monospace";
  ctx.fillText(SND_LABELS[soundMode], SND_PILL.x + SND_PILL.w / 2, SND_PILL.y + SND_PILL.h / 2 + 5);

  ctx.fillStyle = UI.white;
  roundRect(LANG_PILL.x, LANG_PILL.y, LANG_PILL.w, LANG_PILL.h, 8);
  ctx.fill();
  ctx.strokeStyle = UI.ink;
  roundRect(LANG_PILL.x, LANG_PILL.y, LANG_PILL.w, LANG_PILL.h, 8);
  ctx.stroke();
  ctx.fillStyle = UI.ink;
  ctx.fillText(`${LANG_CODES[fns.language()]} >`, LANG_PILL.x + LANG_PILL.w / 2, LANG_PILL.y + LANG_PILL.h / 2 + 5);

  ctx.fillStyle = UI.track;
  ctx.font = "13px monospace";
  ctx.fillText(fns.backHint(), TP.cx, 414);

  statusEl.textContent = `Settings · sound ${SND_LABELS[soundMode]} · lang ${LANG_CODES[fns.language()]}`;
}

function settingsTap(x, y) {
  if (inRect(x, y, SND_PILL)) {
    const next = (soundMode + 1) % 3; // SILENT -> VIBRATE -> FULL -> SILENT
    setSoundMode(next);
    if (next !== SOUND_SILENT) playSfx(18); // "menu" -- audible/haptic confirmation
    return;
  }
  if (inRect(x, y, LANG_PILL)) {
    const next = (fns.language() + 1) % LANG_CODES.length;
    Module.ccall("tp_set_language", null, ["number"], [next]);
    playSfx(0); // "tap"
    return;
  }
  if (y > 380) screen = "idle";
}

// Ports drawGameMenu()'s single-tile-so-far subset: only Ball is playable
// here yet (see roadmap), so this is one tile rather than the five
// PetScreen.swift draws.
const BALL_TILE = { x: 133, y: 178, w: 200, h: 110 };

function drawGameMenu() {
  ctx.fillStyle = UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  ctx.strokeStyle = UI.ink;
  ctx.lineWidth = 2;
  roundRect(78, 112, 310, 266, 18);
  ctx.stroke();
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "center";
  ctx.font = "bold 20px monospace";
  ctx.fillText("PLAY", TP.cx, 140);

  ctx.fillStyle = UI.barBad;
  roundRect(BALL_TILE.x, BALL_TILE.y, BALL_TILE.w, BALL_TILE.h, 14);
  ctx.fill();
  ctx.strokeStyle = UI.ink;
  roundRect(BALL_TILE.x, BALL_TILE.y, BALL_TILE.w, BALL_TILE.h, 14);
  ctx.stroke();
  ctx.fillStyle = UI.bgDay;
  ctx.font = "bold 22px monospace";
  ctx.fillText("BALL", BALL_TILE.x + BALL_TILE.w / 2, BALL_TILE.y + BALL_TILE.h / 2 - 2);
  ctx.font = "13px monospace";
  ctx.fillText(`hi ${fns.gameHigh()}`, BALL_TILE.x + BALL_TILE.w / 2, BALL_TILE.y + BALL_TILE.h / 2 + 22);

  ctx.fillStyle = UI.track;
  ctx.font = "13px monospace";
  ctx.fillText("tap outside to close", TP.cx, 410);
  statusEl.textContent = "Play menu";
}

function gameMenuTap(x, y) {
  if (inRect(x, y, { x: BALL_TILE.x, y: BALL_TILE.y, w: BALL_TILE.w, h: BALL_TILE.h })) {
    BallGame.start();
    lastFrameT = performance.now();
    screen = "game";
    return;
  }
  screen = "idle";
}

// Ports renderBallGame(): the day/night habitat backdrop, score + lives,
// the creature chasing the ball, the ball itself, and the impact ring --
// stops short of the falling-poop/weather flourishes SceneRenderer.swift
// draws, since that renderer isn't ported yet either (see roadmap).
function drawBallGame(now) {
  const night = isNight();
  ctx.fillStyle = night ? UI.bgNight : UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  const ink = night ? UI.inkNight : UI.ink;

  if (BallGame.overUntil !== 0) {
    ctx.fillStyle = ink;
    ctx.textAlign = "center";
    ctx.font = "bold 40px monospace";
    ctx.fillText(`SCORE: ${BallGame.score}`, TP.cx, 170);
    ctx.font = "bold 20px monospace";
    ctx.fillStyle = BallGame.newHigh ? UI.barWarn : ink;
    ctx.fillText(BallGame.newHigh ? "NEW RECORD!" : `record: ${fns.gameHigh()}`, TP.cx, 220);
    if (now >= BallGame.overUntil) { screen = "idle"; BallGame.running = false; }
    statusEl.textContent = `Ball · game over · score ${BallGame.score}`;
    return;
  }

  ctx.fillStyle = ink;
  ctx.textAlign = "left";
  ctx.font = "bold 28px monospace";
  ctx.fillText(`${BallGame.score}`, 30, 44);
  for (let i = 0; i < 3; i++) {
    ctx.beginPath();
    ctx.arc(180 + i * 28, 104, 6, 0, Math.PI * 2);
    if (i < 3 - BallGame.misses) { ctx.fillStyle = UI.barBad; ctx.fill(); }
    else { ctx.strokeStyle = UI.track; ctx.lineWidth = 2; ctx.stroke(); }
  }

  // The creature chases the ball -- reuses drawPet's sprite/fallback but at
  // a ground line matching upstream's game-scene y (394, not petGround).
  if (currentSprite) {
    const a = currentSprite.actions[TPAct.idle];
    if (a) {
      const elapsed = performance.now() - poseStart;
      const frame = frameIndexAt(a, elapsed, true);
      const img = frameImageData(currentSprite, TPAct.idle, frame);
      if (img) {
        const s = Math.min(spriteScale(currentSprite, a), 3);
        const w = a.w * s, h = a.h * s;
        frameCanvas.width = a.w; frameCanvas.height = a.h;
        frameCtx.putImageData(img, 0, 0);
        ctx.imageSmoothingEnabled = false;
        ctx.drawImage(frameCanvas, BallGame.petX - w / 2, 394 - (a.base > 0 ? a.base : a.h) * s, w, h);
      }
    }
  }

  const since = now - BallGame.hitAt;
  if (BallGame.hitAt !== 0 && since < 260) {
    const rad = 22 + since / 6;
    ctx.strokeStyle = "rgb(255,231,159)";
    ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(BallGame.hitX, BallGame.hitY, rad, 0, Math.PI * 2); ctx.stroke();
  }

  ctx.font = "24px monospace";
  ctx.textAlign = "center";
  ctx.fillText("⚽", BallGame.ballX, BallGame.ballY + 8); // ball emoji stand-in -- TPIcon.play isn't ported to canvas yet

  statusEl.textContent = `Ball · score ${BallGame.score} · misses ${BallGame.misses}/3`;
}

function draw() {
  if (!Module) return;

  if (screen === "settings") {
    drawSettings();
    return;
  }
  if (screen === "gamemenu") {
    drawGameMenu();
    return;
  }
  if (screen === "game") {
    const now = performance.now();
    const dt = now - lastFrameT;
    lastFrameT = now;
    BallGame.step(dt, now);
    drawBallGame(now);
    return;
  }

  const isEgg = fns.isEgg() !== 0;
  const sleeping = fns.sleeping() !== 0;
  const night = sleeping || isNight();
  const panel = night ? UI.bgNight : UI.bgDay;
  const ink = night ? UI.inkNight : UI.ink;

  ctx.fillStyle = panel;
  ctx.fillRect(0, 0, TP.screen, TP.screen);

  // Header
  ctx.fillStyle = ink;
  ctx.textAlign = "center";
  ctx.font = "bold 22px monospace";
  ctx.fillText(fns.name(), TP.cx, 60);

  if (isEgg) {
    // Simple egg placeholder -- no crack-tap animation yet.
    ctx.beginPath();
    ctx.ellipse(TP.cx, TP.petGround - 75, 60, 75, 0, 0, Math.PI * 2);
    ctx.fillStyle = "#f6f0dc";
    ctx.fill();
    ctx.strokeStyle = UI.ink;
    ctx.lineWidth = 3;
    ctx.stroke();
    ctx.font = "16px monospace";
    ctx.fillStyle = ink;
    ctx.fillText("tap FEED to hatch (WIP)", TP.cx, TP.petGround + 30);
    statusEl.textContent = `EGG · ${fns.name()}`;
    return;
  }

  ensureSprite(fns.speciesId());
  drawPet(ink);

  // Poop icons
  const poops = fns.poops();
  ctx.fillStyle = "#7a5230";
  for (let i = 0; i < poops; i++) {
    ctx.beginPath();
    ctx.arc(36 + i * 46 + 10, 244 + 10, 9, 0, Math.PI * 2);
    ctx.fill();
  }

  // Bottom panel + bars
  ctx.fillStyle = panel;
  ctx.fillRect(0, 312, TP.screen, 154);
  ctx.textAlign = "left";
  drawBar(78, 318, "FUL", fns.fullness());
  drawBar(244, 318, "JOY", fns.joy());
  drawBar(78, 346, "ENE", fns.energy());
  drawBar(244, 346, "HYG", fns.hygiene());

  // Buttons
  for (const b of BUTTONS) {
    const off = sleeping && b.label !== "LIGHT";
    if (!sleeping) {
      ctx.fillStyle = UI.white;
      roundRect(b.x - TP.btnHalf, b.y - TP.btnHalf, TP.btnHalf * 2, TP.btnHalf * 2, 14);
      ctx.fill();
    }
    ctx.strokeStyle = ink;
    ctx.lineWidth = 2;
    roundRect(b.x - TP.btnHalf, b.y - TP.btnHalf, TP.btnHalf * 2, TP.btnHalf * 2, 14);
    ctx.stroke();
    if (!off) {
      ctx.fillStyle = ink;
      ctx.font = "9px monospace";
      ctx.textAlign = "center";
      ctx.fillText(b.label, b.x, b.y + 3);
    }
  }

  if (sleeping) {
    ctx.font = "bold 28px monospace";
    ctx.fillStyle = UI.inkNight;
    ctx.textAlign = "left";
    ctx.fillText("Zz", 320, 140);
  }

  statusEl.textContent =
    `${fns.name()} Lv${fns.level()} · FUL ${fns.fullness()} JOY ${fns.joy()} ` +
    `ENE ${fns.energy()} HYG ${fns.hygiene()}` + (sleeping ? " · sleeping" : "");
}

canvas.addEventListener("pointerdown", (e) => {
  if (!Module) return;
  const rect = canvas.getBoundingClientRect();
  const sx = TP.screen / rect.width, sy = TP.screen / rect.height;
  const x = (e.clientX - rect.left) * sx;
  const y = (e.clientY - rect.top) * sy;

  if (screen === "settings") {
    settingsTap(x, y);
    return;
  }
  if (screen === "gamemenu") {
    gameMenuTap(x, y);
    return;
  }
  if (screen === "game") {
    BallGame.tap(x, y, performance.now());
    return;
  }
  if (fns.isEgg() !== 0) {
    Module._tp_egg_tap();
    return;
  }
  for (const b of BUTTONS) {
    if (Math.abs(x - b.x) < TP.btnHalf && Math.abs(y - b.y) < TP.btnHalf) {
      b.action();
      return;
    }
  }
});

document.getElementById("settingsBtn").addEventListener("click", () => {
  screen = screen === "settings" ? "idle" : "settings";
});

// --- Save persistence ----------------------------------------------------
//
// Mirrors browser_glue.cpp's tp_export_state()/tp_import_state(): the WASM
// side owns the actual key/value store (shim/Preferences.h, an in-memory
// stand-in for ESP32's NVS flash); this is just the round trip that keeps
// it alive in the browser across reloads via IndexedDB. Import must happen
// before the very first tp_tick() call, since that's what triggers
// Pet::begin() reading the store -- importing later would just be ignored.

const DB_NAME = "itamapoke";
const STORE_NAME = "save";
const SAVE_KEY = "state";

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE_NAME);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function loadSave() {
  try {
    const db = await openDb();
    return await new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readonly");
      const req = tx.objectStore(STORE_NAME).get(SAVE_KEY);
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => reject(req.error);
    });
  } catch (e) {
    console.warn("[save] load failed, starting fresh:", e);
    return null;
  }
}

async function writeSave(bytes) {
  try {
    const db = await openDb();
    await new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      tx.objectStore(STORE_NAME).put(bytes, SAVE_KEY);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch (e) {
    console.warn("[save] write failed:", e);
  }
}

// Pulls the current store out of wasm memory as a fresh Uint8Array (the
// pointer tp_export_ptr() returns is only valid until the next export call,
// and can move if the module's heap grows in between -- copying immediately
// is what makes this safe to await afterwards).
function exportStateBytes(mod) {
  const len = mod.ccall("tp_export_state", "number", [], []);
  const ptr = mod.ccall("tp_export_ptr", "number", [], []);
  return mod.HEAPU8.slice(ptr, ptr + len);
}

function importStateBytes(mod, bytes) {
  const ptr = mod._malloc(bytes.length);
  mod.HEAPU8.set(bytes, ptr);
  mod.ccall("tp_import_state", null, ["number", "number"], [ptr, bytes.length]);
  mod._free(ptr);
}

async function saveNow(mod) {
  await writeSave(exportStateBytes(mod));
}

// --- Sprite file picker ---------------------------------------------------
//
// Local-only, per README's licensing note: files picked here go straight
// into this browser's own IndexedDB and nowhere else. Re-picking the same
// dex just overwrites that entry; nothing needs clearing first.
const spriteLoadBtn = document.getElementById("spriteLoad");
const spriteInput = document.getElementById("spriteInput");
spriteLoadBtn.addEventListener("click", () => spriteInput.click());
spriteInput.addEventListener("change", async () => {
  const files = Array.from(spriteInput.files || []);
  spriteInput.value = "";
  if (files.length === 0) return;
  spriteLoadBtn.textContent = "Loading…";
  const n = await importSpriteFiles(files);
  spriteCache.clear(); // a re-picked file may replace one already parsed
  currentDex = 0;    // force ensureSprite() to re-fetch for the active species
  loadingDex = -1;   // ...including one it already (unsuccessfully) tried
  spriteLoadBtn.textContent = n > 0 ? `Loaded ${n} sprite(s)` : "No p<dex>.bin files found";
  setTimeout(() => { spriteLoadBtn.textContent = "Load sprites…"; }, 2500);
});

loadSoundMode();

createTPCore({
  onSfx(id) { playSfx(id); },
}).then(async (mod) => {
  Module = mod;
  fns = {
    isEgg: mod.cwrap("tp_is_egg", "number", []),
    speciesId: mod.cwrap("tp_species_id", "number", []),
    sleeping: mod.cwrap("tp_sleeping", "number", []),
    poops: mod.cwrap("tp_poops", "number", []),
    fullness: mod.cwrap("tp_fullness", "number", []),
    joy: mod.cwrap("tp_joy", "number", []),
    energy: mod.cwrap("tp_energy", "number", []),
    hygiene: mod.cwrap("tp_hygiene", "number", []),
    level: mod.cwrap("tp_level", "number", []),
    name: mod.cwrap("tp_name", "string", []),
    language: mod.cwrap("tp_language", "number", []),
    settingsTitle: mod.cwrap("tp_settings_title", "string", []),
    backHint: mod.cwrap("tp_back_hint", "string", []),
    gameHigh: mod.cwrap("tp_game_high", "number", []),
  };
  mod.ccall("tp_seed_random", null, ["number"], [Date.now() & 0xffffffff]);

  const existing = await loadSave();
  if (existing) {
    importStateBytes(mod, existing);
    console.log("[save] loaded", existing.length, "bytes from IndexedDB");
  } else {
    console.log("[save] no existing save -- starting fresh");
  }

  // Periodic autosave, plus on tab hide/close -- pagehide fires reliably on
  // both a real close and a background/app-switch on mobile Safari, unlike
  // beforeunload.
  setInterval(() => saveNow(mod), 15000);
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") saveNow(mod);
  });
  window.addEventListener("pagehide", () => saveNow(mod));

  function frame(t) {
    mod.ccall("tp_tick", null, ["number"], [t | 0]);
    draw();
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
});
