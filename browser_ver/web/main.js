// Ports Sources/Shared/PetScreen.swift's render()/input handling to a plain
// 2D canvas. See browser_ver/README.md for build status.

const rgb565 = (u16) => {
  const r = (u16 >> 11) & 0x1f, g = (u16 >> 5) & 0x3f, b = u16 & 0x1f;
  const r8 = Math.round(r * 255 / 31), g8 = Math.round(g * 255 / 63), b8 = Math.round(b * 255 / 31);
  return `rgb(${r8},${g8},${b8})`;
};

// Mirrors TPGraphics.swift's TP/UI enums.
const TP = { screen: 466, cx: 233, cy: 233, petCY: 202, petGround: 304, btnHalf: 26 };
const UI = {
  bgDay: rgb565(0xF77C), bgNight: rgb565(0x10C5),
  ink: rgb565(0x2946), inkNight: rgb565(0xDEFE),
  track: rgb565(0xDE97), barOK: rgb565(0x5DCD),
  barWarn: rgb565(0xED07), barBad: rgb565(0xEA87), white: "#fff",
};

// Same four buttons as PetScreen.swift's `Self.buttons`, in the same order:
// feed / play / light(sleep toggle) / clean.
// Each carries the firmware's own pixel icon (icons.js), drawn 16x16 at
// scale 2 centred on the button exactly as drawButtons does on iOS.
//
// FEED opens the berry/candy menu rather than feeding straight away (the
// iOS button does the same: red berry, blue berry, green berry, candy --
// which berry the creature loves is a per-species secret to discover, and
// candy is the weight mechanic; neither was reachable at all while FEED
// short-circuited to feedBerry(0)). CLEAN starts the bath, which washes the
// creature only once the suds finish -- see behaviour.js's stepBath.
const BUTTONS = [
  { x: 140, y: 390, label: "FEED",  icon: () => TPIcon.food,  action: (now) => { feedMenuUntil = now + 6000; } },
  { x: 202, y: 404, label: "PLAY",  icon: () => TPIcon.play,  action: () => { screen = "gamemenu"; } },
  { x: 264, y: 404, label: "LIGHT", icon: () => TPIcon.light, action: () => Module._tp_toggle_light() },
  { x: 326, y: 390, label: "CLEAN", icon: () => TPIcon.clean, action: (now) => {
    startBath(now, fns.isEgg() !== 0, fns.sleeping() !== 0, fns.ceremony());
  } },
];

// Mirrors PetScreen.swift's `feedMenuUntil` / `confirmUntil`: deadlines in
// ms after which the feed menu / release dialog close on their own.
let feedMenuUntil = 0;
let confirmUntil = 0;

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

// Shared backdrop for the minigames and the wild battle: the creature's own
// habitat, so they don't look like a different app -- PetScreen.swift's
// drawGameScene (SceneRenderer with sleeping forced off). Returns the ink
// colour the caller should draw its text in.
function drawGameScene() {
  const hour = sceneHour();
  const night = sceneIsNight(hour, false);
  const biome = fns.isEgg() !== 0 ? 0 : fns.dexBiome(fns.speciesId());
  drawScene(biome, performance.now(), night, hour);
  return { night, ink: night ? UI.inkNight : UI.ink };
}

function drawBar(x, y, label, value, ink = UI.ink) {
  const bx = x + 48, bw = 100, bh = 15;
  // Label in the scene's ink: at night the panel is dark, so the day ink
  // would vanish into it -- PetScreen's drawBars takes the same ink.
  ctx.fillStyle = ink;
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

/// Draws whichever pose behaviour.js settled on this tick (walk/eat/sleep/
/// hurt/gesture, or idle), anchored by the creature's feet on TP.petGround
/// at petPose.x -- PetScreen.swift's drawPet. The "no sprite loaded"
/// placeholder reproduces the firmware's own behaviour with an empty SD card.
function drawPet(ink) {
  if (!currentSprite) {
    ctx.font = "bold 64px monospace";
    ctx.fillStyle = ink;
    ctx.fillText("?", TP.cx, TP.petGround - 100);
    ctx.font = "12px monospace";
    ctx.fillText("(no sprite loaded for this species)", TP.cx, TP.petGround - 40);
    return;
  }
  const act = spriteHas(currentSprite, petPose.act) ? petPose.act : TPAct.idle;
  const a = currentSprite.actions[act];
  if (!a) return;
  const frame = frameIndexAt(a, petPose.elapsedMs, petPose.loop);
  const img = frameImageData(currentSprite, act, frame);
  if (!img) return;

  const s = spriteScale(currentSprite, a);
  const w = a.w * s, h = a.h * s;
  const x = petPose.x - w / 2;
  const y = TP.petGround - (a.base > 0 ? a.base : a.h) * s + petPose.yOffset;

  frameCanvas.width = a.w;
  frameCanvas.height = a.h;
  frameCtx.putImageData(img, 0, 0);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(frameCanvas, x, y, w, h);
}

// Port of drawEgg: cream ellipse, three spots, crack marks at 1 and 2 taps
// (the third hatches).
function drawEgg(cracks) {
  const cy = TP.petCY;
  ctx.beginPath();
  ctx.ellipse(TP.cx, cy, 60, 75, 0, 0, Math.PI * 2);
  ctx.fillStyle = "rgb(246,240,220)";
  ctx.fill();
  ctx.strokeStyle = UI.ink;
  ctx.lineWidth = 3;
  ctx.stroke();
  ctx.fillStyle = "rgb(216,201,164)";
  for (const [sx, sy] of [[-22, -10], [14, 8], [-6, 34]]) {
    ctx.beginPath(); ctx.arc(TP.cx + sx, cy + sy, 9, 0, Math.PI * 2); ctx.fill();
  }
  const crack = (fx, fy, dx) => {
    ctx.strokeStyle = UI.ink; ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(fx, fy);
    ctx.lineTo(fx + dx, fy + 12);
    ctx.lineTo(fx, fy + 24);
    ctx.lineTo(fx + dx, fy + 36);
    ctx.stroke();
  };
  if (cracks >= 1) crack(TP.cx + 6, cy - 46, 10);
  if (cracks >= 2) crack(TP.cx - 18, cy + 4, -12);
}

// Flame and streak count, top-left of the idle screen -- drawStreakBadge.
function drawFlame(x, y, h = 18) {
  ctx.fillStyle = UI.barBad;
  ctx.beginPath(); ctx.moveTo(x + 8, y); ctx.lineTo(x + 1, y + h); ctx.lineTo(x + 15, y + h); ctx.closePath(); ctx.fill();
  ctx.fillStyle = UI.barWarn;
  ctx.beginPath(); ctx.moveTo(x + 8, y + 7); ctx.lineTo(x + 4, y + h); ctx.lineTo(x + 12, y + h); ctx.closePath(); ctx.fill();
}
function drawStreakBadge(ink) {
  const streak = fns.streak();
  if (streak < 1) return;
  drawFlame(26, 16, 17);
  ctx.textAlign = "left";
  ctx.font = "bold 15px monospace";
  ctx.fillStyle = ink;
  ctx.fillText(String(streak), 48, 30);
}

// Temporary banner for a new medal or a streak milestone -- drawCelebration.
function drawCelebration() {
  let title, detail;
  if (fns.showMedal() !== 0 && fns.newMedalName()) {
    title = fns.medalBannerTitle(); detail = fns.newMedalName();
  } else if (fns.showMilestone() !== 0) {
    title = fns.milestoneTitle(); detail = fns.milestoneLine();
  } else {
    return;
  }
  ctx.fillStyle = UI.barWarn;
  roundRect(73, 150, 320, 96, 16); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 1;
  roundRect(73, 150, 320, 96, 16); ctx.stroke();
  ctx.textAlign = "center";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 20px monospace";
  ctx.fillText(title, TP.cx, 192);
  ctx.font = "15px monospace";
  ctx.fillText(detail, TP.cx, 224);
}

// The berry/candy picker FEED opens -- drawFeedMenu: four icons at scale 3
// in a white box, exactly where iOS puts them. Tapping picks by column.
function drawFeedMenu(ink) {
  ctx.fillStyle = UI.white;
  roundRect(101, 288, 264, 64, 14); ctx.fill();
  ctx.strokeStyle = ink; ctx.lineWidth = 1;
  roundRect(101, 288, 264, 64, 14); ctx.stroke();
  drawIcon(TPIcon.food, 110, 296, 3);
  drawIcon(TPIcon.berryBlue, 176, 296, 3);
  drawIcon(TPIcon.berryGreen, 242, 296, 3);
  drawIcon(TPIcon.candy, 308, 296, 3);
}

// "Let it go?" -- the long-press confirmation, two buttons (TP.releaseYes/No).
const RELEASE_YES = { x: 118, y: 252, w: 100, h: 52 };
const RELEASE_NO = { x: 248, y: 252, w: 100, h: 52 };
function drawReleaseDialog() {
  ctx.fillStyle = UI.white;
  roundRect(94, 168, 278, 152, 16); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 1;
  roundRect(94, 168, 278, 152, 16); ctx.stroke();
  ctx.textAlign = "center";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 15px monospace";
  ctx.fillText(fns.releaseQuestion(), TP.cx, 208);
  ctx.fillStyle = UI.barOK;
  roundRect(RELEASE_YES.x, RELEASE_YES.y, RELEASE_YES.w, RELEASE_YES.h, 12); ctx.fill();
  ctx.fillStyle = UI.barBad;
  roundRect(RELEASE_NO.x, RELEASE_NO.y, RELEASE_NO.w, RELEASE_NO.h, 12); ctx.fill();
  ctx.fillStyle = UI.white;
  ctx.fillText(fns.yesText(), RELEASE_YES.x + RELEASE_YES.w / 2, RELEASE_YES.y + 32);
  ctx.fillText(fns.noText(), RELEASE_NO.x + RELEASE_NO.w / 2, RELEASE_NO.y + 32);
}

// Same 8-slot picker as PetScreen.swift's langCodes/isDexKorean, kept in
// the same order since it's also the raw index tp_set_language() expects.
const LANG_CODES = ["ES", "EN", "FR", "DE", "IT", "PT", "KR", "kr"];
const SND_PILL = { x: 34, y: 296, w: 96, h: 30 };
const LANG_PILL = { x: 336, y: 296, w: 96, h: 30 };
// Settings pill labels come from the string table (S_SND_OFF/VIB/FULL).
const SND_LABELS = { get [0]() { return fns.soundModeLabel(0); },
                     get [1]() { return fns.soundModeLabel(1); },
                     get [2]() { return fns.soundModeLabel(2); } };

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
// Labels come from the string table (pet.ballRecordLabel etc. on iOS), so
// a Korean UI shows 공놀이/캐치/패턴 기억/청소/타입 here too.
const GAME_TILES = [
  { x: 92, y: 168, w: 138, h: 78, label: () => fns.ballRecordLabel(), color: UI.barBad, hi: () => fns.gameHigh() },
  { x: 236, y: 168, w: 138, h: 78, label: () => fns.catchRecordLabel(), color: UI.barWarn, hi: () => fns.catchHigh() },
  { x: 92, y: 254, w: 138, h: 78, label: () => fns.memoRecordLabel(), color: "#4C98D9", hi: () => fns.memoHigh() },
  { x: 236, y: 254, w: 138, h: 78, label: () => fns.cleanRecordLabel(), color: UI.barOK, hi: () => fns.cleanHigh() },
  { x: 92, y: 340, w: 282, h: 30, label: () => fns.typeRecordLabel(), color: "#F3B7D9", hi: () => fns.typeHigh() },
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
  ctx.fillText(fns.playTitle(), TP.cx, 140);

  for (const t of GAME_TILES) {
    ctx.fillStyle = t.color;
    roundRect(t.x, t.y, t.w, t.h, 14);
    ctx.fill();
    ctx.strokeStyle = UI.ink;
    roundRect(t.x, t.y, t.w, t.h, 14);
    ctx.stroke();
    ctx.fillStyle = UI.bgDay;
    ctx.font = "bold 15px monospace";
    ctx.textBaseline = "middle";
    // PetScreen's tiles carry the label alone, centred; the record shows
    // inside each game instead.
    ctx.fillText(t.label(), t.x + t.w / 2, t.y + t.h / 2);
    ctx.textBaseline = "alphabetic";
  }
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
// Bitmap-font size -> canvas font, matching TPGraphics' 6px-per-size glyph
// widths closely enough that iOS's x positions land in the same places.
function gfxFont(size) {
  return `bold ${[0, 11, 15, 20, 28, 34, 40][size] || 15}px monospace`;
}
// gfxTextCentered / gfxText with iOS's "y is the text's top" convention.
function gfxTextC(text, y, size, color) {
  ctx.font = gfxFont(size); ctx.fillStyle = color;
  ctx.textAlign = "center"; ctx.textBaseline = "top";
  ctx.fillText(text, TP.cx, y);
  ctx.textBaseline = "alphabetic";
}
function gfxTextL(text, x, y, size, color) {
  ctx.font = gfxFont(size); ctx.fillStyle = color;
  ctx.textAlign = "left"; ctx.textBaseline = "top";
  ctx.fillText(text, x, y);
  ctx.textBaseline = "alphabetic";
}
// TP.textTop(centeredOn:size:) -- the top y that centres a line on cy.
function gfxTop(cy, size) { return cy - ([0, 11, 15, 20, 28, 34, 40][size] || 15) / 2; }

// Shared "SCORE: N" + record/new-record card the four newer minigames show
// (gain line optional), laid out as PetScreen.swift's renderCatchGame etc.
function drawGameOverCard(ink, score, newHigh, high, gainLine, gainColor) {
  gfxTextC(fns.scoreLine(score), gainLine ? 148 : 160, 4, ink);
  if (gainLine) gfxTextC(gainLine, 204, 3, gainColor);
  const y = gainLine ? 256 : 214;
  if (newHigh && score > 0) gfxTextC(fns.newRecordText(), y, 2, UI.barWarn);
  else gfxTextC(fns.recordLine(high), y, 2, ink);
}
// The three-dot miss counter at y 104 every minigame shares.
function drawMisses(misses) {
  for (let i = 0; i < 3; i++) {
    ctx.beginPath();
    ctx.arc(180 + i * 28, 104, 6, 0, Math.PI * 2);
    if (i < 3 - misses) { ctx.fillStyle = UI.barBad; ctx.fill(); }
    else { ctx.strokeStyle = UI.track; ctx.lineWidth = 2; ctx.stroke(); }
  }
}
function drawTimeBar(y, h, leftMs, totalMs) {
  const bw = 280;
  const fw = bw * Math.min(leftMs, totalMs) / totalMs;
  ctx.fillStyle = UI.track;
  roundRect(TP.cx - bw / 2, y, bw, h, 5); ctx.fill();
  if (fw > 2) { ctx.fillStyle = UI.barOK; roundRect(TP.cx - bw / 2, y, fw, h, 5); ctx.fill(); }
}

// Ports renderBallGame(): the day/night habitat backdrop, score + lives,
// the creature chasing the ball, the ball itself, and the impact ring --
// stops short of the falling-poop/weather flourishes SceneRenderer.swift
// draws, since that renderer isn't ported yet either (see roadmap).
function drawBallGame(now) {
  const { night, ink } = drawGameScene();

  if (BallGame.overUntil !== 0) {
    drawGameOverCard(ink, BallGame.score, BallGame.newHigh, fns.gameHigh());
    gfxTextC(BallGame.score >= 10 ? fns.greatJoyText() : fns.plusJoyText(), 250, 2, ink);
    if (now >= BallGame.overUntil) { screen = "idle"; BallGame.running = false; }
    statusEl.textContent = `Ball · game over · score ${BallGame.score}`;
    return;
  }

  // renderBallGame: big score centred at the top, the record under it,
  // three lives.
  gfxTextC(`${BallGame.score}`, 30, 4, ink);
  gfxTextC(fns.recLine(fns.gameHigh()), 76, 2, ink);
  drawMisses(BallGame.misses);

  // The creature chases the ball -- reuses drawPet's sprite/fallback but at
  // a ground line matching upstream's game-scene y (394, not petGround).
  if (currentSprite) {
    // Walks toward the ball, as renderBallGame does on iOS: walkR/walkL
    // by which side the ball is on, idle if the sheet has no walk frames.
    let act = TPAct.idle;
    if (BallGame.ballX > BallGame.petX + 4) act = TPAct.walkR;
    else if (BallGame.ballX < BallGame.petX - 4) act = TPAct.walkL;
    if (!spriteHas(currentSprite, act)) act = TPAct.idle;
    const a = currentSprite.actions[act];
    if (a) {
      const elapsed = performance.now() - poseStart;
      const frame = frameIndexAt(a, elapsed, true);
      const img = frameImageData(currentSprite, act, frame);
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

  // The ball is the firmware's own pokeball glyph, same as PetScreen.swift's
  // renderBallGame: 16x16 at scale 3, centred on the ball's position.
  drawIcon(TPIcon.play, BallGame.ballX - 24, BallGame.ballY - 24, 3);

  statusEl.textContent = `Ball · score ${BallGame.score} · misses ${BallGame.misses}/3`;
}

// Ports renderCatchGame(): a target that shrinks its own patience bar,
// three lives, and the day/night backdrop shared with Ball.
function drawCatchGame(now) {
  const { night, ink } = drawGameScene();
  const g = CatchGame;

  if (g.overUntil !== 0) {
    drawGameOverCard(ink, g.score, g.newHigh, fns.catchHigh());
    gfxTextC(g.score >= 10 ? fns.greatJoyText() : fns.plusJoyText(), 250, 2, ink);
    if (now >= g.overUntil) screen = "idle";
    statusEl.textContent = `Catch · game over · score ${g.score}`;
    return;
  }

  gfxTextC(fns.catchTitle(), 32, 3, ink);
  gfxTextL(fns.scoreLine(g.score), 50, 78, 2, ink);
  gfxTextL(fns.recLine(fns.catchHigh()), 294, 78, 2, ink);
  drawMisses(g.misses);

  ctx.beginPath();
  ctx.arc(g.targetX, g.targetY, 34, 0, Math.PI * 2);
  ctx.fillStyle = UI.white; ctx.fill();
  ctx.strokeStyle = UI.barWarn; ctx.lineWidth = 2; ctx.stroke();
  // The target is the same berry/food glyph PetScreen.swift's renderCatchGame
  // draws (food / blue berry / green berry by g.icon), 16x16 at scale 3.
  const catchIcon = g.icon === 0 ? TPIcon.food : (g.icon === 1 ? TPIcon.berryBlue : TPIcon.berryGreen);
  drawIcon(catchIcon, g.targetX - 24, g.targetY - 24, 3);

  drawTimeBar(362, 16, g.targetUntil > now ? g.targetUntil - now : 0, 20000);

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
  const { night, ink } = drawGameScene();
  const g = MemoGame;

  if (g.overUntil !== 0) {
    drawGameOverCard(ink, g.rounds, g.newHigh, fns.memoHigh(), fns.defGainLine(g.gain || 0), rgb565(0x4C98));
    if (now >= g.overUntil) screen = "idle";
    statusEl.textContent = `Memo · game over · rounds ${g.rounds}`;
    return;
  }

  gfxTextC(fns.memoRecordLabel(), 34, 3, ink);
  gfxTextL(fns.roundLine(g.rounds + 1), 60, 82, 2, ink);
  gfxTextL(fns.recLine(fns.memoHigh()), 310, 82, 2, ink);

  // Four round pads, as renderMemoGame draws them: bad/warn/blue/ok, the
  // active one lightened with a pulsing ring, a good/bad double ring on
  // the pad just pressed.
  const cols565 = [0xEA87, 0xED07, 0x4C98, 0x5DCD];
  const active = g.showing ? g.activePad : (g.failUntil !== 0 ? g.hintPad : -1);
  for (let i = 0; i < 4; i++) {
    const px = g.padX[i], py = g.padY[i];
    const fill = i === active ? lerp565(cols565[i], 0xFFFF, 5, 8) : cols565[i];
    ctx.fillStyle = rgb565(fill);
    ctx.beginPath(); ctx.arc(px, py, 48, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = ink; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(px, py, 52, 0, Math.PI * 2); ctx.stroke();
    if (i === active) {
      const pulse = 56 + (Math.floor(now / 70) % 5);
      ctx.strokeStyle = rgb565(cols565[i]);
      ctx.beginPath(); ctx.arc(px, py, pulse, 0, Math.PI * 2); ctx.stroke();
    }
    if (i === g.flashPad && now < g.flashUntil) {
      ctx.strokeStyle = g.flashGood ? UI.barOK : UI.barBad;
      ctx.beginPath(); ctx.arc(px, py, 60, 0, Math.PI * 2); ctx.stroke();
      ctx.beginPath(); ctx.arc(px, py, 64, 0, Math.PI * 2); ctx.stroke();
    }
  }

  const phase = g.failUntil !== 0 ? fns.memoWrongText()
              : g.showing ? fns.memoWatchText()
              : fns.memoTurnLine(g.input, g.seq.length);
  ctx.fillStyle = UI.bgDay;
  roundRect(78, 230, 310, 24, 7); ctx.fill();
  ctx.strokeStyle = ink; ctx.lineWidth = 1;
  roundRect(78, 230, 310, 24, 7); ctx.stroke();
  const phaseColor = g.failUntil !== 0 ? UI.barBad : (g.showing ? UI.barWarn : UI.barOK);
  gfxTextC(phase, gfxTop(230 + 12, 2), 2, phaseColor);

  statusEl.textContent = `Memo · round ${g.rounds + 1} · ${g.showing ? "playback" : "input"}`;
}

// Ports renderCleanGame(): dirt spots to scrub within a countdown.
function drawCleanGame(now) {
  const { night, ink } = drawGameScene();
  const g = CleanGame;

  if (g.overUntil !== 0) {
    drawGameOverCard(ink, g.score, g.newHigh, fns.cleanHigh(), fns.hygGainLine(g.gain || 0), UI.barOK);
    if (now >= g.overUntil) screen = "idle";
    statusEl.textContent = `Clean · game over · score ${g.score}`;
    return;
  }

  gfxTextC(fns.cleanTitle(), 32, 3, ink);
  gfxTextL(fns.scoreLine(g.score), 50, 78, 2, ink);
  gfxTextL(fns.recLine(fns.cleanHigh()), 294, 78, 2, ink);
  drawMisses(g.misses);
  drawTimeBar(362, 16, g.until > now ? g.until - now : 0, 18000);

  // Dirt blobs, as PetScreen.swift's renderCleanGame draws them: a brown
  // disc with an ink outline and two darker spots -- not a bubble emoji.
  for (let i = 0; i < 4; i++) {
    if (!g.alive[i]) continue;
    ctx.fillStyle = "rgb(138,102,69)";
    ctx.beginPath(); ctx.arc(g.x[i], g.y[i], 26, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = UI.ink; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(g.x[i], g.y[i], 28, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = "rgb(98,69,46)";
    ctx.beginPath(); ctx.arc(g.x[i] - 8, g.y[i] - 8, 5, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.arc(g.x[i] + 10, g.y[i] + 4, 6, 0, Math.PI * 2); ctx.fill();
  }
  const since = now - g.hitAt;
  if (g.hitAt !== 0 && since < 220) {
    ctx.strokeStyle = UI.barOK; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(g.hitX, g.hitY, 42 + since / 8, 0, Math.PI * 2); ctx.stroke();
  }

  statusEl.textContent = `Clean · score ${g.score} · misses ${g.misses}/3`;
}

// Ports renderTypeGame(): the attacking type shown at top, three answer
// rows, a countdown bar per question.
// TPPet.mm's kTypeNames / TPTypeColor: deliberately English in every
// language (upstream keeps them outside the string table), same colours.
const TYPE_NAMES = ["", "NORMAL", "FIRE", "WATER", "ELEC", "GRASS", "ICE",
  "FIGHT", "POISON", "GROUND", "FLY", "PSY", "BUG", "ROCK", "GHOST",
  "DRAGON", "DARK", "STEEL", "FAIRY"];
const TYPE_COLORS_565 = [0x8C4D, 0x8C4D, 0xEA87, 0x4C98, 0xBCA1, 0x3C49, 0x5D99, 0xA2A5,
  0x8A73, 0xB447, 0x8D7F, 0xD28F, 0x7CC4, 0x9407, 0x6B33, 0x5A5F, 0x5ACB, 0xA534, 0xF3B7];
function typeColor565(t) { return TYPE_COLORS_565[t] || 0x8C4D; }

function drawTypeGame(now) {
  const { night, ink } = drawGameScene();
  const g = TypeGame;

  if (g.overUntil !== 0) {
    drawGameOverCard(ink, g.score, g.newHigh, fns.typeHigh(), fns.atkGainLine(g.gain || 0), UI.barBad);
    if (now >= g.overUntil) screen = "idle";
    statusEl.textContent = `Type · game over · score ${g.score}`;
    return;
  }

  gfxTextC(fns.typeTitle(), 32, 3, ink);
  gfxTextL(fns.scoreLine(g.score), 50, 78, 2, ink);
  gfxTextL(fns.recLine(fns.typeHigh()), 294, 78, 2, ink);
  drawMisses(g.misses);

  // The type to beat, in its own colour, then three answer buttons.
  ctx.fillStyle = rgb565(lerp565(typeColor565(g.enemy), 0xFFFF, 4, 8));
  roundRect(118, 126, 230, 54, 14); ctx.fill();
  ctx.strokeStyle = ink; ctx.lineWidth = 1;
  roundRect(118, 126, 230, 54, 14); ctx.stroke();
  gfxTextC(TYPE_NAMES[g.enemy], gfxTop(126 + 27, 3), 3, UI.ink);

  for (let i = 0; i < 3; i++) {
    const bx = 88, by = 210 + i * 60;
    ctx.fillStyle = rgb565(lerp565(typeColor565(g.choices[i]), 0xFFFF, 5, 8));
    roundRect(bx, by, 290, 48, 12); ctx.fill();
    ctx.strokeStyle = ink; ctx.lineWidth = 1;
    roundRect(bx, by, 290, 48, 12); ctx.stroke();
    gfxTextC(TYPE_NAMES[g.choices[i]], gfxTop(by + 24, 2), 2, UI.ink);
  }

  drawTimeBar(392, 14, g.until > now ? g.until - now : 0, 4200);

  statusEl.textContent = `Type · score ${g.score} · misses ${g.misses}/3`;
}

// Ports renderSack(): a swinging punching bag, tapped for ten seconds.
function drawSackGame(now) {
  const { night, ink } = drawGameScene();

  if (Module._tp_sack_is_over() !== 0) {
    gfxTextC(fns.hitsLine(), 150, 4, ink);
    gfxTextC(fns.strengthGainLine(), 210, 3, UI.barBad);
    const newHigh = fns.sackNewHigh() !== 0;
    if (newHigh && fns.sackHits() > 0) gfxTextC(fns.newRecordText(), 256, 2, UI.barWarn);
    else gfxTextC(fns.recordLine(fns.strengthHigh2()), 256, 2, ink);
    if (Module._tp_sack_over_until_reached(now)) screen = "card";
    statusEl.textContent = `Sack · done · ${fns.sackHits()} hits`;
    return;
  }

  // renderSack: rope, chain, the bag with a band, the hit count, the
  // "hit fast!" hint and the 10-second countdown bar.
  const off = SackGame.shake * Math.sin(now * 0.05);
  const sx = TP.cx + off, top = 86;
  ctx.fillStyle = ink;
  ctx.fillRect(TP.cx - 3, 56, 6, top - 56);
  ctx.fillRect(sx - 4, top - 30, 8, 34);
  ctx.fillStyle = "rgb(181,58,58)";
  roundRect(sx - 42, top, 84, 150, 26); ctx.fill();
  ctx.fillStyle = "rgb(126,40,40)";
  roundRect(sx - 42, top, 84, 22, 18); ctx.fill();
  ctx.strokeStyle = ink; ctx.lineWidth = 1;
  roundRect(sx - 42, top, 84, 150, 26); ctx.stroke();
  ctx.fillStyle = "rgb(126,40,40)";
  ctx.fillRect(sx - 42, top + 70, 84, 4);

  gfxTextC(`${fns.sackHits()}`, 268, 6, ink);
  gfxTextC(fns.hitFastText(), 322, 2, ink);
  drawTimeBar(350, 16, fns.sackMsLeft(now | 0), 10000);

  statusEl.textContent = `Sack · ${fns.sackHits()} hits`;
}

// --- Starter picker --------------------------------------------------------
//
// PetScreen.swift's renderStarterSelect: the one screen a fresh save shows
// before anything else. Nine starters, one generation's trio per page,
// swiped like the stat card; a language pill top-right because Settings
// isn't reachable yet and chooseStarter() only ever runs once.
const STARTER_ROWS = 3, STARTER_ROW_H = 72, STARTER_ROW_GAP = 14;
const STARTER_LANG_PILL = { x: 300, y: 78, w: 96, h: 26 };
let starterPage = 0;
function starterRowY(row) { return 120 + row * (STARTER_ROW_H + STARTER_ROW_GAP); }
function starterPageCount() {
  return Math.max(1, Math.ceil(fns.starterCount() / STARTER_ROWS));
}

function drawStarterSelect() {
  ctx.fillStyle = UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "center";
  ctx.font = "bold 20px monospace";
  ctx.fillText(fns.chooseStarterTitle(), TP.cx, 62);

  const l = STARTER_LANG_PILL;
  ctx.fillStyle = UI.white;
  roundRect(l.x, l.y, l.w, l.h, 8); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 2;
  roundRect(l.x, l.y, l.w, l.h, 8); ctx.stroke();
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 13px monospace";
  ctx.fillText(`${LANG_CODES[fns.language()]} >`, l.x + l.w / 2, l.y + l.h / 2 + 5);

  const lang = fns.language();
  const genLabel = (lang === 6 || lang === 7) ? `${starterPage + 1}세대` : `GEN ${starterPage + 1}`;
  ctx.fillStyle = UI.track;
  ctx.font = "bold 18px monospace";
  ctx.fillText(genLabel, TP.cx, 98);

  const first = starterPage * STARTER_ROWS;
  const last = Math.min(first + STARTER_ROWS, fns.starterCount());
  for (let slot = first; slot < last; slot++) {
    const dex = fns.starterDex(slot);
    const accent = fns.dexAccent(dex);
    const ry = starterRowY(slot - first);
    ctx.fillStyle = rgb565(lerp565(accent, 0xFFFF, 6, 8));
    roundRect(70, ry, 326, STARTER_ROW_H, 12); ctx.fill();
    ctx.strokeStyle = rgb565(accent); ctx.lineWidth = 2;
    roundRect(70, ry, 326, STARTER_ROW_H, 12); ctx.stroke();
  }
  for (let slot = first; slot < last; slot++) {
    const dex = fns.starterDex(slot);
    const ry = starterRowY(slot - first);
    // Thumbnail beside the name, as upstream draws it -- from the user's
    // own sprite file if one is loaded, otherwise just a labelled row.
    const sprite = spriteFor(dex, false);
    if (sprite) drawDexThumb(sprite, 78, ry + 4, 64);
    const name = fns.dexName(dex);
    ctx.fillStyle = UI.ink;
    ctx.textAlign = "left";
    ctx.font = "bold 24px monospace";
    if (ctx.measureText(name).width > 240) ctx.font = "bold 17px monospace";
    ctx.textBaseline = "middle";
    ctx.fillText(name, 150, ry + STARTER_ROW_H / 2);
    ctx.textBaseline = "alphabetic";
  }

  const pages = starterPageCount();
  if (pages > 1) {
    const dotsX = TP.cx - (pages - 1) * 13;
    for (let i = 0; i < pages; i++) {
      const cx = dotsX + i * 26;
      ctx.beginPath(); ctx.arc(cx, 400, i === starterPage ? 5 : 4, 0, Math.PI * 2);
      if (i === starterPage) { ctx.fillStyle = UI.ink; ctx.fill(); }
      else { ctx.strokeStyle = UI.ink; ctx.lineWidth = 1; ctx.stroke(); }
    }
  }
  ctx.textAlign = "center";
  statusEl.textContent = "Choose your starter";
}

function starterTap(x, y) {
  if (inRect(x, y, STARTER_LANG_PILL)) {
    Module.ccall("tp_set_language", null, ["number"], [(fns.language() + 1) % LANG_CODES.length]);
    playSfx(0);
    return;
  }
  const first = starterPage * STARTER_ROWS;
  const last = Math.min(first + STARTER_ROWS, fns.starterCount());
  for (let slot = first; slot < last; slot++) {
    const ry = starterRowY(slot - first);
    if (x >= 70 && x <= 396 && y >= ry && y <= ry + STARTER_ROW_H) {
      Module._tp_choose_starter(fns.starterDex(slot));
      playSfx(0);
      // A once-only decision: persist it now rather than at the next
      // 15s autosave, so a reload/backgrounding in between can't lose it.
      saveNow(Module);
      return;
    }
  }
}

function draw() {
  if (!Module) return;

  // A fresh save picks its starter before any other screen exists --
  // same precedence as PetScreen.swift's render().
  if (fns.awaitingStarter() !== 0) {
    drawStarterSelect();
    return;
  }

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

  const now = performance.now();
  const isEgg = fns.isEgg() !== 0;
  const sleeping = fns.sleeping() !== 0;
  const hour = sceneHour();
  const night = sceneIsNight(hour, sleeping);
  const panel = night ? UI.bgNight : UI.bgDay;
  const ink = night ? UI.inkNight : UI.ink;

  // The creature's world: sky from the clock, ground from the species'
  // biome (an egg sits on the meadow) -- SceneRenderer.draw on iOS.
  const biome = isEgg ? 0 : fns.dexBiome(fns.speciesId());
  drawScene(biome, now, night, hour);

  // Header: name in the species' own accent colour (ink at night), status
  // line under it -- drawHeader on iOS.
  const nameColor = night ? UI.inkNight : rgb565(fns.dexAccent(fns.speciesId()));
  ctx.textAlign = "center";
  ctx.font = "bold 22px monospace";
  ctx.fillStyle = isEgg ? ink : nameColor;
  ctx.fillText(fns.headerName(), TP.cx, 60);
  ctx.font = "15px monospace";
  ctx.fillStyle = ink;
  ctx.fillText(isEgg ? fns.eggMessage() : fns.statusMessage(), TP.cx, 96);

  if (isEgg) {
    drawEgg(fns.eggCracks());
    ctx.fillStyle = panel;
    ctx.fillRect(0, 312, TP.screen, 154);
    // A rare/legendary egg says so under it; a common one says nothing.
    // Drawn after the panel, same order as PetScreen.swift (which used to
    // paint the label first and then fill the panel over it -- fixed there
    // at the same time this was ported).
    const rarity = fns.eggRarityLabel();
    if (rarity) {
      ctx.font = "bold 15px monospace";
      ctx.fillStyle = fns.eggRarity() === 3 ? UI.barWarn : rgb565(0x4C98);
      ctx.fillText(rarity, TP.cx, 330);
    }
    ctx.font = "bold 15px monospace";
    ctx.fillStyle = ink;
    ctx.fillText(fns.pokedexLine(), TP.cx, 356);
    statusEl.textContent = `EGG · ${fns.eggMessage()}`;
    return;
  }

  ensureSprite(fns.speciesId());
  drawStreakBadge(ink);
  drawPet(ink);
  drawBath(now);
  // Port of drawPetPMD's trailing heart draw, following the creature.
  if (fns.showHeart() !== 0) drawIcon(TPIcon.heart, petPose.x + 50, TP.petGround - 190, 2);

  // Poops, the firmware's own glyph -- 32x32 at scale 2, same spots as iOS.
  const poops = fns.poops();
  for (let i = 0; i < poops; i++) drawIcon(TPIcon.poop, 36 + i * 46, 244, 2);

  // Bottom panel + bars
  ctx.fillStyle = panel;
  ctx.fillRect(0, 312, TP.screen, 154);
  ctx.textAlign = "left";
  drawBar(78, 318, fns.barLabel(0), fns.fullness(), ink);
  drawBar(244, 318, fns.barLabel(1), fns.joy(), ink);
  drawBar(78, 346, fns.barLabel(2), fns.energy(), ink);
  drawBar(244, 346, fns.barLabel(3), fns.hygiene(), ink);
  ctx.textBaseline = "alphabetic";

  // Buttons: asleep, only the light button stays lit -- drawButtons on iOS.
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
    // 16x16 at scale 2, drawn from its top-left corner: the firmware's
    // `cx - 16, cy - 16` centres a 32px icon on the button.
    if (!off) drawIcon(b.icon(), b.x - 16, b.y - 16, 2);
  }

  drawCelebration();

  // Evolve/farewell/runaway call-to-action, and its confirmation dialog --
  // same precedence as PetScreen.swift's render(): evolve first, then
  // runaway, then the voluntary farewell.
  if (!isEgg) drawExpeditionHud();
  if (!isEgg) drawEvolveEndingOverlay(now);

  if (sleeping) {
    ctx.font = "bold 28px monospace";
    ctx.fillStyle = UI.inkNight;
    ctx.textAlign = "left";
    ctx.fillText("Zz", 320, 140);
  }
  if (now < feedMenuUntil) drawFeedMenu(ink);
  if (now < confirmUntil) drawReleaseDialog();
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
  if (fns.awaitingStarter() !== 0) {
    starterTap(x, y);
    return;
  }
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
  // From here on this is PetScreen.swift's idle-screen onTap, in its order.
  const now = performance.now();

  // A decision dialog swallows the tap whether or not it hit an option.
  if (choice !== "none") {
    choiceDialogTap(x, y);
    return;
  }
  // The release confirmation swallows the tap and closes either way.
  if (now < confirmUntil) {
    if (x >= RELEASE_YES.x && x <= RELEASE_YES.x + RELEASE_YES.w &&
        y >= RELEASE_YES.y && y <= RELEASE_YES.y + RELEASE_YES.h) {
      Module._tp_release();
    }
    confirmUntil = 0;
    return;
  }
  if (fns.ceremony() !== 0) return;  // no buttons during a ceremony

  // Feed menu: pick by column, any other tap just closes it.
  if (now < feedMenuUntil) {
    if (y >= 288 && y <= 352 && x >= 101 && x <= 365) {
      const item = Math.floor((x - 101) / 66);
      if (item === 3) Module._tp_feed_candy(); else Module._tp_feed_berry(item);
      playSfx(1); // eat
    }
    feedMenuUntil = 0;
    return;
  }

  if (fns.isEgg() !== 0) {
    Module._tp_egg_tap();
    playSfx(0); // tap
    saveNow(Module);   // cracks and the hatch itself are worth keeping immediately
    return;
  }

  if (evolveEndingTap(x, y)) return;
  if (fns.wildPromptActive() !== 0) {
    wildPromptTap(x, y);
    return;
  }

  // The four action buttons: round hit area (BTN_HIT 36), and while asleep
  // only the light button answers -- same as iOS.
  const sleeping = fns.sleeping() !== 0;
  for (let i = 0; i < BUTTONS.length; i++) {
    const b = BUTTONS[i];
    const dx = x - b.x, dy = y - b.y;
    if (dx * dx + dy * dy > 36 * 36) continue;
    if (sleeping && i !== 2) return;
    playSfx(0); // tap
    b.action(now);
    return;
  }

  // inPetZone(): tapping the creature pets it.
  if (x > 110 && x < 356 && y > 95 && y < 310) {
    Module._tp_caress();
    if (!sleeping) playSfx(3); // heart (audio.js EFFECTS[3]; 2 is "play")
  }
}

// Whether a drag should be read as a swipe at all -- ports PetScreen.swift's
// `swipeAllowed`. A stray drag mid-minigame (or a second finger landing
// during a tap, which SwiftUI/the DOM can both report as a large jump) must
// not be read as "swipe out of the game."
function swipeAllowed() {
  if (screen === "game" || screen === "battle" || screen === "gamemenu") return false;
  // Same extra gates as PetScreen.swift's swipe guard: an open feed menu
  // or release dialog owns the touch until it closes.
  const now = performance.now();
  if (now < feedMenuUntil || now < confirmUntil) return false;
  return choice === "none" && fns.wildPromptActive() === 0;
}

// Ports PetScreen.swift's onSwipe (horizontal): from idle, any horizontal
// swipe opens the dex; on the dex/card, it turns pages; dir 1 = swiped
// right, -1 = swiped left (left advances, matching upstream).
function onSwipe(dir) {
  if (fns.awaitingStarter() !== 0) {
    starterPage = Math.min(Math.max(starterPage + (dir > 0 ? -1 : 1), 0), starterPageCount() - 1);
    return;
  }
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
  if (fns.awaitingStarter() !== 0) return;   // the picker only pages sideways
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
let dragStartAt = 0;
let dragNow = null;
let holdFired = false;
function toScreenSpace(clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  const sx = TP.screen / rect.width, sy = TP.screen / rect.height;
  return { x: (clientX - rect.left) * sx, y: (clientY - rect.top) * sy };
}

// Long-press on the creature opens the release ("let it go?") dialog --
// PetScreen.swift's hold check: 3s held within 30px of where it started, on
// the idle screen, inside the pet zone, with nothing else open. Polled from
// the frame loop the same way iOS polls it from its tick.
function checkHold(now) {
  if (holdFired || screen !== "idle" || !dragStart || !dragNow) return;
  if (now - dragStartAt <= 3000) return;
  if (Math.abs(dragNow.x - dragStart.x) >= 30 || Math.abs(dragNow.y - dragStart.y) >= 30) return;
  const p = dragStart;
  if (!(p.x > 110 && p.x < 356 && p.y > 95 && p.y < 310)) return;   // inPetZone
  if (fns.isEgg() !== 0 || fns.ceremony() !== 0 || choice !== "none") return;
  if (now < confirmUntil || now < feedMenuUntil) return;
  confirmUntil = now + 10000;
  holdFired = true;
}

canvas.addEventListener("pointerdown", (e) => {
  if (!Module) return;
  dragStart = toScreenSpace(e.clientX, e.clientY);
  dragNow = dragStart;
  dragStartAt = performance.now();
  holdFired = false;
});
canvas.addEventListener("pointermove", (e) => {
  if (!Module || !dragStart) return;
  dragNow = toScreenSpace(e.clientX, e.clientY);
});
canvas.addEventListener("pointerup", (e) => {
  if (!Module || !dragStart) return;
  const from = dragStart;
  dragStart = null;
  dragNow = null;
  // A fired hold has already acted; upstream swallows the gesture rather
  // than also treating the release as a tap.
  if (holdFired) { holdFired = false; return; }
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
canvas.addEventListener("pointercancel", () => { dragStart = null; dragNow = null; holdFired = false; });

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
  if (!mod) return;   // cleared by "Reset game…" while the page unloads
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
  spriteLoading.clear(); // ...and an in-flight lookup must not block the refetch:
                     // spriteFor() skips species whose key is still in here, so a
                     // load that was mid-air during the import would otherwise
                     // leave that species stuck on its fallback until a reload
  currentDex = 0;    // force ensureSprite() to re-fetch for the active species
  loadingDex = -1;   // ...including one it already (unsuccessfully) tried
  await refreshThumbs();   // thumbs.bin may have been among the picked files
  spriteLoadBtn.textContent = n > 0 ? `Loaded ${n} file(s)` : "No p<dex>.bin / thumbs.bin found";
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

const cryLoadBtn = document.getElementById("cryLoad");
const cryInput = document.getElementById("cryInput");
cryLoadBtn.addEventListener("click", () => cryInput.click());
cryInput.addEventListener("change", async () => {
  const files = Array.from(cryInput.files || []);
  cryInput.value = "";
  if (files.length === 0) return;
  cryLoadBtn.textContent = "Loading…";
  const n = await importCryFiles(files);
  cryLoadBtn.textContent = n > 0 ? `Loaded ${n} cry file(s)` : "No psnd<dex>.m4a files found";
  setTimeout(() => { cryLoadBtn.textContent = "Load cries…"; }, 2500);
});

// --- Save file: export / import / reset --------------------------------------
//
// The save itself lives in this app's IndexedDB (a web page cannot write
// into the phone's Files app on its own). These three buttons are the
// bridge to a real file, mirroring the iOS app's iTamaPoke-save.json /
// iTamaPoke-import.json flow: "Save file…" hands the current state to the
// share sheet (iPhone: "Save to Files" -> put it in your mons folder),
// "Load save…" reads one back and restarts on it, "Reset game…" wipes the
// save (not the sprites) and starts a fresh egg.
const SAVE_FILE_NAME = "iTamaPoke-save.tpsave";

async function exportSaveFile() {
  if (!Module) return;
  const bytes = exportStateBytes(Module);
  await writeSave(bytes);
  const blob = new Blob([bytes], { type: "application/octet-stream" });
  const file = new File([blob], SAVE_FILE_NAME, { type: "application/octet-stream" });
  try {
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      await navigator.share({ files: [file], title: "iTamaPoke save" });
      return;
    }
  } catch (e) {
    if (e && e.name === "AbortError") return;   // user closed the sheet
  }
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = SAVE_FILE_NAME;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
}

document.getElementById("saveExport").addEventListener("click", () => { exportSaveFile(); });

const saveInput = document.getElementById("saveInput");
document.getElementById("saveImport").addEventListener("click", () => saveInput.click());
saveInput.addEventListener("change", async () => {
  const f = saveInput.files && saveInput.files[0];
  saveInput.value = "";
  if (!f) return;
  const bytes = new Uint8Array(await f.arrayBuffer());
  // Same sanity check tp_import_state does: a 4-byte entry count first.
  if (bytes.length < 4) { alert("Not an iTamaPoke save file."); return; }
  if (!confirm("Replace the current creature with this save file?")) return;
  await writeSave(bytes);
  window.location.reload();   // the core reads the store before its first tick
});

document.getElementById("gameReset").addEventListener("click", async () => {
  if (!confirm("Start over with a new egg? The current creature, level and Pokédex are erased. Sprites stay.")) return;
  if (!confirm("Really erase the save? This cannot be undone.")) return;
  try {
    const db = await openDb();
    await new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      tx.objectStore(STORE_NAME).delete(SAVE_KEY);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch (e) {
    console.warn("[save] reset failed:", e);
  }
  // Stop the periodic autosave from writing the old state back before the
  // page has gone away.
  Module = null;
  window.location.reload();
});

loadSoundMode();
// Which species have a cry installed, so the dex detail's play control knows
// synchronously whether to draw itself at all.
refreshCryIndex();
// The Pokédex thumbnail atlas, if thumbs.bin has been loaded.
refreshThumbs();

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
    // Idle-screen presentation (TPPet.mm's headerName/statusMessage/egg*/
    // showHeart/mood + the celebration banner + release dialog + per-species
    // scene biome and header accent) -- see browser_glue.cpp's matching block.
    awaitingStarter: mod.cwrap("tp_awaiting_starter", "number", []),
    starterCount: mod.cwrap("tp_starter_count", "number", []),
    starterDex: mod.cwrap("tp_starter_dex", "number", ["number"]),
    chooseStarterTitle: mod.cwrap("tp_choose_starter_title", "string", []),
    headerName: mod.cwrap("tp_header_name", "string", []),
    statusMessage: mod.cwrap("tp_status_message", "string", []),
    eggCracks: mod.cwrap("tp_egg_cracks", "number", []),
    eggMessage: mod.cwrap("tp_egg_message", "string", []),
    eggRarity: mod.cwrap("tp_egg_rarity", "number", []),
    eggRarityLabel: mod.cwrap("tp_egg_rarity_label", "string", []),
    showHeart: mod.cwrap("tp_show_heart", "number", []),
    eating: mod.cwrap("tp_eating", "number", []),
    mood: mod.cwrap("tp_mood", "number", []),
    dexBiome: mod.cwrap("tp_dex_biome", "number", ["number"]),
    dexAccent: mod.cwrap("tp_dex_accent", "number", ["number"]),
    showMedal: mod.cwrap("tp_show_medal", "number", []),
    showMilestone: mod.cwrap("tp_show_milestone", "number", []),
    medalBannerTitle: mod.cwrap("tp_medal_banner_title", "string", []),
    milestoneTitle: mod.cwrap("tp_milestone_title", "string", []),
    newMedalName: mod.cwrap("tp_new_medal_name", "string", []),
    milestoneLine: mod.cwrap("tp_milestone_line", "string", []),
    releaseQuestion: mod.cwrap("tp_release_question", "string", []),
    yesText: mod.cwrap("tp_yes_text", "string", []),
    noText: mod.cwrap("tp_no_text", "string", []),
    battleWildAlreadyCaught: mod.cwrap("tp_battle_wild_already_caught", "number", []),
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
    streak: mod.cwrap("tp_streak", "number", []),
    bestStreak: mod.cwrap("tp_best_streak", "number", []),
    // Localized UI strings (see browser_glue.cpp's "Localized UI strings").
    playTitle: mod.cwrap("tp_play_title", "string", []),
    barLabel: mod.cwrap("tp_bar_label", "string", ["number"]),
    soundModeLabel: mod.cwrap("tp_sound_mode_label", "string", ["number"]),
    langLabel: mod.cwrap("tp_lang_label", "string", []),
    raisedCaughtLine: mod.cwrap("tp_raised_caught_line", "string", []),
    hitFastText: mod.cwrap("tp_hit_fast_text", "string", []),
    greatJoyText: mod.cwrap("tp_great_joy_text", "string", []),
    plusJoyText: mod.cwrap("tp_plus_joy_text", "string", []),
    catchTitle: mod.cwrap("tp_catch_title", "string", []),
    cleanTitle: mod.cwrap("tp_clean_title", "string", []),
    typeTitle: mod.cwrap("tp_type_title", "string", []),
    memoWatchText: mod.cwrap("tp_memo_watch_text", "string", []),
    memoWrongText: mod.cwrap("tp_memo_wrong_text", "string", []),
    memoTurnLine: mod.cwrap("tp_memo_turn_line", "string", ["number", "number"]),
    filterAllText: mod.cwrap("tp_filter_all_text", "string", []),
    caughtMarkText: mod.cwrap("tp_caught_mark_text", "string", []),
    detailBackText: mod.cwrap("tp_detail_back_text", "string", []),
    nameLabel: mod.cwrap("tp_name_label", "string", []),
    effectiveText: mod.cwrap("tp_effective_text", "string", []),
    notEffectiveText: mod.cwrap("tp_not_effective_text", "string", []),
    scoreLine: mod.cwrap("tp_score_line", "string", ["number"]),
    roundLine: mod.cwrap("tp_round_line", "string", ["number"]),
    recLine: mod.cwrap("tp_rec_line", "string", ["number"]),
    pokedexLine: mod.cwrap("tp_pokedex_line", "string", []),
    defGainLine: mod.cwrap("tp_def_gain_line", "string", ["number"]),
    hygGainLine: mod.cwrap("tp_hyg_gain_line", "string", ["number"]),
    atkGainLine: mod.cwrap("tp_atk_gain_line", "string", ["number"]),
    sackMsLeft: mod.cwrap("tp_sack_ms_left", "number", ["number"]),
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
    canEvolveNow: mod.cwrap("tp_can_evolve_now", "number", []),
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
    // Frozen while a decision dialog (evolve/farewell) is up -- tp_tick's
    // gPet.update() is a real-time catch-up loop keyed off millis(), so
    // stats keep decaying for as long as the page is open, dialog or not.
    // A stat sitting just above the evolve threshold when the dialog opened
    // could tick below it in the few seconds it takes to read "Evolve?" and
    // tap the button, so the confirm tap would silently fail against a
    // *now*-too-low stat even though every bar still looked fine when the
    // button was pressed. Skipping tp_tick() here doesn't erase that decay,
    // just defers it to resume the instant the dialog closes -- mirrors
    // PetScreen.swift's fix, same reasoning.
    if (choice === "none") mod.ccall("tp_tick", null, ["number"], [t | 0]);
    // The rest of GameModel.tick(): the idle creature's pose scheduler, the
    // bath timer (which is what actually washes the creature when it ends),
    // and the long-press check -- all on the tick, never in a draw.
    if (screen === "idle") {
      checkHold(t);
      advanceBehaviour(t, currentSprite, fns.mood());
      stepBath(t, currentSprite);
    }
    // A draw that throws must not kill the loop: on a phone there is no
    // console, so the only symptom would be a frozen "loading…" line. Show
    // the error there and keep ticking so the save still happens.
    try {
      draw();
    } catch (e) {
      statusEl.textContent = "error: " + (e && e.message ? e.message : e);
      console.error(e);
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
});
