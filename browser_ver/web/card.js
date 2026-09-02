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

  ctx.textAlign = "left";
  ctx.font = "13px monospace";
  ctx.fillStyle = UI.ink;
  ctx.fillText(`🔥 ${fns.streakLine()}`, 138, 232);

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
  ctx.fillStyle = color;
  ctx.textAlign = "left";
  ctx.font = "10px monospace";
  ctx.fillText(label, x + 10, y + 15);
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 14px monospace";
  ctx.textAlign = "right";
  ctx.fillText(`${value}`, x + 108, y + 24);
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

  ctx.textAlign = "left";
  ctx.fillStyle = UI.ink;
  ctx.font = "11px monospace";
  ctx.fillText(fns.battleRecordLine(), 40, 276);
  ctx.fillText(fns.battleStreakLine(), 176, 276);
  ctx.fillText(fns.battleBestLine(), 300, 276);

  ctx.fillStyle = "#4C98D9";
  roundRect(40, 296, 160, 40, 11); ctx.fill();
  ctx.fillStyle = UI.bgDay;
  ctx.textAlign = "center";
  ctx.font = "bold 13px monospace";
  ctx.fillText(fns.wildBattleText(), 120, 320);

  ctx.fillStyle = UI.barBad;
  roundRect(216, 296, 160, 40, 11); ctx.fill();
  ctx.fillStyle = UI.bgDay;
  ctx.fillText(fns.trainButtonText(), 296, 320);

  statusEl.textContent = `Card · Battle stats`;
}

function cardStatsTap(x, y) {
  if (x >= 40 && x <= 200 && y >= 296 && y <= 336) {
    if (fns.battleCanStart() !== 0) {
      Module._tp_battle_start();
      screen = "battle";
    }
    return;
  }
  if (x >= 216 && x <= 376 && y >= 296 && y <= 336) {
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
    ctx.font = "12px monospace";
    ctx.fillText((got ? "✓ " : "") + fns.medalDescription(i), x + 12, y + 27);
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
    nameDraft = "";
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

const KB_KEYS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ.-".split("");
const KB_COLS = 6, KB_X = 40, KB_Y = 150, KB_W = 64, KB_H = 52;

function drawKeyboard() {
  ctx.fillStyle = UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  ctx.textAlign = "center";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 18px monospace";
  ctx.fillText("NAME", TP.cx, 56);

  ctx.fillStyle = UI.white;
  roundRect(83, 84, 300, 40, 8); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 2;
  roundRect(83, 84, 300, 40, 8); ctx.stroke();
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "left";
  ctx.font = "bold 20px monospace";
  ctx.fillText(nameDraft || "_", 95, 112);

  for (let i = 0; i < 30; i++) {
    const x = KB_X + (i % KB_COLS) * KB_W, y = KB_Y + Math.floor(i / KB_COLS) * KB_H;
    const special = i >= 28;
    ctx.fillStyle = special ? UI.barWarn : UI.white;
    roundRect(x, y, KB_W - 6, KB_H - 6, 6); ctx.fill();
    ctx.strokeStyle = UI.ink; ctx.lineWidth = 1;
    roundRect(x, y, KB_W - 6, KB_H - 6, 6); ctx.stroke();
    ctx.fillStyle = UI.ink;
    ctx.textAlign = "center";
    ctx.font = "bold 16px monospace";
    ctx.fillText(i < 28 ? KB_KEYS[i] : (i === 28 ? "<-" : "OK"), x + (KB_W - 6) / 2, y + (KB_H - 6) / 2 + 6);
  }
  statusEl.textContent = `Rename · "${nameDraft}"`;
}

function keyboardTap(x, y) {
  const col = Math.floor((x - KB_X) / KB_W), row = Math.floor((y - KB_Y) / KB_H);
  if (col < 0 || col >= KB_COLS || row < 0 || row >= 5) return;
  const i = row * KB_COLS + col;
  if (i >= 30) return;
  if (i === 28) {
    if (nameDraft.length > 0) nameDraft = nameDraft.slice(0, -1);
  } else if (i === 29) {
    Module.ccall("tp_rename", null, ["string"], [nameDraft]);
    screen = "card";
  } else if (nameDraft.length < 11) {
    nameDraft += KB_KEYS[i];
  }
}
