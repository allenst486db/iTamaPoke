// Evolution/farewell/runaway, ported from PetScreen.swift's
// drawEvolveButton/drawEndingButton/drawChoiceDialog/drawEvolveFX/
// drawCeremony. The underlying game state (evolving, the ending states)
// already runs correctly through the real C++ Pet -- this is a simplified
// presentation: a pulsing button and a plain "evolving..."/ceremony-message
// overlay instead of the original's halo/ray/spark particle animation,
// which needs a lot more of SceneRenderer.swift ported first to look right
// against. See browser_ver/README.md's roadmap.

let choice = "none"; // none | evolve | farewell

function drawEvolveButton(now) {
  const p = Math.round(5 * Math.sin(now * 0.006));
  const x = 233 - 130 - p, y = 372 - p, w = 260 + p * 2, h = 44 + p * 2;
  ctx.fillStyle = UI.barBad;
  roundRect(x, y, w, h, 18); ctx.fill();
  ctx.strokeStyle = UI.white; ctx.lineWidth = 2;
  roundRect(x, y, w, h, 18); ctx.stroke();
  ctx.fillStyle = UI.white;
  ctx.textAlign = "center";
  ctx.font = "bold 18px monospace";
  ctx.fillText(fns.evolveButtonText(), TP.cx, y + h / 2 + 6);
}

function drawEndingButton(now, text, fill, textColor, amplitude, rate) {
  const p = Math.round(amplitude * Math.sin(now * rate));
  const x = 233 - 130 - p, y = 372 - p, w = 260 + p * 2, h = 40 + p * 2;
  ctx.fillStyle = fill;
  roundRect(x, y, w, h, 16); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 1;
  roundRect(x, y, w, h, 16); ctx.stroke();
  ctx.fillStyle = textColor;
  ctx.textAlign = "center";
  ctx.font = "bold 14px monospace";
  ctx.fillText(text, TP.cx, y + h / 2 + 5);
}

// Called from the idle screen's own draw, after the buttons row -- mirrors
// PetScreen.swift's render() precedence: evolve first, then runaway, then
// the voluntary farewell.
function drawEvolveEndingOverlay(now) {
  if (fns.wantsEvolve() !== 0) {
    drawEvolveButton(now);
  } else if (fns.canRunaway() !== 0) {
    drawEndingButton(now, fns.runawayButtonText(), "#3a445a", "#c8d2e0", 3, 0.003);
  } else if (fns.wantsFarewell() !== 0) {
    drawEndingButton(now, fns.farewellButtonText(), UI.barWarn, UI.ink, 4, 0.005);
  }
}

function evolveEndingTap(x, y) {
  // Same 260x44-ish hit rect as the drawn button, generous enough not to
  // need the exact pulse offset.
  if (x < 103 || x > 363 || y < 358 || y > 428) return false;
  if (fns.wantsEvolve() !== 0) { choice = "evolve"; return true; }
  if (fns.canRunaway() !== 0) { Module._tp_start_runaway(); return true; }
  if (fns.wantsFarewell() !== 0) { choice = "farewell"; return true; }
  return false;
}

function drawChoiceDialog() {
  const isEvolve = choice === "evolve";
  ctx.fillStyle = UI.white;
  roundRect(73, 156, 320, 188, 16); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 2;
  roundRect(73, 156, 320, 188, 16); ctx.stroke();
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "center";
  ctx.font = "bold 15px monospace";
  ctx.fillText(isEvolve ? fns.evolveQuestion() : fns.farewellQuestion(), TP.cx, 182);

  const actFill = isEvolve ? UI.barBad : UI.barWarn;
  const keepFill = isEvolve ? "#dedede" : UI.barOK;
  ctx.fillStyle = actFill;
  roundRect(93, 226, 280, 44, 12); ctx.fill();
  ctx.fillStyle = keepFill;
  roundRect(93, 278, 280, 44, 12); ctx.fill();
  ctx.fillStyle = isEvolve ? UI.white : UI.ink;
  ctx.font = "bold 15px monospace";
  ctx.fillText(isEvolve ? fns.evolveButtonText() : fns.farewellGoText(), TP.cx, 254);
  ctx.fillStyle = isEvolve ? UI.ink : UI.white;
  ctx.fillText(isEvolve ? fns.evolveKeepText() : fns.farewellStayText(), TP.cx, 306);
}

function choiceDialogTap(x, y) {
  if (x >= 93 && x <= 373 && y >= 226 && y <= 270) {
    if (choice === "evolve") Module._tp_evolve();
    else Module._tp_start_farewell();
    choice = "none";
    return;
  }
  if (x >= 93 && x <= 373 && y >= 278 && y <= 322) {
    if (choice === "evolve") Module._tp_decline_evolve();
    else Module._tp_decline_farewell();
    choice = "none";
  }
}

// Drawn instead of the normal idle scene while a ceremony/evolution
// animation is in progress -- see this file's header comment on why this
// is a plain message screen rather than the original's particle FX.
function drawCeremonyOrEvolving(now) {
  const night = isNight();
  ctx.fillStyle = night ? UI.bgNight : UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  const ink = night ? UI.inkNight : UI.ink;
  ctx.textAlign = "center";

  if (fns.evolvingNow() !== 0) {
    const t = fns.evolveProgress();
    ctx.fillStyle = UI.white;
    ctx.font = "bold 28px monospace";
    ctx.fillText("✨ Evolving... ✨", TP.cx, 220);
    const bw = 280;
    ctx.strokeStyle = UI.white; ctx.lineWidth = 2;
    ctx.strokeRect(TP.cx - bw / 2, 240, bw, 10);
    ctx.fillStyle = UI.white;
    ctx.fillRect(TP.cx - bw / 2, 240, bw * Math.min(Math.max(t, 0), 1), 10);
    statusEl.textContent = `Evolving · ${Math.round(t * 100)}%`;
    return;
  }

  ctx.fillStyle = ink;
  ctx.font = "bold 22px monospace";
  ctx.fillText(fns.name(), TP.cx, 200);
  ctx.font = "18px monospace";
  ctx.fillText(fns.ceremonyMessage(), TP.cx, 240);
  statusEl.textContent = `Ceremony · ${fns.ceremonyMessage()}`;
}
