// Stat card (profile page only -- personality/daily/box/battle/medals/
// progress/expedition aren't ported, see browser_ver/README.md) and the
// rename keyboard, ported from PetScreen.swift's renderCardProfile /
// renderKeyboard / keyboardTap.

let nameDraft = "";

function drawCardProfile(now) {
  ctx.fillStyle = UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
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

  ctx.fillStyle = UI.track;
  ctx.font = "12px monospace";
  ctx.fillText(fns.backHint(), TP.cx, 414);

  statusEl.textContent = `Card · ${head} · bond ${bond}`;
}

function cardTap(x, y) {
  // renameHint's own line, per PetScreen.swift's card-tap dispatch for the
  // profile page.
  if (y >= 320 && y <= 344) {
    nameDraft = "";
    screen = "keyboard";
    return;
  }
  if (y > 400) screen = "idle";
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
