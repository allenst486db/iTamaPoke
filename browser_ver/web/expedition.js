// Stat card pages Daily/Box/Expedition, ported from PetScreen.swift's
// renderCardDaily/renderCardBox/renderCardExpedition + the idle screen's
// expedition HUD chip. All state lives in the real C++ Pet (via
// browser_card2.cpp); this is drawing + tap only.

function dailyGoalColor(kind) {
  return { 0: "#d4527e", 1: UI.barWarn, 2: UI.barBad, 3: UI.barOK, 4: "#4C98D9" }[kind] || UI.track;
}

function drawCardDaily() {
  Module._tp_ensure_daily_goals();
  ctx.textAlign = "center";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 20px monospace";
  ctx.fillText(fns.dailyTitle(), TP.cx, 50);
  ctx.fillStyle = UI.track;
  ctx.font = "11px monospace";
  ctx.fillText(fns.dayPhaseLabel(), TP.cx, 74);

  const count = fns.dailyGoalCount();
  let done = 0;
  for (let i = 0; i < count; i++) {
    const y = 96 + i * 66;
    const complete = fns.dailyGoalComplete(i) !== 0;
    if (complete) done++;
    const col = dailyGoalColor(fns.dailyGoalKind(i));
    ctx.fillStyle = complete ? col : UI.white;
    roundRect(58, y, 350, 48, 12); ctx.fill();
    ctx.strokeStyle = col; ctx.lineWidth = 1;
    roundRect(58, y, 350, 48, 12); ctx.stroke();
    ctx.textAlign = "left";
    ctx.fillStyle = complete ? UI.bgDay : UI.ink;
    ctx.font = "13px monospace";
    ctx.fillText(fns.dailyGoalLabel(i), 76, y + 28);
    ctx.textAlign = "right";
    if (complete) {
      ctx.fillText("✓ " + fns.doneText(), 390, y + 28);
    } else {
      ctx.fillText(`${fns.dailyGoalProgress(i)}/${fns.dailyGoalTarget(i)}`, 390, y + 28);
    }
  }

  ctx.textAlign = "center";
  ctx.fillStyle = done === count ? UI.barOK : UI.track;
  ctx.font = "13px monospace";
  ctx.fillText(fns.dailyRewardLine(), TP.cx, 310);

  statusEl.textContent = `Card · Daily · ${done}/${count}`;
}

let boxPage = 0;

function drawCardBox() {
  Module._tp_box_invalidate(); // cheap at this size; always fresh rather than stale after a catch
  const rows = 5;
  const pages = fns.boxPageCount(rows);
  if (boxPage >= pages) boxPage = Math.max(0, pages - 1);

  ctx.textAlign = "left";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 18px monospace";
  ctx.fillText(fns.boxTitle(), 40, 40);

  ctx.fillStyle = UI.white;
  roundRect(302, 30, 96, 26, 9); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 1;
  roundRect(302, 30, 96, 26, 9); ctx.stroke();
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "center";
  ctx.font = "11px monospace";
  ctx.fillText(fns.boxSortLabel(), 350, 47);

  ctx.textAlign = "left";
  ctx.font = "13px monospace";
  ctx.fillText(fns.caughtCountLine(), 40, 62);
  ctx.fillStyle = UI.track;
  ctx.font = "10px monospace";
  ctx.fillText(fns.knownCountLine(), 40, 78);
  ctx.fillText(fns.dexGoalLine(), 230, 78);

  if (fns.caughtCount() === 0) {
    ctx.fillStyle = UI.white;
    roundRect(82, 130, 302, 60, 16); ctx.fill();
    ctx.strokeStyle = UI.track; ctx.lineWidth = 1;
    roundRect(82, 130, 302, 60, 16); ctx.stroke();
    ctx.fillStyle = UI.track;
    ctx.textAlign = "center";
    ctx.font = "13px monospace";
    ctx.fillText(fns.noCatchesText(), TP.cx, 164);
    drawBoxPager(pages);
    statusEl.textContent = `Card · Box · empty`;
    return;
  }

  for (let i = 0; i < rows; i++) {
    const dex = fns.boxDexAt(boxPage * rows + i);
    if (dex <= 0) break;
    const y = 90 + i * 36;
    const raised = fns.dexRegistered(dex) !== 0;
    ctx.fillStyle = UI.white;
    roundRect(40, y, 350, 30, 9); ctx.fill();
    ctx.strokeStyle = TYPE_COLORS[fns.dexType1(dex)] || UI.ink;
    ctx.lineWidth = 1;
    roundRect(40, y, 350, 30, 9); ctx.stroke();
    ctx.fillStyle = UI.ink;
    ctx.textAlign = "left";
    ctx.font = "11px monospace";
    ctx.fillText(`#${String(dex).padStart(3, "0")} ${fns.dexName(dex)}`, 50, y + 19);
    const t1 = TYPE_NAMES[fns.dexType1(dex)] || "";
    const t2 = fns.dexType2(dex) ? "/" + TYPE_NAMES[fns.dexType2(dex)] : "";
    ctx.textAlign = "right";
    ctx.fillStyle = TYPE_COLORS[fns.dexType1(dex)] || UI.ink;
    ctx.font = "9px monospace";
    ctx.fillText(t1 + t2, 380, y + (raised ? 14 : 19));
    if (raised) { ctx.fillStyle = UI.barOK; ctx.fillText(fns.raisedMarkText(), 380, y + 26); }
  }

  drawBoxPager(pages);
  statusEl.textContent = `Card · Box · page ${boxPage + 1}/${pages}`;
}

function drawBoxPager(pages) {
  const prevOn = boxPage > 0, nextOn = boxPage + 1 < pages;
  const off = rgb565(0xE71C);   // PetScreen's disabled pager fill
  ctx.fillStyle = prevOn ? UI.track : off;
  roundRect(58, 296, 90, 32, 11); ctx.fill();
  ctx.fillStyle = nextOn ? UI.track : off;
  roundRect(288, 296, 90, 32, 11); ctx.fill();
  ctx.fillStyle = UI.bgDay;
  ctx.textAlign = "center";
  ctx.font = "bold 16px monospace";
  ctx.fillText("<", 103, 318);
  ctx.fillText(">", 333, 318);
  ctx.fillStyle = UI.track;
  ctx.font = "11px monospace";
  ctx.fillText(fns.pageLine(boxPage + 1, pages), TP.cx, 322);
}

function cardBoxTap(x, y) {
  if (x >= 302 && x <= 398 && y >= 30 && y <= 56) {
    Module._tp_cycle_box_sort();
    return;
  }
  if (y >= 296 && y <= 328) {
    const pages = fns.boxPageCount(5);
    if (x >= 58 && x <= 148 && boxPage > 0) boxPage--;
    else if (x >= 288 && x <= 378 && boxPage + 1 < pages) boxPage++;
  }
}

const EXP_TILE_X = [50, 180, 310];
const EXP_ITEM_POS = [[50, 204], [244, 204], [50, 268], [244, 268]];

let expeditionTrainChoiceOpen = false;

function drawCardExpedition() {
  ctx.textAlign = "center";
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 20px monospace";
  ctx.fillText(fns.expeditionTitle(), TP.cx, 48);

  if (fns.expeditionReady() !== 0) {
    ctx.fillStyle = UI.barOK;
    ctx.font = "13px monospace";
    ctx.fillText(fns.expeditionFoundLine(), TP.cx, 78);
    roundRect(98, 98, 270, 48, 11); ctx.fill();
    ctx.fillStyle = UI.bgDay;
    ctx.font = "bold 14px monospace";
    ctx.fillText(fns.expeditionClaimText(), TP.cx, 128);
  } else if (fns.expeditionActive() !== 0) {
    ctx.fillStyle = "#4C98D9";
    ctx.font = "bold 18px monospace";
    ctx.fillText(fns.expeditionBackInLine(), TP.cx, 92);
    ctx.fillStyle = UI.track;
    ctx.font = "11px monospace";
    ctx.fillText(fns.expeditionWaitText(), TP.cx, 116);
  } else {
    const cols = [UI.barOK, "#4C98D9", UI.barBad];
    for (let i = 0; i < 3; i++) {
      const avail = fns.expeditionCanStart(i) !== 0;
      ctx.fillStyle = avail ? cols[i] : UI.track;
      roundRect(EXP_TILE_X[i], 94, 106, 54, 9); ctx.fill();
      ctx.fillStyle = UI.bgDay;
      ctx.font = "bold 13px monospace";
      ctx.fillText(fns.expeditionDurationLabel(i), EXP_TILE_X[i] + 53, 116);
      ctx.font = "10px monospace";
      ctx.fillText(fns.expeditionCostLabel(i), EXP_TILE_X[i] + 53, 136);
    }
    if (fns.expeditionInventoryFull() !== 0) {
      ctx.fillStyle = UI.barBad;
      ctx.font = "10px monospace";
      ctx.fillText(fns.expeditionInventoryFullText(), TP.cx, 78);
    } else if (fns.energy() < 12) {
      ctx.fillStyle = UI.barBad;
      ctx.font = "10px monospace";
      ctx.fillText(fns.expeditionNeedEnergyText(), TP.cx, 78);
    }
  }

  ctx.fillStyle = UI.ink;
  ctx.font = "13px monospace";
  ctx.fillText(fns.inventoryTitle(), TP.cx, 172);
  for (let i = 0; i < 4; i++) drawExpeditionItem(EXP_ITEM_POS[i][0], EXP_ITEM_POS[i][1], i);

  if (expeditionTrainChoiceOpen) drawExpeditionTrainChoice();

  statusEl.textContent = `Card · Expedition`;
}

function drawExpeditionItem(x, y, index) {
  const count = fns.expeditionItemCount(index);
  const col = rgb565(fns.expeditionItemColor(index));
  // An empty slot is a faded card, not a black hole -- same light panel
  // the iOS build uses, with the outline and text greyed instead.
  ctx.fillStyle = count > 0 ? UI.white : rgb565(0xE4E7);   // PetScreen's empty-slot fill
  roundRect(x, y, 172, 54, 9); ctx.fill();
  ctx.strokeStyle = count > 0 ? col : UI.track; ctx.lineWidth = 1;
  roundRect(x, y, 172, 54, 9); ctx.stroke();
  ctx.beginPath();
  ctx.arc(x + 22, y + 27, 12, 0, Math.PI * 2);
  ctx.fillStyle = count > 0 ? col : UI.track;
  ctx.fill();
  ctx.textAlign = "left";
  ctx.fillStyle = count > 0 ? UI.ink : UI.track;
  ctx.font = "11px monospace";
  ctx.fillText(fns.expeditionItemLabel(index), x + 42, y + 24);
  ctx.textAlign = "right";
  ctx.font = "bold 13px monospace";
  ctx.fillText(`x${count}`, x + 160, y + 34);
}

function drawExpeditionTrainChoice() {
  ctx.fillStyle = UI.white;
  roundRect(58, 118, 350, 190, 14); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 2;
  roundRect(58, 118, 350, 190, 14); ctx.stroke();
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "center";
  ctx.font = "13px monospace";
  ctx.fillText(fns.trainChoiceTitle(), TP.cx, 140);

  const cols = [UI.barBad, "#4C98D9", UI.barWarn];
  for (let i = 0; i < 3; i++) {
    const x = 74 + i * 108;
    const usable = fns.trainStatUsable(i) !== 0;
    ctx.fillStyle = usable ? cols[i] : UI.track;
    roundRect(x, 172, 102, 66, 9); ctx.fill();
    ctx.fillStyle = UI.bgDay;
    ctx.font = "bold 13px monospace";
    ctx.fillText(fns.trainStatLabel(i), x + 51, 190);
    ctx.font = "11px monospace";
    ctx.fillText(usable ? "+2" : fns.trainMaxedText(), x + 51, 214);
  }
  ctx.fillStyle = UI.track;
  ctx.font = "12px monospace";
  ctx.fillText(fns.backHint(), TP.cx, 288);
}

function expeditionItemAt(x, y) {
  if (!((y >= 204 && y <= 258) || (y >= 268 && y <= 322))) return null;
  const left = x >= 50 && x <= 222, right = x >= 244 && x <= 416;
  if (!left && !right) return null;
  const row = y >= 268 ? 1 : 0;
  return row * 2 + (right ? 1 : 0);
}

function cardExpeditionTap(x, y) {
  if (expeditionTrainChoiceOpen) {
    if (y >= 172 && y <= 238 && x >= 74 && x <= 398) {
      const stat = Math.floor((x - 74) / 108);
      if (stat <= 2 && fns.trainStatUsable(stat) !== 0) Module._tp_use_train_item(stat);
      else playSfx(7); // deny
    }
    expeditionTrainChoiceOpen = false;
    return;
  }
  if (fns.expeditionReady() !== 0) {
    if (x >= 98 && x <= 368 && y >= 98 && y <= 146) {
      Module._tp_claim_expedition();
      playSfx(6); // medal
    }
    return;
  }
  if (fns.expeditionActive() === 0 && y >= 94 && y <= 148) {
    const idx = x >= 50 && x <= 156 ? 0 : x >= 180 && x <= 286 ? 1 : x >= 310 && x <= 416 ? 2 : -1;
    if (idx >= 0) {
      if (fns.expeditionCanStart(idx) !== 0) { Module._tp_start_expedition(idx); playSfx(0); }
      else playSfx(7);
    }
    return;
  }
  const item = expeditionItemAt(x, y);
  if (item === null) return;
  if (item === 3) {
    if (fns.expeditionItemCount(3) === 0) { playSfx(7); return; }
    expeditionTrainChoiceOpen = true;
    return;
  }
  if (fns.expeditionItemCount(item) === 0) { playSfx(7); return; }
  Module._tp_use_expedition_item(item);
  playSfx(0);
}

// --- Idle-screen expedition HUD chip ----------------------------------

function drawExpeditionHud() {
  const state = fns.expeditionHudState();
  if (state === 0) return;
  const color = state === 2 ? UI.barOK : state === 3 ? UI.barWarn : "#4C98D9";
  ctx.fillStyle = UI.white;
  roundRect(330, 16, 120, 34, 8); ctx.fill();
  ctx.strokeStyle = color; ctx.lineWidth = 2;
  roundRect(330, 16, 120, 34, 8); ctx.stroke();
  ctx.beginPath();
  ctx.arc(347, 33, 9, 0, Math.PI * 2);
  ctx.fillStyle = color; ctx.fill();
  ctx.fillStyle = UI.white;
  ctx.font = "bold 11px monospace";
  ctx.textAlign = "center";
  ctx.fillText(state === 2 ? "!" : state === 3 ? "+" : ">", 347, 37);
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "left";
  ctx.font = "10px monospace";
  ctx.fillText(fns.expeditionHudLabel(), 362, 37);
}
