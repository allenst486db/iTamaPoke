// Ports Sources/Shared/PetScreen.swift's render()/input handling to a plain
// 2D canvas. See browser_ver/README.md for build status.

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

// idle | settings | gamemenu | game -- ports PetScreen.swift's `screen` enum.
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

// Ports drawGameMenu(): five tiles, same layout math as PetScreen.swift's
// `gameMenuTiles` (two rows of tiles inside the 78,112,310,266 card).
let gameMode = 0; // 0 ball, 1 catch, 2 memo, 3 clean, 4 type
const GAME_TILES = [
  { x: 92, y: 168, w: 138, h: 78, label: "BALL", color: UI.barBad, hi: () => fns.gameHigh() },
  { x: 236, y: 168, w: 138, h: 78, label: "CATCH", color: UI.barWarn, hi: () => fns.catchHigh() },
  { x: 92, y: 254, w: 138, h: 78, label: "MEMO", color: "#4C98D9", hi: () => fns.memoHigh() },
  { x: 236, y: 254, w: 138, h: 78, label: "CLEAN", color: UI.barOK, hi: () => fns.cleanHigh() },
  { x: 92, y: 340, w: 282, h: 30, label: "TYPE", color: "#F3B7D9", hi: () => fns.typeHigh() },
];
const GAME_STARTERS = [
  () => BallGame.start(performance.now()),
  (now) => CatchGame.start(now),
  (now) => MemoGame.start(now),
  (now) => CleanGame.start(now),
  (now) => TypeGame.start(now),
];

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

  for (const t of GAME_TILES) {
    ctx.fillStyle = t.color;
    roundRect(t.x, t.y, t.w, t.h, 14);
    ctx.fill();
    ctx.strokeStyle = UI.ink;
    roundRect(t.x, t.y, t.w, t.h, 14);
    ctx.stroke();
    ctx.fillStyle = UI.bgDay;
    ctx.font = "bold 15px monospace";
    ctx.fillText(t.label, t.x + t.w / 2, t.y + t.h / 2 - 2);
    ctx.font = "11px monospace";
    ctx.fillText(`hi ${t.hi()}`, t.x + t.w / 2, t.y + t.h / 2 + 16);
  }

  ctx.fillStyle = UI.track;
  ctx.font = "13px monospace";
  ctx.fillText("tap outside to close", TP.cx, 410);
  statusEl.textContent = "Play menu";
}

function gameMenuTap(x, y) {
  const now = performance.now();
  for (let i = 0; i < GAME_TILES.length; i++) {
    const t = GAME_TILES[i];
    if (inRect(x, y, t)) {
      gameMode = i;
      GAME_STARTERS[i](now);
      lastFrameT = now;
      screen = "game";
      return;
    }
  }
  screen = "idle";
}

// Shared game-over card: the four newer minigames all show the same
// "SCORE: N" + record/new-record layout, matching renderCatchGame etc.'s
// shared shape in PetScreen.swift.
function drawGameOverCard(ink, score, newHigh, high) {
  ctx.fillStyle = ink;
  ctx.textAlign = "center";
  ctx.font = "bold 40px monospace";
  ctx.fillText(`SCORE: ${score}`, TP.cx, 170);
  ctx.font = "bold 20px monospace";
  ctx.fillStyle = newHigh ? UI.barWarn : ink;
  ctx.fillText(newHigh ? "NEW RECORD!" : `record: ${high}`, TP.cx, 220);
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
    drawGameOverCard(ink, BallGame.score, BallGame.newHigh, fns.gameHigh());
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

const CATCH_ICONS = ["🍖", "🫐", "🍏"];

// Ports renderCatchGame(): a target that shrinks its own patience bar,
// three lives, and the day/night backdrop shared with Ball.
function drawCatchGame(now) {
  const night = isNight();
  ctx.fillStyle = night ? UI.bgNight : UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  const ink = night ? UI.inkNight : UI.ink;
  const g = CatchGame;

  if (g.overUntil !== 0) {
    drawGameOverCard(ink, g.score, g.newHigh, fns.catchHigh());
    if (now >= g.overUntil) screen = "idle";
    statusEl.textContent = `Catch · game over · score ${g.score}`;
    return;
  }

  ctx.fillStyle = ink;
  ctx.textAlign = "center";
  ctx.font = "bold 24px monospace";
  ctx.fillText("CATCH", TP.cx, 44);
  ctx.textAlign = "left";
  ctx.font = "bold 20px monospace";
  ctx.fillText(`${g.score}`, 50, 82);
  ctx.textAlign = "right";
  ctx.fillText(`hi ${fns.catchHigh()}`, 396, 82);
  ctx.textAlign = "center";
  for (let i = 0; i < 3; i++) {
    ctx.beginPath();
    ctx.arc(180 + i * 28, 104, 6, 0, Math.PI * 2);
    if (i < 3 - g.misses) { ctx.fillStyle = UI.barBad; ctx.fill(); }
    else { ctx.strokeStyle = UI.track; ctx.lineWidth = 2; ctx.stroke(); }
  }

  ctx.beginPath();
  ctx.arc(g.targetX, g.targetY, 34, 0, Math.PI * 2);
  ctx.fillStyle = UI.white; ctx.fill();
  ctx.strokeStyle = UI.barWarn; ctx.lineWidth = 2; ctx.stroke();
  ctx.font = "26px monospace";
  ctx.fillText(CATCH_ICONS[g.icon], g.targetX, g.targetY + 9);

  const bw = 280;
  const left = g.targetUntil > now ? g.targetUntil - now : 0;
  const fw = bw * Math.min(left, 20000) / 20000;
  ctx.fillStyle = UI.track;
  roundRect(TP.cx - bw / 2, 362, bw, 16, 5); ctx.fill();
  if (fw > 2) { ctx.fillStyle = UI.barOK; roundRect(TP.cx - bw / 2, 362, fw, 16, 5); ctx.fill(); }

  const since = now - g.hitAt;
  if (g.hitAt !== 0 && since < 220) {
    ctx.strokeStyle = UI.barWarn; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(g.hitX, g.hitY, 42 + since / 8, 0, Math.PI * 2); ctx.stroke();
  }

  statusEl.textContent = `Catch · score ${g.score} · misses ${g.misses}/3`;
}

// Ports renderMemoGame(): four pads, lighting during playback and flashing
// green/red on the player's own taps.
function drawMemoGame(now) {
  const night = isNight();
  ctx.fillStyle = night ? UI.bgNight : UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  const ink = night ? UI.inkNight : UI.ink;
  const g = MemoGame;

  if (g.overUntil !== 0) {
    ctx.fillStyle = ink;
    ctx.textAlign = "center";
    ctx.font = "bold 40px monospace";
    ctx.fillText(`SCORE: ${g.rounds}`, TP.cx, 148);
    ctx.font = "bold 24px monospace";
    ctx.fillStyle = "#4C98D9";
    ctx.fillText(`+${g.gain || 0} DEF`, TP.cx, 194);
    ctx.font = "bold 18px monospace";
    ctx.fillStyle = g.newHigh ? UI.barWarn : ink;
    ctx.fillText(g.newHigh ? "NEW RECORD!" : `record: ${fns.memoHigh()}`, TP.cx, 230);
    if (now >= g.overUntil) screen = "idle";
    statusEl.textContent = `Memo · game over · rounds ${g.rounds}`;
    return;
  }

  ctx.fillStyle = ink;
  ctx.textAlign = "center";
  ctx.font = "bold 20px monospace";
  ctx.fillText(`Round ${g.rounds + 1}`, TP.cx, 60);

  const padColors = ["#e86464", "#5da0e8", "#e8c85d", "#5dd08a"];
  for (let i = 0; i < 4; i++) {
    let fill = padColors[i];
    if (g.activePad === i) fill = UI.white;
    if (g.hintPad === i) fill = UI.barWarn;
    if (g.flashPad === i && now < g.flashUntil) fill = g.flashGood ? UI.barOK : UI.barBad;
    ctx.fillStyle = fill;
    roundRect(g.padX[i] - 60, g.padY[i] - 60, 120, 120, 16);
    ctx.fill();
    ctx.strokeStyle = ink; ctx.lineWidth = 2;
    roundRect(g.padX[i] - 60, g.padY[i] - 60, 120, 120, 16);
    ctx.stroke();
  }

  ctx.fillStyle = UI.track;
  ctx.font = "13px monospace";
  ctx.fillText(g.showing ? "watch..." : "your turn", TP.cx, 410);

  statusEl.textContent = `Memo · round ${g.rounds + 1} · ${g.showing ? "playback" : "input"}`;
}

// Ports renderCleanGame(): dirt spots to scrub within a countdown.
function drawCleanGame(now) {
  const night = isNight();
  ctx.fillStyle = night ? UI.bgNight : UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  const ink = night ? UI.inkNight : UI.ink;
  const g = CleanGame;

  if (g.overUntil !== 0) {
    drawGameOverCard(ink, g.score, g.newHigh, fns.cleanHigh());
    if (now >= g.overUntil) screen = "idle";
    statusEl.textContent = `Clean · game over · score ${g.score}`;
    return;
  }

  ctx.fillStyle = ink;
  ctx.textAlign = "center";
  ctx.font = "bold 24px monospace";
  ctx.fillText("CLEAN", TP.cx, 44);
  ctx.textAlign = "left";
  ctx.font = "bold 20px monospace";
  ctx.fillText(`${g.score}`, 50, 82);
  const bw = 280;
  const left = g.until > now ? g.until - now : 0;
  const fw = bw * Math.min(left, 18000) / 18000;
  ctx.fillStyle = UI.track;
  roundRect(TP.cx - bw / 2, 362, bw, 16, 5); ctx.fill();
  if (fw > 2) { ctx.fillStyle = UI.barOK; roundRect(TP.cx - bw / 2, 362, fw, 16, 5); ctx.fill(); }

  ctx.textAlign = "center";
  ctx.font = "28px monospace";
  for (let i = 0; i < 4; i++) {
    if (!g.alive[i]) continue;
    ctx.fillText("🫧", g.x[i], g.y[i] + 10);
  }
  const since = now - g.hitAt;
  if (g.hitAt !== 0 && since < 220) {
    ctx.strokeStyle = UI.barOK; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(g.hitX, g.hitY, 30 + since / 8, 0, Math.PI * 2); ctx.stroke();
  }

  statusEl.textContent = `Clean · score ${g.score} · misses ${g.misses}/3`;
}

// Ports renderTypeGame(): the attacking type shown at top, three answer
// rows, a countdown bar per question.
const TYPE_NAMES = ["", "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE",
  "FIGHT", "POISON", "GROUND", "FLYING", "PSYCHIC", "BUG", "ROCK", "GHOST",
  "DRAGON", "DARK", "STEEL", "FAIRY"];

function drawTypeGame(now) {
  const night = isNight();
  ctx.fillStyle = night ? UI.bgNight : UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  const ink = night ? UI.inkNight : UI.ink;
  const g = TypeGame;

  if (g.overUntil !== 0) {
    drawGameOverCard(ink, g.score, g.newHigh, fns.typeHigh());
    if (now >= g.overUntil) screen = "idle";
    statusEl.textContent = `Type · game over · score ${g.score}`;
    return;
  }

  ctx.fillStyle = ink;
  ctx.textAlign = "center";
  ctx.font = "bold 18px monospace";
  ctx.fillText("What beats...", TP.cx, 70);
  ctx.font = "bold 28px monospace";
  ctx.fillText(TYPE_NAMES[g.enemy], TP.cx, 110);

  const left = g.until > now ? g.until - now : 0;
  const bw = 326;
  ctx.fillStyle = UI.track;
  roundRect(TP.cx - bw / 2, 150, bw, 10, 4); ctx.fill();
  ctx.fillStyle = UI.barOK;
  roundRect(TP.cx - bw / 2, 150, bw * Math.min(left, 4200) / 4200, 10, 4); ctx.fill();

  for (let i = 0; i < 3; i++) {
    const by = 210 + i * 60;
    ctx.fillStyle = UI.white;
    roundRect(70, by - 8, 326, 56, 12); ctx.fill();
    ctx.strokeStyle = ink; ctx.lineWidth = 2;
    roundRect(70, by - 8, 326, 56, 12); ctx.stroke();
    ctx.fillStyle = ink;
    ctx.font = "bold 18px monospace";
    ctx.fillText(TYPE_NAMES[g.choices[i]], TP.cx, by + 28);
  }

  ctx.fillStyle = ink;
  ctx.textAlign = "left";
  ctx.font = "bold 16px monospace";
  ctx.fillText(`${g.score}`, 30, 44);

  statusEl.textContent = `Type · score ${g.score} · misses ${g.misses}/3`;
}

// Ports renderSack(): a swinging punching bag, tapped for ten seconds.
function drawSackGame(now) {
  const night = isNight();
  ctx.fillStyle = night ? UI.bgNight : UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  const ink = night ? UI.inkNight : UI.ink;

  if (Module._tp_sack_is_over() !== 0) {
    ctx.fillStyle = ink;
    ctx.textAlign = "center";
    ctx.font = "bold 32px monospace";
    ctx.fillText(fns.hitsLine(), TP.cx, 160);
    ctx.fillStyle = UI.barBad;
    ctx.font = "bold 22px monospace";
    ctx.fillText(fns.strengthGainLine(), TP.cx, 210);
    const newHigh = fns.sackNewHigh() !== 0;
    ctx.fillStyle = newHigh ? UI.barWarn : ink;
    ctx.font = "13px monospace";
    ctx.fillText(newHigh && fns.sackHits() > 0 ? fns.newRecordText() : fns.recordLine(fns.strengthHigh2()), TP.cx, 256);
    if (Module._tp_sack_over_until_reached(now)) screen = "card";
    statusEl.textContent = `Sack · done · ${fns.sackHits()} hits`;
    return;
  }

  const off = SackGame.shake * Math.sin(now * 0.05);
  const sx = TP.cx + off, top = 86;
  ctx.fillStyle = ink;
  ctx.fillRect(TP.cx - 3, 56, 6, top - 56);
  ctx.fillRect(sx - 4, top - 30, 8, 34);
  ctx.fillStyle = "#b53a3a";
  roundRect(sx - 42, top, 84, 150, 26); ctx.fill();
  ctx.fillStyle = "#7e2828";
  roundRect(sx - 42, top, 84, 22, 18); ctx.fill();
  ctx.strokeStyle = ink; ctx.lineWidth = 2;
  roundRect(sx - 42, top, 84, 150, 26); ctx.stroke();

  ctx.fillStyle = ink;
  ctx.textAlign = "center";
  ctx.font = "bold 28px monospace";
  ctx.fillText(`${fns.sackHits()}`, TP.cx, 280);

  statusEl.textContent = `Sack · ${fns.sackHits()} hits`;
}

function draw() {
  if (!Module) return;

  if (screen === "settings") {
    drawSettings();
    return;
  }
  if (screen === "dex") {
    if (dexScreen === "detail") drawDexDetail(); else drawDexGrid();
    return;
  }
  if (screen === "battle") {
    drawBattle(performance.now());
    return;
  }
  if (screen === "card") {
    drawCard(performance.now());
    return;
  }
  if (screen === "keyboard") {
    drawKeyboard();
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
    switch (gameMode) {
      case 0: BallGame.step(dt, now); drawBallGame(now); break;
      case 1: CatchGame.step(now); drawCatchGame(now); break;
      case 2: MemoGame.step(now); drawMemoGame(now); break;
      case 3: CleanGame.step(now); drawCleanGame(now); break;
      case 4: TypeGame.step(now); drawTypeGame(now); break;
      case 5: SackGame.step(now); drawSackGame(now); break;
    }
    return;
  }

  // Ceremony/evolving takes over the whole screen, same precedence as
  // PetScreen.swift's render() (checked before anything else about the
  // idle scene).
  if (fns.ceremony() !== 0 || fns.evolvingNow() !== 0) {
    drawCeremonyOrEvolving(performance.now());
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

  // Evolve/farewell/runaway call-to-action, and its confirmation dialog --
  // same precedence as PetScreen.swift's render(): evolve first, then
  // runaway, then the voluntary farewell.
  if (!isEgg) drawExpeditionHud();
  if (!isEgg) drawEvolveEndingOverlay(performance.now());
  if (choice !== "none") drawChoiceDialog();

  // Wild-encounter prompt, checked once a frame while the idle screen is
  // genuinely the front-most thing -- mirrors PetScreen.swift's
  // mainScreenReadyForWild gate (no egg/sleeping/other dialog/CTA open).
  const wildEligible = !isEgg && !sleeping && choice === "none" &&
    fns.wantsEvolve() === 0 && fns.canRunaway() === 0 && fns.wantsFarewell() === 0;
  Module._tp_battle_check_wild(wildEligible ? 1 : 0);
  if (choice === "none" && fns.wildPromptActive() !== 0) drawWildPrompt();

  statusEl.textContent =
    `${fns.name()} Lv${fns.level()} · FUL ${fns.fullness()} JOY ${fns.joy()} ` +
    `ENE ${fns.energy()} HYG ${fns.hygiene()}` + (sleeping ? " · sleeping" : "");
}

function handleTap(x, y) {
  if (screen === "settings") {
    settingsTap(x, y);
    return;
  }
  if (screen === "dex") {
    if (dexScreen === "detail") dexDetailTap(x, y); else dexGridTap(x, y);
    return;
  }
  if (screen === "battle") {
    battleTap(x, y);
    return;
  }
  if (screen === "card") {
    cardTap(x, y);
    return;
  }
  if (screen === "keyboard") {
    keyboardTap(x, y);
    return;
  }
  if (screen === "gamemenu") {
    gameMenuTap(x, y);
    return;
  }
  if (screen === "game") {
    const now = performance.now();
    switch (gameMode) {
      case 0:
        BallGame.tap(x, y, now);
        break;
      case 1: {
        const r = CatchGame.tap(x, y, now);
        if (r === "hit") playSfx(12); // catchOK
        else if (r === "miss") playSfx(13); // catchFail
        break;
      }
      case 2: {
        const r = MemoGame.tap(x, y, now);
        if (r.pad >= 0) playSfx(23 + r.pad);
        break;
      }
      case 3: {
        const r = CleanGame.tap(x, y, now);
        if (r === "hit") playSfx(32); // minigameOK
        else if (r === "miss") playSfx(33); // minigameBad
        break;
      }
      case 4: {
        const typeChoice = TypeGame.choiceAt(x, y);
        if (typeChoice >= 0) {
          const r = TypeGame.tap(typeChoice, now);
          playSfx(r === "hit" ? 30 : 31); // effective / weakHit
        }
        break;
      }
      case 5:
        SackGame.tap(now);
        break;
    }
    return;
  }
  if (fns.isEgg() !== 0) {
    Module._tp_egg_tap();
    return;
  }
  if (choice !== "none") {
    choiceDialogTap(x, y);
    return;
  }
  if (evolveEndingTap(x, y)) return;
  if (fns.wildPromptActive() !== 0) {
    wildPromptTap(x, y);
    return;
  }
  for (const b of BUTTONS) {
    if (Math.abs(x - b.x) < TP.btnHalf && Math.abs(y - b.y) < TP.btnHalf) {
      b.action();
      return;
    }
  }
}

// Whether a drag should be read as a swipe at all -- ports PetScreen.swift's
// `swipeAllowed`. A stray drag mid-minigame (or a second finger landing
// during a tap, which SwiftUI/the DOM can both report as a large jump) must
// not be read as "swipe out of the game."
function swipeAllowed() {
  if (screen === "game" || screen === "battle" || screen === "gamemenu") return false;
  return choice === "none" && fns.wildPromptActive() === 0;
}

// Ports PetScreen.swift's onSwipe (horizontal): from idle, any horizontal
// swipe opens the dex; on the dex/card, it turns pages; dir 1 = swiped
// right, -1 = swiped left (left advances, matching upstream).
function onSwipe(dir) {
  if (screen === "card") {
    cardPage = ((dir > 0 ? cardPage - 1 : cardPage + 1) + CARD_PAGE_COUNT) % CARD_PAGE_COUNT;
    return;
  }
  if (screen === "idle") {
    if (fns.isEgg() !== 0 || choice !== "none") return;
    dexScreen = "grid";
    dexPage = 0;
    dexFilter = 0;
    screen = "dex";
    return;
  }
  if (screen !== "dex") return;
  if (dexScreen === "detail") {
    dexDetailPage = Math.min(Math.max(dexDetailPage + (dir > 0 ? -1 : 1), 0), 1);
    return;
  }
  const pages = dexPageCount();
  const next = dexPage - dir;
  if (next < 0) { screen = "idle"; return; }
  dexPage = Math.min(next, pages - 1);
}

// Ports PetScreen.swift's onSwipeV (vertical): dir 1 = swiped down (opens
// settings from idle), -1 = swiped up (opens the stat card from idle,
// closes it if already open).
function onSwipeV(dir) {
  if (!swipeAllowed()) return;
  if (screen === "dex") {
    dexScreen = "grid";
    screen = "idle";
    return;
  }
  if (screen === "card") {
    if (dir < 0) screen = "idle"; // up closes
    return;
  }
  if (screen === "settings") {
    screen = "idle";
    return;
  }
  if (screen !== "idle" || choice !== "none") return;
  if (dir > 0) { // down: settings
    screen = "settings";
    return;
  }
  if (fns.isEgg() !== 0) return; // up: the stat card
  screen = "card";
  cardPage = 0;
}

// Pointer-drag gesture recognizer, mirroring PetScreen.swift's
// DragGesture(minimumDistance: 0) + onGesture(from:to:predicted:): classify
// the release point against the *start* point as a swipe past a distance-
// and-direction threshold, a plain tap if it barely moved, or nothing (a
// stray ambiguous drag) otherwise -- rather than firing on pointerdown,
// which would make every swipe also register as a tap on whatever sits
// under the finger's starting point.
let dragStart = null;
function toScreenSpace(clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  const sx = TP.screen / rect.width, sy = TP.screen / rect.height;
  return { x: (clientX - rect.left) * sx, y: (clientY - rect.top) * sy };
}
canvas.addEventListener("pointerdown", (e) => {
  if (!Module) return;
  dragStart = toScreenSpace(e.clientX, e.clientY);
});
canvas.addEventListener("pointerup", (e) => {
  if (!Module || !dragStart) return;
  const from = dragStart;
  dragStart = null;
  const to = toScreenSpace(e.clientX, e.clientY);
  if (!swipeAllowed()) {
    handleTap(from.x, from.y);
    return;
  }
  const dx = to.x - from.x, dy = to.y - from.y;
  if (Math.abs(dx) > 80 && Math.abs(dx) > Math.abs(dy) * 1.4) {
    onSwipe(dx > 0 ? 1 : -1);
  } else if (Math.abs(dy) > 80 && Math.abs(dy) > Math.abs(dx) * 1.4) {
    onSwipeV(dy > 0 ? 1 : -1);
  } else if (Math.abs(dx) < 40 && Math.abs(dy) < 40) {
    handleTap(from.x, from.y);
  }
});
canvas.addEventListener("pointercancel", () => { dragStart = null; });

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

// --- Dex entry text file picker -------------------------------------------
//
// Same local-only rule as sprites -- picked files go into this browser's
// own IndexedDB and nowhere else. See dexentry.js.
const dexEntryLoadBtn = document.getElementById("dexEntryLoad");
const dexEntryInput = document.getElementById("dexEntryInput");
dexEntryLoadBtn.addEventListener("click", () => dexEntryInput.click());
dexEntryInput.addEventListener("change", async () => {
  const files = Array.from(dexEntryInput.files || []);
  dexEntryInput.value = "";
  if (files.length === 0) return;
  dexEntryLoadBtn.textContent = "Loading…";
  const n = await importDexEntryFiles(files);
  dexEntryLoadBtn.textContent = n > 0 ? `Loaded ${n} language(s)` : "No dex_entries_<lang>.txt found";
  setTimeout(() => { dexEntryLoadBtn.textContent = "Load dex text…"; }, 2500);
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
    catchHigh: mod.cwrap("tp_catch_high", "number", []),
    memoHigh: mod.cwrap("tp_memo_high", "number", []),
    cleanHigh: mod.cwrap("tp_clean_high", "number", []),
    typeHigh: mod.cwrap("tp_type_high", "number", []),
    dexCount: mod.cwrap("tp_dex_count", "number", []),
    dexRegistered: mod.cwrap("tp_dex_registered", "number", ["number"]),
    dexCaught: mod.cwrap("tp_dex_caught", "number", ["number"]),
    dexShiny: mod.cwrap("tp_dex_shiny", "number", ["number"]),
    dexName: mod.cwrap("tp_dex_name", "string", ["number"]),
    dexType1: mod.cwrap("tp_dex_type1", "number", ["number"]),
    dexType2: mod.cwrap("tp_dex_type2", "number", ["number"]),
    registeredCount: mod.cwrap("tp_registered_count", "number", []),
    caughtCount: mod.cwrap("tp_caught_count", "number", []),

    wildPromptActive: mod.cwrap("tp_wild_prompt_active", "number", []),
    battleWildPromptLine: () => {
      const dex = mod.ccall("tp_wild_prompt_dex", "number", [], []);
      const lvl = mod.ccall("tp_wild_prompt_level", "number", [], []);
      return `${mod.ccall("tp_dex_name", "string", ["number"], [dex])} Lv.${lvl}`;
    },
    battleWildQuestionText: mod.cwrap("tp_battle_wild_question_text", "string", []),
    battleFightText: mod.cwrap("tp_battle_fight_text", "string", []),
    battleLaterText: mod.cwrap("tp_battle_later_text", "string", []),

    battleResolved: mod.cwrap("tp_battle_resolved", "number", []),
    battlePlayerWon: mod.cwrap("tp_battle_player_won", "number", []),
    battleWildDex: mod.cwrap("tp_battle_wild_dex", "number", []),
    battlePlayerHp: mod.cwrap("tp_battle_player_hp", "number", []),
    battlePlayerMaxHp: mod.cwrap("tp_battle_player_max_hp", "number", []),
    battleEnemyHp: mod.cwrap("tp_battle_enemy_hp", "number", []),
    battleEnemyMaxHp: mod.cwrap("tp_battle_enemy_max_hp", "number", []),
    battleAttackMenuOpen: mod.cwrap("tp_battle_attack_menu_open", "number", []),
    battleLastEnemyDamage: mod.cwrap("tp_battle_last_enemy_damage", "number", []),
    battleRound: mod.cwrap("tp_battle_round", "number", []),
    battleTitle: mod.cwrap("tp_battle_title_text", "string", []),
    battlePlayerLabel: mod.cwrap("tp_battle_player_label", "string", []),
    battleEnemyLabel: mod.cwrap("tp_battle_enemy_label", "string", []),
    battleRunText: mod.cwrap("tp_battle_run_text", "string", []),
    battleAttackText: mod.cwrap("tp_battle_attack_text", "string", []),
    battleDodgeText: mod.cwrap("tp_battle_dodge_text", "string", []),
    battleRestText: mod.cwrap("tp_battle_rest_text", "string", []),
    battleQuickAttackText: mod.cwrap("tp_battle_quick_attack_text", "string", []),
    battleHeavyAttackText: mod.cwrap("tp_battle_heavy_attack_text", "string", []),
    battleRoundLabel: mod.cwrap("tp_battle_round_label", "string", []),
    battleMessage: mod.cwrap("tp_battle_message", "string", []),
    battleResultText: mod.cwrap("tp_battle_result_text", "string", []),
    battleRoundsLine: mod.cwrap("tp_battle_rounds_line", "string", []),
    battleDamageLine: mod.cwrap("tp_battle_damage_line", "string", []),
    battleRewardLine: mod.cwrap("tp_battle_reward_line", "string", []),
    battleCloseChanceText: mod.cwrap("tp_battle_close_chance_text", "string", []),
    battleCatchOffered: mod.cwrap("tp_battle_catch_offered", "number", []),
    battleCatchDone: mod.cwrap("tp_battle_catch_done", "number", []),
    battleCatchTried: mod.cwrap("tp_battle_catch_tried", "number", []),
    battleCatchSuccess: mod.cwrap("tp_battle_catch_success", "number", []),
    battleCatchWildText: mod.cwrap("tp_battle_catch_wild_text", "string", []),
    battleLeaveWildText: mod.cwrap("tp_battle_leave_wild_text", "string", []),
    battleOkText: mod.cwrap("tp_battle_ok_text", "string", []),
    battleCaughtOkText: mod.cwrap("tp_battle_caught_ok_text", "string", []),
    battleEscapedText: mod.cwrap("tp_battle_escaped_text", "string", []),

    speciesName: mod.cwrap("tp_species_name", "string", []),
    streakLine: mod.cwrap("tp_streak_line", "string", []),
    infoLine: mod.cwrap("tp_info_line", "string", []),
    renameHint: mod.cwrap("tp_rename_hint", "string", []),
    bondLabel: mod.cwrap("tp_bond_label", "string", []),
    bond: mod.cwrap("tp_bond", "number", []),
    hasNick: mod.cwrap("tp_has_nick", "number", []),

    wantsEvolve: mod.cwrap("tp_wants_evolve", "number", []),
    wantsFarewell: mod.cwrap("tp_wants_farewell", "number", []),
    canRunaway: mod.cwrap("tp_can_runaway", "number", []),
    evolvingNow: mod.cwrap("tp_evolving_now", "number", []),
    evolveProgress: mod.cwrap("tp_evolve_progress", "number", []),
    ceremony: mod.cwrap("tp_ceremony", "number", []),
    ceremonyProgress: mod.cwrap("tp_ceremony_progress", "number", []),
    ceremonyMessage: mod.cwrap("tp_ceremony_message", "string", []),
    evolveButtonText: mod.cwrap("tp_evolve_button_text", "string", []),
    farewellButtonText: mod.cwrap("tp_farewell_button_text", "string", []),
    runawayButtonText: mod.cwrap("tp_runaway_button_text", "string", []),
    evolveQuestion: mod.cwrap("tp_evolve_question", "string", []),
    evolveKeepText: mod.cwrap("tp_evolve_keep_text", "string", []),
    farewellQuestion: mod.cwrap("tp_farewell_question", "string", []),
    farewellGoText: mod.cwrap("tp_farewell_go_text", "string", []),
    farewellStayText: mod.cwrap("tp_farewell_stay_text", "string", []),

    personalityKind: mod.cwrap("tp_personality_kind", "number", []),
    personalityTitle: mod.cwrap("tp_personality_title", "string", []),
    personalityName: mod.cwrap("tp_personality_name", "string", []),
    personalityHint: mod.cwrap("tp_personality_hint", "string", []),
    personalityAgeLine: mod.cwrap("tp_personality_age_line", "string", []),
    recordsTitle: mod.cwrap("tp_records_title", "string", []),
    ballRecordLabel: mod.cwrap("tp_ball_record_label", "string", []),
    catchRecordLabel: mod.cwrap("tp_catch_record_label", "string", []),
    memoRecordLabel: mod.cwrap("tp_memo_record_label", "string", []),
    cleanRecordLabel: mod.cwrap("tp_clean_record_label", "string", []),
    typeRecordLabel: mod.cwrap("tp_type_record_label", "string", []),
    bestBattleStreak: mod.cwrap("tp_best_battle_streak", "number", []),

    statsBattleTitle: mod.cwrap("tp_battle_title", "string", []),
    battleRecordLine: mod.cwrap("tp_battle_record_line", "string", []),
    battleStreakLine: mod.cwrap("tp_battle_streak_line", "string", []),
    battleBestLine: mod.cwrap("tp_battle_best_line", "string", []),
    wildBattleText: mod.cwrap("tp_wild_battle_text", "string", []),
    trainButtonText: mod.cwrap("tp_train_button_text", "string", []),
    atkStat: mod.cwrap("tp_atk_stat", "number", []),
    defStat: mod.cwrap("tp_def_stat", "number", []),
    speStat: mod.cwrap("tp_spe_stat", "number", []),
    weight: mod.cwrap("tp_weight", "number", []),
    statLabel: mod.cwrap("tp_stat_label", "string", ["number"]),
    battleCanStart: mod.cwrap("tp_battle_can_start", "number", []),

    medalCount: mod.cwrap("tp_medal_count", "number", []),
    hasMedal: mod.cwrap("tp_has_medal", "number", ["number"]),
    medalDescription: mod.cwrap("tp_medal_description", "string", ["number"]),
    medalsLine: mod.cwrap("tp_medals_line", "string", []),

    progressTitle: mod.cwrap("tp_progress_title", "string", []),
    levelLine: mod.cwrap("tp_level_line", "string", []),
    minutesIntoLevel: mod.cwrap("tp_minutes_into_level", "number", []),
    minutesPerLevel: mod.cwrap("tp_minutes_per_level", "number", []),
    nextLevelLine: mod.cwrap("tp_next_level_line", "string", []),
    evolutionLabel: mod.cwrap("tp_evolution_label", "string", []),
    evolutionStatus: mod.cwrap("tp_evolution_status", "string", []),
    evolutionStatusKind: mod.cwrap("tp_evolution_status_kind", "number", []),
    mistakesLine: mod.cwrap("tp_mistakes_line", "string", []),
    careMistakes: mod.cwrap("tp_care_mistakes", "number", []),

    dailyTitle: mod.cwrap("tp_daily_title", "string", []),
    dayPhaseLabel: mod.cwrap("tp_day_phase_label", "string", []),
    dailyGoalCount: mod.cwrap("tp_daily_goal_count", "number", []),
    doneText: mod.cwrap("tp_done_text", "string", []),
    dailyGoalComplete: mod.cwrap("tp_daily_goal_complete", "number", ["number"]),
    dailyGoalLabel: mod.cwrap("tp_daily_goal_label", "string", ["number"]),
    dailyGoalKind: mod.cwrap("tp_daily_goal_kind", "number", ["number"]),
    dailyGoalProgress: mod.cwrap("tp_daily_goal_progress", "number", ["number"]),
    dailyGoalTarget: mod.cwrap("tp_daily_goal_target", "number", ["number"]),
    dailyRewardLine: mod.cwrap("tp_daily_reward_line", "string", []),

    boxTitle: mod.cwrap("tp_box_title", "string", []),
    caughtCountLine: mod.cwrap("tp_caught_count_line", "string", []),
    knownCountLine: mod.cwrap("tp_known_count_line", "string", []),
    dexGoalLine: mod.cwrap("tp_dex_goal_line", "string", []),
    noCatchesText: mod.cwrap("tp_no_catches_text", "string", []),
    raisedMarkText: mod.cwrap("tp_raised_mark_text", "string", []),
    boxSortLabel: mod.cwrap("tp_box_sort_label", "string", []),
    pageLine: mod.cwrap("tp_page_line", "string", ["number", "number"]),
    boxPageCount: mod.cwrap("tp_box_page_count", "number", ["number"]),
    boxDexAt: mod.cwrap("tp_box_dex_at", "number", ["number"]),
    caughtCount: mod.cwrap("tp_caught_count", "number", []),

    expeditionTitle: mod.cwrap("tp_expedition_title", "string", []),
    expeditionReady: mod.cwrap("tp_expedition_ready", "number", []),
    expeditionActive: mod.cwrap("tp_expedition_active", "number", []),
    expeditionFoundLine: mod.cwrap("tp_expedition_found_line", "string", []),
    expeditionClaimText: mod.cwrap("tp_expedition_claim_text", "string", []),
    expeditionBackInLine: mod.cwrap("tp_expedition_back_in_line", "string", []),
    expeditionWaitText: mod.cwrap("tp_expedition_wait_text", "string", []),
    expeditionInventoryFullText: mod.cwrap("tp_expedition_inventory_full_text", "string", []),
    expeditionNeedEnergyText: mod.cwrap("tp_expedition_need_energy_text", "string", []),
    expeditionInventoryFull: mod.cwrap("tp_expedition_inventory_full", "number", []),
    expeditionDurationLabel: mod.cwrap("tp_expedition_duration_label", "string", ["number"]),
    expeditionCostLabel: mod.cwrap("tp_expedition_cost_label", "string", ["number"]),
    expeditionCanStart: mod.cwrap("tp_expedition_can_start", "number", ["number"]),
    inventoryTitle: mod.cwrap("tp_inventory_title", "string", []),
    expeditionItemLabel: mod.cwrap("tp_expedition_item_label", "string", ["number"]),
    expeditionItemCount: mod.cwrap("tp_expedition_item_count", "number", ["number"]),
    expeditionItemColor: mod.cwrap("tp_expedition_item_color", "number", ["number"]),
    trainChoiceTitle: mod.cwrap("tp_train_choice_title", "string", []),
    trainStatLabel: mod.cwrap("tp_train_stat_label", "string", ["number"]),
    trainStatUsable: mod.cwrap("tp_train_stat_usable", "number", ["number"]),
    trainMaxedText: mod.cwrap("tp_train_maxed_text", "string", []),
    expeditionHudState: mod.cwrap("tp_expedition_hud_state", "number", []),
    expeditionHudLabel: mod.cwrap("tp_expedition_hud_label", "string", []),

    hitsLine: mod.cwrap("tp_hits_line", "string", []),
    strengthGainLine: mod.cwrap("tp_strength_gain_line", "string", []),
    newRecordText: mod.cwrap("tp_new_record_text", "string", []),
    recordLine: mod.cwrap("tp_record_line", "string", ["number"]),
    sackHits: mod.cwrap("tp_sack_hits", "number", []),
    sackNewHigh: mod.cwrap("tp_sack_new_high", "number", []),
    strengthHigh2: mod.cwrap("tp_strength_high2", "number", []),
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
