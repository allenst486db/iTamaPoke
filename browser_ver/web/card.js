// Stat card, ported from PetScreen.swift's renderCard + its eight page
// functions. Profile/Personality/Battle/Medals/Progress live here;
// Daily/Box/Expedition are in expedition.js. Also the rename keyboard
// (renderKeyboard/keyboardTap).

let cardPage = 0;
const CARD_PAGE_COUNT = 8;
let nameDraft = "";

function drawCard(now) {
  ctx.fillStyle = UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);

  switch (cardPage) {
    case 0: drawCardProfile(now); break;
    case 1: drawCardPersonality(); break;
    case 2: drawCardDaily(); break;
    case 3: drawCardBox(); break;
    case 4: drawCardStats(); break;
    case 5: drawCardMedals(); break;
    case 6: drawCardProgress(); break;
    case 7: drawCardExpedition(); break;
  }

  const dotsX = TP.cx - (CARD_PAGE_COUNT - 1) * 13;
  for (let i = 0; i < CARD_PAGE_COUNT; i++) {
    const cx = dotsX + i * 26;
    ctx.beginPath();
    ctx.arc(cx, 382, i === cardPage ? 5 : 4, 0, Math.PI * 2);
    if (i === cardPage) { ctx.fillStyle = UI.ink; ctx.fill(); }
    else { ctx.strokeStyle = UI.ink; ctx.lineWidth = 1; ctx.stroke(); }
  }
  ctx.fillStyle = UI.track;
  ctx.textAlign = "center";
  ctx.font = "12px monospace";
  ctx.fillText(fns.backHint(), TP.cx, 400);
}

function drawCardProfile(now) {
  ctx.textAlign = "center";
  const head = fns.name();
  ctx.fillStyle = UI.ink;
  ctx.font = head.length <= 11 ? "bold 26px monospace" : "bold 20px monospace";
  ctx.fillText(head, TP.cx, head.length <= 11 ? 44 : 50);

  if (fns.hasNick() !== 0) {
    ctx.fillStyle = UI.track;
    ctx.font = "13px monospace";
    ctx.fillText(`(${fns.speciesName()})`, TP.cx, 70);
  }

  if (currentSprite) {
    const a = currentSprite.actions[TPAct.idle];
    if (a) {
      const frame = frameIndexAt(a, now, true);
      const img = frameImageData(currentSprite, TPAct.idle, frame);
      if (img) {
        const s = Math.min(spriteScale(currentSprite, a), 4);
        const w = a.w * s, h = a.h * s;
        frameCanvas.width = a.w; frameCanvas.height = a.h;
        frameCtx.putImageData(img, 0, 0);
        ctx.imageSmoothingEnabled = false;
        ctx.drawImage(frameCanvas, TP.cx - w / 2, 206 - (a.base > 0 ? a.base : a.h) * s, w, h);
      }
    }
  }

  // The same little flame the idle screen's streak badge uses, not an
  // emoji (which renders differently per platform, or not at all).
  drawFlame(118, 220, 16);
  ctx.textAlign = "left";
  ctx.font = "13px monospace";
  ctx.fillStyle = UI.ink;
  ctx.fillText(fns.streakLine(), 140, 232);

  const bondLabel = fns.bondLabel(), bond = fns.bond();
  ctx.fillText(bondLabel, 60, 262);
  ctx.fillStyle = UI.track;
  roundRect(150, 254, 160, 11, 3); ctx.fill();
  ctx.fillStyle = "#d4527e";
  roundRect(150, 254, 160 * Math.min(bond, 100) / 100, 11, 3); ctx.fill();
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "right";
  ctx.fillText(`${bond}`, 330, 262);

  ctx.textAlign = "center";
  ctx.fillText(fns.infoLine(), TP.cx, 300);
  ctx.fillStyle = UI.track;
  ctx.fillText(fns.renameHint(), TP.cx, 332);

  statusEl.textContent = `Card · ${head} · bond ${bond}`;
}

function personalityColor(kind) {
  return { 0: UI.barOK, 1: UI.barWarn, 2: UI.barBad, 3: "#4C98D9", 4: "#B3C8D9" }[kind] || UI.barOK;
}

function drawPersonalityRecord(x, y, label, value, color) {
  ctx.fillStyle = UI.white;
  roundRect(x, y, 118, 34, 8); ctx.fill();
  ctx.strokeStyle = color; ctx.lineWidth = 1;
  roundRect(x, y, 118, 34, 8); ctx.stroke();
  // Label and number share one vertical centre (the iOS build had them on
  // mismatched baselines until it was fixed there too).
  ctx.textBaseline = "middle";
  ctx.fillStyle = color;
  ctx.textAlign = "left";
  ctx.font = "10px monospace";
  ctx.fillText(label, x + 10, y + 17);
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 14px monospace";
  ctx.textAlign = "right";
  ctx.fillText(`${value}`, x + 108, y + 17);
  ctx.textBaseline = "alphabetic";
}

function drawCardPersonality() {
  const col = personalityColor(fns.personalityKind());
  ctx.textAlign = "center";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 20px monospace";
  ctx.fillText(fns.personalityTitle(), TP.cx, 50);

  ctx.fillStyle = col;
  roundRect(62, 86, 342, 70, 16); ctx.fill();
  ctx.fillStyle = UI.bgDay;
  ctx.font = "bold 18px monospace";
  ctx.fillText(fns.personalityName(), TP.cx, 116);
  ctx.font = "12px monospace";
  ctx.fillText(fns.personalityHint(), TP.cx, 140);

  ctx.textAlign = "left";
  ctx.fillStyle = UI.ink;
  ctx.font = "12px monospace";
  const bond = fns.bond();
  ctx.fillText(`${fns.bondLabel()} ${bond}`, 62, 200);
  ctx.fillStyle = UI.track;
  roundRect(160, 190, 150, 10, 3); ctx.fill();
  ctx.fillStyle = "#d4527e";
  roundRect(160, 190, 150 * Math.min(bond, 100) / 100, 10, 3); ctx.fill();

  ctx.textAlign = "center";
  ctx.fillStyle = UI.track;
  ctx.font = "11px monospace";
  ctx.fillText(fns.personalityAgeLine(), TP.cx, 246);
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 14px monospace";
  ctx.fillText(fns.recordsTitle(), TP.cx, 268);

  drawPersonalityRecord(52, 294, fns.ballRecordLabel(), fns.gameHigh(), UI.barOK);
  drawPersonalityRecord(178, 294, fns.catchRecordLabel(), fns.catchHigh(), UI.barWarn);
  drawPersonalityRecord(304, 294, fns.memoRecordLabel(), fns.memoHigh(), "#4C98D9");
  drawPersonalityRecord(52, 334, fns.cleanRecordLabel(), fns.cleanHigh(), UI.barOK);
  drawPersonalityRecord(178, 334, fns.typeRecordLabel(), fns.typeHigh(), "#F3B7D9");
  drawPersonalityRecord(304, 334, fns.statsBattleTitle(), fns.bestBattleStreak(), UI.barBad);

  statusEl.textContent = `Card · Personality · ${fns.personalityName()}`;
}

function drawStatBar(y, label, value, maxBar, color) {
  ctx.textAlign = "left";
  ctx.fillStyle = UI.ink;
  ctx.font = "12px monospace";
  ctx.fillText(label, 40, y + 15);
  ctx.textAlign = "right";
  ctx.fillText(`${value}`, 396, y + 15);
  ctx.fillStyle = UI.track;
  roundRect(150, y + 4, 160, 11, 3); ctx.fill();
  ctx.fillStyle = color;
  roundRect(150, y + 4, 160 * Math.min(value / maxBar, 1), 11, 3); ctx.fill();
}

function drawCardStats() {
  ctx.textAlign = "center";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 20px monospace";
  ctx.fillText(fns.statsBattleTitle(), TP.cx, 54);

  drawStatBar(112, fns.statLabel(0), fns.atkStat(), 260, UI.barBad);
  drawStatBar(154, fns.statLabel(1), fns.defStat(), 260, "#4C98D9");
  drawStatBar(196, fns.statLabel(2), fns.speStat(), 260, UI.barWarn);
  drawStatBar(238, fns.statLabel(3), fns.weight(), 100, "#B3C8D9");

  // Record line and the two full-width buttons, at PetScreen.swift's
  // renderCardStats positions (TP.wildBattleBtn / TP.trainBtn: 96,290 and
  // 96,332, 274x36) -- they used to sit side by side at other coordinates.
  ctx.textAlign = "left";
  ctx.fillStyle = UI.ink;
  ctx.font = "11px monospace";
  ctx.fillText(fns.battleRecordLine(), 74, 280);
  ctx.fillText(fns.battleStreakLine(), 210, 280);
  ctx.fillText(fns.battleBestLine(), 334, 280);

  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.font = "bold 14px monospace";
  ctx.fillStyle = "#4C98D9";
  roundRect(96, 290, 274, 36, 11); ctx.fill();
  ctx.fillStyle = UI.bgDay;
  ctx.fillText(fns.wildBattleText(), 96 + 137, 290 + 18);

  ctx.fillStyle = UI.barBad;
  roundRect(96, 332, 274, 36, 11); ctx.fill();
  ctx.fillStyle = UI.bgDay;
  ctx.fillText(fns.trainButtonText(), 96 + 137, 332 + 18);
  ctx.textBaseline = "alphabetic";

  statusEl.textContent = `Card · Battle stats`;
}

function cardStatsTap(x, y) {
  if (x >= 96 && x <= 370 && y >= 290 && y <= 326) {
    if (fns.battleCanStart() !== 0) {
      Module._tp_battle_start();
      battleReturn = "card";   // come back to this page when the battle closes
      screen = "battle";
    }
    return;
  }
  if (x >= 96 && x <= 370 && y >= 332 && y <= 368) {
    gameMode = 5;
    SackGame.start(performance.now());
    screen = "game";
  }
}

function drawCardMedals() {
  ctx.textAlign = "center";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 20px monospace";
  ctx.fillText(fns.medalsLine(), TP.cx, 54);

  const count = fns.medalCount();
  for (let i = 0; i < count; i++) {
    const x = 28 + (i % 2) * 206, y = 104 + Math.floor(i / 2) * 54;
    const got = fns.hasMedal(i) !== 0;
    ctx.fillStyle = got ? UI.barOK : UI.track;
    roundRect(x, y, 196, 44, 10); ctx.fill();
    ctx.fillStyle = got ? UI.bgDay : "#84888a";
    ctx.textAlign = "left";
    ctx.textBaseline = "middle";
    ctx.font = "12px monospace";
    ctx.fillText((got ? "✓ " : "") + fns.medalDescription(i), x + 12, y + 22);
    ctx.textBaseline = "alphabetic";
  }
  statusEl.textContent = `Card · ${fns.medalsLine()}`;
}

function drawCardProgress() {
  ctx.textAlign = "center";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 20px monospace";
  ctx.fillText(fns.progressTitle(), TP.cx, 50);

  ctx.font = "bold 40px monospace";
  ctx.fillText(fns.levelLine(), TP.cx, 106);

  const bx = 93, bw = 280, by = 158, bh = 22;
  ctx.fillStyle = UI.track;
  roundRect(bx, by, bw, bh, 6); ctx.fill();
  const fw = (bw - 4) * fns.minutesIntoLevel() / fns.minutesPerLevel();
  if (fw > 0) { ctx.fillStyle = UI.barOK; roundRect(bx + 2, by + 2, fw, bh - 4, 5); ctx.fill(); }
  ctx.fillStyle = UI.ink;
  ctx.font = "13px monospace";
  ctx.fillText(fns.nextLevelLine(), TP.cx, by + 45);

  ctx.fillStyle = UI.track;
  ctx.fillText(fns.evolutionLabel(), TP.cx, 236);
  const kind = fns.evolutionStatusKind();
  ctx.fillStyle = kind === 1 ? UI.barOK : kind === 2 ? UI.barBad : UI.ink;
  ctx.font = "bold 14px monospace";
  ctx.fillText(fns.evolutionStatus(), TP.cx, 260);

  ctx.fillStyle = fns.careMistakes() > 0 ? UI.barBad : UI.ink;
  ctx.font = "13px monospace";
  ctx.fillText(fns.mistakesLine(), TP.cx, 316);

  statusEl.textContent = `Card · ${fns.levelLine()}`;
}

function cardTap(x, y) {
  if (cardPage === 0 && y >= 320 && y <= 344) {
    // Start from the current nickname rather than blank, so a small fix
    // doesn't mean retyping the whole name.
    Module.ccall("tp_kb_set", null, ["string"], [fns.hasNick() !== 0 ? fns.name() : ""]);
    kbSync();
    screen = "keyboard";
    return;
  }
  if (cardPage === 4) cardStatsTap(x, y);
  if (cardPage === 3) cardBoxTap(x, y);
  if (cardPage === 7) cardExpeditionTap(x, y);
  if (y >= 370 && y <= 394) {
    // Page-dot row: tap left half to go back a page, right half forward.
    if (x < TP.cx) cardPage = (cardPage - 1 + CARD_PAGE_COUNT) % CARD_PAGE_COUNT;
    else cardPage = (cardPage + 1) % CARD_PAGE_COUNT;
    return;
  }
  // Only the "tap: back" hint itself closes the card now (also swipe up,
  // see main.js's onSwipeV) -- it used to be the entire rest of the page
  // below the buttons, same bug as PetScreen.swift's cardTap had (see its
  // own comment): any stray tap while reading a page, or mid-swipe, closed
  // the whole card.
  if (x >= 66 && x <= 400 && y >= 388 && y <= 420) screen = "idle";
}

// --- Rename keyboard -------------------------------------------------

// Two layouts over the same 6x5 grid. English is upstream's own A-Z set;
// Korean is every jamo as its own key, composed into syllables by
// Sources/Core/hangul.cpp (shared with the iOS keyboard). `null` is a gap,
// and the last two slots are always backspace and OK.
//
// Jamo ids match hangul.h's enum: consonants 0-18, vowels 19-39.
const KB_KEYS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ.-".split("");
// ㄱㄴㄷㄹㅁㅂ / ㅅㅇㅈㅊㅋㅌ / ㅍㅎㄲㄸㅃㅆ / ㅉㅏㅐㅑㅓㅔ / ㅕㅗㅛㅜㅠㅡ ... ㅣ
const KB_JAMO = [
  0, 2, 3, 5, 6, 7,          // ㄱ ㄴ ㄷ ㄹ ㅁ ㅂ
  9, 11, 12, 14, 15, 16,     // ㅅ ㅇ ㅈ ㅊ ㅋ ㅌ
  17, 18, 1, 4, 8, 10,       // ㅍ ㅎ ㄲ ㄸ ㅃ ㅆ
  13, 19, 20, 21, 23, 24,    // ㅉ ㅏ ㅐ ㅑ ㅓ ㅔ
  25, 27, 31, 32, 36, 37,    // ㅕ ㅗ ㅛ ㅜ ㅠ ㅡ
  39,                        // ㅣ  (row 6, first slot)
];
const KB_COLS = 6, KB_X = 40, KB_Y = 150, KB_W = 64, KB_H = 52;
const KB_LANG_PILL = { x: 300, y: 84, w: 82, h: 40 };
let kbKorean = false;

function kbRows() { return kbKorean ? 7 : 5; }
function kbSlots() { return kbKorean ? 41 : 30; }   // 39 jamo slots + <- + OK
function kbCount() { return kbKorean ? KB_JAMO.length : KB_KEYS.length; }

function drawKeyboard() {
  ctx.fillStyle = UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  ctx.textAlign = "center";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 18px monospace";
  ctx.fillText(fns.nameLabel(), TP.cx, 56);

  ctx.fillStyle = UI.white;
  roundRect(83, 84, 208, 40, 8); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 2;
  roundRect(83, 84, 208, 40, 8); ctx.stroke();
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "left";
  ctx.font = "bold 20px monospace";
  ctx.fillText(nameDraft || "_", 95, 112);

  // 한/영 toggle, in the same spot the starter picker puts its language pill.
  const p = KB_LANG_PILL;
  ctx.fillStyle = kbKorean ? UI.ink : UI.white;
  roundRect(p.x, p.y, p.w, p.h, 8); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 2;
  roundRect(p.x, p.y, p.w, p.h, 8); ctx.stroke();
  ctx.fillStyle = kbKorean ? UI.bgDay : UI.ink;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.font = "bold 15px monospace";
  ctx.fillText(kbKorean ? "한" : "ABC", p.x + p.w / 2, p.y + p.h / 2);
  ctx.textBaseline = "alphabetic";

  const rows = kbRows(), count = kbCount(), slots = kbSlots();
  const kh = kbKorean ? 42 : KB_H;
  for (let i = 0; i < slots; i++) {
    if (i >= count && i < slots - 2) continue;   // gap before <- / OK
    const x = KB_X + (i % KB_COLS) * KB_W, y = KB_Y + Math.floor(i / KB_COLS) * kh;
    const special = i >= slots - 2;
    ctx.fillStyle = special ? UI.barWarn : UI.white;
    roundRect(x, y, KB_W - 6, kh - 6, 6); ctx.fill();
    ctx.strokeStyle = UI.ink; ctx.lineWidth = 1;
    roundRect(x, y, KB_W - 6, kh - 6, 6); ctx.stroke();
    ctx.fillStyle = UI.ink;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.font = "bold 16px monospace";
    const label = special
      ? (i === slots - 2 ? "<-" : "OK")
      : (kbKorean ? fns.kbJamoText(KB_JAMO[i]) : KB_KEYS[i]);
    ctx.fillText(label, x + (KB_W - 6) / 2, y + (kh - 6) / 2);
    ctx.textBaseline = "alphabetic";
  }
  statusEl.textContent = `Rename · "${nameDraft}"`;
}

// The draft lives in the C++ automaton, not in JS, so an in-progress
// syllable survives a redraw and backspace can walk back jamo by jamo.
function kbSync() { nameDraft = fns.kbText(); }

function keyboardTap(x, y) {
  if (inRect(x, y, KB_LANG_PILL)) {
    kbKorean = !kbKorean;
    Module.ccall("tp_kb_set", null, ["string"], [nameDraft]);  // stop composing
    playSfx(0);
    return;
  }
  const kh = kbKorean ? 42 : KB_H;
  const col = Math.floor((x - KB_X) / KB_W), row = Math.floor((y - KB_Y) / kh);
  if (col < 0 || col >= KB_COLS || row < 0 || row >= kbRows()) return;
  const i = row * KB_COLS + col;
  const slots = kbSlots();
  if (i >= slots) return;
  if (i === slots - 2) {
    Module._tp_kb_backspace();
    kbSync();
    return;
  }
  if (i === slots - 1) {
    Module.ccall("tp_rename", null, ["string"], [fns.kbText()]);
    screen = "card";
    return;
  }
  if (i >= kbCount()) return;
  // Stop one character short of what Pet::nick can hold, so nothing the
  // keyboard shows is silently truncated by rename().
  const cap = fns.nickCapacity();
  if (kbKorean) {
    if (fns.kbByteLen() + 3 > cap) { playSfx(7); return; }
    Module._tp_kb_jamo(KB_JAMO[i]);
  } else {
    if (fns.kbByteLen() + 1 > cap || fns.kbCharLen() >= 11) { playSfx(7); return; }
    Module.ccall("tp_kb_ascii", null, ["number"], [KB_KEYS[i].charCodeAt(0)]);
  }
  kbSync();
}
