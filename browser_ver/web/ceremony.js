// Evolution/farewell/runaway, ported from PetScreen.swift's
// drawEvolveButton/drawEndingButton/drawChoiceDialog/drawEvolveFX/
// drawCeremony -- halo rings, turning rays, sparks, rain, rising hearts,
// and the white-out reveal all included. The one real simplification:
// evolveFx flickers the current sprite against itself rather than the old
// species against the new one, since this build doesn't keep a second
// sprite around for the form being evolved from.

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

  // The evolve CTA can appear as soon as the level requirement is met
  // (see tp_wants_evolve), before all 4 care stats are actually at 40+ --
  // tapping "Evolve" while that's still true used to just silently do
  // nothing and close the dialog, no indication why. Surface the same
  // ready/blocked line the Progress page shows, in the gap between the
  // Keep button (ends y 322) and the dialog's own bottom edge (y 344),
  // matching PetScreen.swift's drawChoiceDialog fix.
  if (isEvolve && fns.evolutionStatusKind() === 2) {
    ctx.fillStyle = UI.barWarn;
    ctx.font = "12px monospace";
    ctx.fillText(fns.evolutionStatus(), TP.cx, 332);
  }
}

function choiceDialogTap(x, y) {
  if (x >= 93 && x <= 373 && y >= 226 && y <= 270) {
    if (choice === "evolve") {
      // tp_evolve() itself already no-ops when a stat has dropped back
      // under 40 (or the pet fell asleep) since the button first appeared
      // -- give an explicit "denied" cue in that case rather than letting
      // the dialog just vanish with nothing happening.
      if (fns.canEvolveNow() !== 0) Module._tp_evolve();
      else playSfx(7); // deny
    } else {
      Module._tp_start_farewell();
    }
    choice = "none";
    return;
  }
  if (x >= 93 && x <= 373 && y >= 278 && y <= 322) {
    if (choice === "evolve") Module._tp_decline_evolve();
    else Module._tp_decline_farewell();
    choice = "none";
  }
}

// Draws the current sprite's idle frame as a flat black silhouette at
// (x, groundY), matching drawSpriteIdle(silhouette: true)'s look -- source-
// atop composites solid ink only where the frame already has pixels, so
// the shape stays exact without re-deriving it from alpha manually.
function drawSilhouette(x, groundY, scale) {
  if (!currentSprite) return;
  const a = currentSprite.actions[TPAct.idle];
  if (!a) return;
  const img = frameImageData(currentSprite, TPAct.idle, 0);
  if (!img) return;
  const w = a.w * scale, h = a.h * scale;
  frameCanvas.width = a.w; frameCanvas.height = a.h;
  frameCtx.putImageData(img, 0, 0);
  frameCtx.globalCompositeOperation = "source-atop";
  frameCtx.fillStyle = "#1a1a1a";
  frameCtx.fillRect(0, 0, a.w, a.h);
  frameCtx.globalCompositeOperation = "source-over";
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(frameCanvas, x - w / 2, groundY - h, w, h);
}

// Port of drawEvolveFX(): a pulsing halo, turning rays, a flickering
// silhouette, sparks, and a white-out reveal at the end. Flickers the
// current sprite against itself rather than old-vs-new (the browser build
// doesn't keep the pre-evolution species' sprite around separately), which
// is the one real simplification versus PetScreen.swift's version.
function drawEvolveFx(now) {
  ctx.fillStyle = UI.bgNight;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  const t = fns.evolveProgress();
  const cx = TP.cx, cy = 304 - 96, n = now;

  const halo = 36 + t * 150 + 8 * Math.sin(n * 0.02);
  ctx.strokeStyle = UI.white;
  ctx.lineWidth = 2;
  for (let k = 0; k < 4; k++) {
    const r = halo - k * 7;
    if (r > 0) { ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke(); }
  }

  const base = n * 0.004;
  for (let i = 0; i < 12; i++) {
    const a = base + i * (Math.PI / 6);
    const len = 90 + 70 * (0.5 + 0.5 * Math.sin(n * 0.012 + i));
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx + Math.cos(a) * len, cy + Math.sin(a) * len);
    ctx.stroke();
  }

  const period = Math.max(60 + 220 * (1 - t), 1);
  if (t < 0.9 || (now / period) % 2 < 1) drawSilhouette(cx, 304, 3);

  for (let i = 0; i < 10; i++) {
    const a = i * (Math.PI / 5) + t * 4.0;
    const d = (now / 14 + i * 33) % 200;
    const sx = cx + Math.cos(a) * d, sy = cy + Math.sin(a) * d;
    ctx.fillStyle = i & 1 ? "#ffe070" : UI.white;
    ctx.fillRect(sx - 2, sy - 2, 5, 5);
  }

  if (t > 0.9) {
    ctx.fillStyle = UI.white;
    ctx.beginPath();
    ctx.arc(cx, cy, Math.max(300 * (t - 0.9) / 0.1, 0), 0, Math.PI * 2);
    ctx.fill();
  }

  statusEl.textContent = `Evolving · ${Math.round(t * 100)}%`;
}

// Port of drawCeremony(): a golden halo + rising hearts and a walk-off
// right for a farewell; rain + a flinch + fading walk-off left for a
// runaway.
function drawCeremonyFx(now) {
  const panic = fns.ceremony() === 2; // CER_RUNAWAY
  ctx.fillStyle = panic ? UI.bgNight : UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  const t = fns.ceremonyProgress();
  const n = now;
  let x = TP.cx;
  let hidden = false;

  if (panic) {
    ctx.strokeStyle = "#6a84b0";
    ctx.lineWidth = 1;
    for (let i = 0; i < 46; i++) {
      const rx = (i * 47 + now / 3) % TP.screen;
      const ry = (i * 91 + now / 2) % 470;
      ctx.beginPath(); ctx.moveTo(rx, ry); ctx.lineTo(rx - 3, ry + 12); ctx.stroke();
    }
    if (t < 0.30) {
      x = TP.cx + 4 * Math.sin(n * 0.04);
    } else {
      x = TP.cx - ((t - 0.30) / 0.70) * (TP.cx + 120);
      hidden = t > 0.6 && (now / 160) % 2 < 1;
    }
  } else {
    const gcy = 304 - 96;
    ctx.strokeStyle = "#ffdf8a";
    ctx.lineWidth = 2;
    for (let k = 0; k < 4; k++) {
      const r = 60 + k * 34 + 10 * Math.sin(n * 0.02);
      ctx.beginPath(); ctx.arc(TP.cx, gcy, r, 0, Math.PI * 2); ctx.stroke();
    }
    for (let i = 0; i < 16; i++) {
      const px = (i * 71 + 28) % TP.screen;
      const py = 410 - ((now / 8 + i * 70) % 360);
      if (py < 30) continue;
      if (i % 4 === 0) {
        ctx.font = "16px monospace"; ctx.textAlign = "center";
        ctx.fillStyle = "#ff6b9a";
        ctx.fillText("♥", px, py);
      } else {
        ctx.fillStyle = i % 2 === 1 ? "#ffe79f" : "#ff9ac0";
        ctx.fillRect(px, py, 4, 4);
      }
    }
    if (t >= 0.45) x = TP.cx + ((t - 0.45) / 0.55) * (TP.cx + 140);
  }

  // Blinks off near the end of a panicked walk-off, same as
  // PetScreen.swift's own `fade` -- everything on this screen already
  // draws as a silhouette (see drawSilhouette's own comment), so this is
  // just "draw it this frame or don't."
  if (!hidden) drawSilhouette(x, 304, 3);

  if (panic && t < 0.55) {
    ctx.fillStyle = "#9ac4e8";
    ctx.fillRect(x + 6, 304 - 150 + ((now / 6) % 40), 3, 6);
  }

  ctx.textAlign = "center";
  ctx.fillStyle = panic ? UI.inkNight : UI.ink;
  ctx.font = "bold 20px monospace";
  ctx.fillText(fns.name(), TP.cx, 60);
  ctx.font = "16px monospace";
  ctx.fillText(fns.ceremonyMessage(), TP.cx, 90);

  statusEl.textContent = `Ceremony · ${fns.ceremonyMessage()}`;
}

// Drawn instead of the normal idle scene while a ceremony/evolution
// animation is in progress. Deliberately simplified from
// PetScreen.swift's drawEvolveFX/drawCeremony in one way: it flickers the
// current sprite against itself during evolution rather than the old form
// against the new one, since this build doesn't keep a second sprite
// around for the species being evolved from.
function drawCeremonyOrEvolving(now) {
  if (fns.evolvingNow() !== 0) { drawEvolveFx(now); return; }
  drawCeremonyFx(now);
}
