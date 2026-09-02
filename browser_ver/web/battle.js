// Wild battle screen, ported from PetScreen.swift's renderBattle/battleTap
// (itself a screen design over ShadowEnemyx/TamaPoke ("Expanded")'s
// battle.h combat math -- see upstream-expanded/README.md). All game state
// lives in browser_battle.cpp/battle.cpp; this file only draws it and
// forwards taps, same split as the rest of this port.

function drawBattleHpBar(x, y, cur, max, color) {
  const w = 150, m = max === 0 ? 1 : max;
  const fw = Math.min(w * cur / m, w);
  ctx.fillStyle = UI.track;
  roundRect(x, y, w, 14, 4);
  ctx.fill();
  if (fw > 2) { ctx.fillStyle = color; roundRect(x, y, fw, 14, 4); ctx.fill(); }
}

// Reuses the idle sprite loader/frame-walker already loaded for the raised
// species. The wild side used to always fall back to the "?" placeholder
// unless the opponent happened to be the same species you're raising --
// `currentSprite` only ever holds the *active* pet. Now it also consults
// what sprites.js has already parsed, and kicks off a load for anything it
// hasn't seen yet, so the opponent shows its real sprite from the second
// frame onwards (the first draw after a species is first requested still
// shows "?" for the moment the IndexedDB read takes). `undefined` means
// never requested; `null` means requested and no local file exists, which
// stays on "?" without re-requesting every frame.
function battleSprite(dex) {
  return dex === currentDex ? currentSprite : spriteFor(dex, false);
}

function drawBattleSprite(dex, x, now) {
  const sprite = battleSprite(dex);
  if (!sprite) {
    ctx.font = "bold 40px monospace";
    ctx.fillStyle = "#98a0b0";
    ctx.textAlign = "center";
    ctx.fillText("?", x, 260);
    return;
  }
  const a = sprite.actions[TPAct.idle];
  if (!a) return;
  const frame = frameIndexAt(a, now, true);
  const img = frameImageData(sprite, TPAct.idle, frame);
  if (!img) return;
  const s = Math.min(spriteScale(sprite, a), 3);
  const w = a.w * s, h = a.h * s;
  frameCanvas.width = a.w; frameCanvas.height = a.h;
  frameCtx.putImageData(img, 0, 0);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(frameCanvas, x - w / 2, 286 - (a.base > 0 ? a.base : a.h) * s, w, h);
}

function drawBattle(now) {
  const night = isNight();
  ctx.fillStyle = night ? UI.bgNight : UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  const ink = night ? UI.inkNight : UI.ink;

  ctx.fillStyle = ink;
  ctx.textAlign = "center";
  ctx.font = "bold 20px monospace";
  ctx.fillText(fns.battleTitle(), TP.cx, 40);

  ctx.textAlign = "left";
  ctx.font = "bold 15px monospace";
  ctx.fillText(fns.battlePlayerLabel(), 28, 88);
  const rightLabel = fns.battleEnemyLabel();
  ctx.textAlign = "right";
  ctx.fillText(rightLabel, 438, 88);

  drawBattleHpBar(28, 110, fns.battlePlayerHp(), fns.battlePlayerMaxHp(), UI.barOK);
  drawBattleHpBar(288, 110, fns.battleEnemyHp(), fns.battleEnemyMaxHp(), UI.barBad);

  const dex = fns.speciesId(), wildDex = fns.battleWildDex();
  ctx.textAlign = "left";
  ctx.font = "10px monospace";
  const t1 = TYPE_NAMES[fns.dexType1(dex)] || "";
  const t2 = fns.dexType2(dex) ? "/" + TYPE_NAMES[fns.dexType2(dex)] : "";
  ctx.fillStyle = TYPE_COLORS[fns.dexType1(dex)] || ink;
  ctx.fillText(t1 + t2, 28, 134);
  const et1 = TYPE_NAMES[fns.dexType1(wildDex)] || "";
  const et2 = fns.dexType2(wildDex) ? "/" + TYPE_NAMES[fns.dexType2(wildDex)] : "";
  ctx.textAlign = "right";
  ctx.fillStyle = TYPE_COLORS[fns.dexType1(wildDex)] || ink;
  ctx.fillText(et1 + et2, 438, 134);

  const resolved = fns.battleResolved() !== 0;
  if (!resolved) {
    ctx.fillStyle = UI.track;
    roundRect(188, 102, 90, 32, 9);
    ctx.fill();
    ctx.fillStyle = UI.bgDay;
    ctx.textAlign = "center";
    ctx.font = "bold 13px monospace";
    ctx.fillText(fns.battleRunText(), 233, 122);
  }

  drawBattleSprite(dex, 142, now);
  drawBattleSprite(wildDex, 328, now);

  if (resolved) {
    const won = fns.battlePlayerWon() !== 0;
    ctx.fillStyle = won ? UI.barOK : UI.barBad;
    ctx.textAlign = "center";
    ctx.font = "bold 32px monospace";
    ctx.fillText(fns.battleResultText(), TP.cx, 312);
    ctx.fillStyle = ink;
    ctx.font = "13px monospace";
    ctx.fillText(fns.battleRoundsLine(), TP.cx, 338);
    ctx.fillText(fns.battleDamageLine(), TP.cx, 360);

    if (won) {
      const reward = fns.battleRewardLine();
      if (reward) { ctx.fillStyle = UI.barWarn; ctx.fillText(reward, TP.cx, 382); }
    } else {
      const cc = fns.battleCloseChanceText();
      if (cc) { ctx.fillStyle = UI.barWarn; ctx.fillText(cc, TP.cx, 382); }
    }

    const catchOffered = fns.battleCatchOffered() !== 0, catchDone = fns.battleCatchDone() !== 0;
    if (catchOffered && !catchDone) {
      ctx.fillStyle = UI.barOK;
      roundRect(76, 396, 148, 52, 14); ctx.fill();
      ctx.fillStyle = UI.track;
      roundRect(242, 396, 148, 52, 14); ctx.fill();
      ctx.fillStyle = UI.bgDay;
      ctx.font = "bold 13px monospace";
      ctx.fillText(fns.battleCatchWildText(), 150, 426);
      ctx.fillText(fns.battleLeaveWildText(), 316, 426);
    } else {
      if (catchDone && fns.battleCatchTried() !== 0) {
        const success = fns.battleCatchSuccess() !== 0;
        ctx.fillStyle = success ? UI.barOK : UI.barBad;
        ctx.font = "13px monospace";
        ctx.fillText(success ? fns.battleCaughtOkText() : fns.battleEscapedText(), TP.cx, 382);
      }
      ctx.fillStyle = UI.barOK;
      roundRect(118, 396, 230, 52, 14); ctx.fill();
      ctx.fillStyle = UI.bgDay;
      ctx.font = "bold 16px monospace";
      ctx.fillText(fns.battleOkText(), TP.cx, 428);
    }
  } else {
    ctx.textAlign = "left";
    ctx.fillStyle = ink;
    ctx.font = "13px monospace";
    ctx.fillText(fns.battleRoundLabel(), 32, 322);
    const msg = fns.battleMessage();
    if (msg) {
      ctx.textAlign = "center";
      ctx.fillText(msg, TP.cx, 322);
      const dmg = fns.battleLastEnemyDamage();
      if (dmg > 0) {
        ctx.fillStyle = UI.barBad;
        ctx.fillText("-" + dmg, TP.cx, 344);
      }
    }

    if (fns.battleAttackMenuOpen() !== 0) {
      ctx.fillStyle = UI.barBad;
      roundRect(74, 298, 150, 46, 12); ctx.fill();
      ctx.fillStyle = UI.barWarn;
      roundRect(242, 298, 150, 46, 12); ctx.fill();
      ctx.fillStyle = UI.bgDay;
      ctx.font = "bold 13px monospace";
      ctx.textAlign = "center";
      ctx.fillText(fns.battleQuickAttackText(), 149, 325);
      ctx.fillText(fns.battleHeavyAttackText(), 317, 325);
    }

    ctx.fillStyle = UI.barBad;
    roundRect(58, 358, 108, 58, 13); ctx.fill();
    ctx.fillStyle = "#4C98D9";
    roundRect(179, 358, 108, 58, 13); ctx.fill();
    ctx.fillStyle = UI.barOK;
    roundRect(300, 358, 108, 58, 13); ctx.fill();
    ctx.fillStyle = UI.bgDay;
    ctx.font = "bold 13px monospace";
    ctx.textAlign = "center";
    ctx.fillText(fns.battleAttackText(), 112, 391);
    ctx.fillText(fns.battleDodgeText(), 233, 391);
    ctx.fillText(fns.battleRestText(), 354, 391);
  }

  statusEl.textContent = resolved
    ? `Battle · ${fns.battlePlayerWon() ? "won" : "lost"}`
    : `Battle · round ${fns.battleRound() + 1} · HP ${fns.battlePlayerHp()}/${fns.battlePlayerMaxHp()}`;
}

function battleTap(x, y) {
  const resolved = fns.battleResolved() !== 0;
  if (resolved) {
    const catchOffered = fns.battleCatchOffered() !== 0, catchDone = fns.battleCatchDone() !== 0;
    if (catchOffered && !catchDone) {
      if (x >= 76 && x <= 224 && y >= 392 && y <= 448) { Module._tp_battle_try_catch(); return; }
      if (x >= 242 && x <= 390 && y >= 392 && y <= 448) { Module._tp_battle_leave_wild(); return; }
      return;
    }
    if (x >= 118 && x <= 348 && y >= 392 && y <= 454) {
      Module._tp_battle_close();
      screen = "idle";
    }
    return;
  }
  if (fns.battleAttackMenuOpen() !== 0) {
    if (x >= 66 && x <= 232 && y >= 292 && y <= 352) { Module._tp_battle_quick_attack(); return; }
    if (x >= 234 && x <= 400 && y >= 292 && y <= 352) { Module._tp_battle_heavy_attack(); return; }
    Module._tp_battle_close_attack_menu();
    return;
  }
  if (x >= 184 && x <= 282 && y >= 100 && y <= 136) {
    Module._tp_battle_close();
    screen = "idle";
    return;
  }
  if (x >= 46 && x <= 174 && y >= 344 && y <= 428) {
    Module._tp_battle_open_attack_menu();
  } else if (x >= 169 && x <= 297 && y >= 344 && y <= 428) {
    Module._tp_battle_dodge();
  } else if (x >= 292 && x <= 420 && y >= 344 && y <= 428) {
    Module._tp_battle_rest();
  }
}

// Idle-screen wild-encounter prompt: a small "fight or later" card, shown
// only while the idle screen itself is the front-most thing (mirrors
// PetScreen.swift's mainScreenReadyForWild gate).
function drawWildPrompt() {
  ctx.fillStyle = UI.white;
  roundRect(82, 156, 302, 178, 18); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 2;
  roundRect(82, 156, 302, 178, 18); ctx.stroke();
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "center";
  ctx.font = "bold 18px monospace";
  ctx.fillText(fns.battleWildQuestionText(), TP.cx, 182);
  ctx.font = "13px monospace";
  ctx.fillText(fns.battleWildPromptLine(), TP.cx, 212);

  ctx.fillStyle = UI.barBad;
  roundRect(93, 226, 280, 44, 12); ctx.fill();
  ctx.fillStyle = UI.track;
  roundRect(93, 278, 280, 44, 12); ctx.fill();
  ctx.fillStyle = UI.white;
  ctx.font = "bold 15px monospace";
  ctx.fillText(fns.battleFightText(), TP.cx, 254);
  ctx.fillStyle = UI.bgDay;
  ctx.fillText(fns.battleLaterText(), TP.cx, 306);
}

function wildPromptTap(x, y) {
  if (x >= 93 && x <= 373 && y >= 226 && y <= 270) {
    Module._tp_wild_accept();
    screen = "battle"; // its own screen id, distinct from the minigames' "game"
    return;
  }
  if (x >= 93 && x <= 373 && y >= 278 && y <= 322) {
    Module._tp_wild_dismiss();
  }
}
