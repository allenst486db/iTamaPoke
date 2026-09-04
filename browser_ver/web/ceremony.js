// Evolution/farewell/runaway, ported from PetScreen.swift's
// drawEvolveButton/drawEndingButton/drawChoiceDialog/drawEvolveFX/
// drawCeremony -- halo rings, turning rays, sparks, rain, rising hearts,
// and the white-out reveal all included. The one real simplification:
// evolveFx flickers the current sprite against itself rather than the old
// species against the new one, since this build doesn't keep a second
// sprite around for the form being evolved from.

let choice = "none"; // none | evolve | farewell

// TP.evoBtn / TP.farBtn on iOS: both sit in the middle of the screen, not
// at the bottom. The browser build used to draw them at y 372, straight
// over the four action buttons -- so the evolve CTA covered FEED and there
// was no way to raise a stat back to 40 once it appeared.
// Written out rather than derived from TP.cx: this file is parsed before
// main.js, where TP is declared, so a top-level `TP.cx` here throws during
// script load and takes every function in this file with it -- which then
// breaks the idle tap handler at its first `choice` reference, i.e. every
// button on the screen. (Same trap as dex.js's cryBtnRect and icons.js's
// palette, both of which dodge it by computing on first use.)
// TP.cx is 233, so these are TP.evoBtn / TP.farBtn exactly.
const EVO_BTN = { x: 105, y: 172, w: 256, h: 64 };
const FAR_BTN = { x: 29, y: 176, w: 408, h: 58 };

function drawEvolveButton(now) {
  const p = Math.round(5 * Math.sin(now * 0.006));
  const x = EVO_BTN.x - p, y = EVO_BTN.y - p, w = EVO_BTN.w + p * 2, h = EVO_BTN.h + p * 2;
  ctx.fillStyle = UI.barBad;
  roundRect(x, y, w, h, 18); ctx.fill();
  ctx.strokeStyle = UI.white; ctx.lineWidth = 2;
  roundRect(x, y, w, h, 18); ctx.stroke();
  roundRect(x + 2, y + 2, w - 4, h - 4, 16); ctx.stroke();
  ctx.fillStyle = UI.white;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.font = "bold 20px monospace";
  ctx.fillText(fns.evolveButtonText(), TP.cx, y + h / 2);
  ctx.textBaseline = "alphabetic";
}

function drawEndingButton(now, text, fill, textColor, amplitude, rate) {
  const p = Math.round(amplitude * Math.sin(now * rate));
  const x = FAR_BTN.x - p, y = FAR_BTN.y - p, w = FAR_BTN.w + p * 2, h = FAR_BTN.h + p * 2;
  ctx.fillStyle = fill;
  roundRect(x, y, w, h, 16); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 1;
  roundRect(x, y, w, h, 16); ctx.stroke();
  ctx.fillStyle = textColor;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.font = "bold 15px monospace";
  ctx.fillText(text, TP.cx, y + h / 2);
  ctx.textBaseline = "alphabetic";
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
  // Each CTA is checked against its own rect (they differ in width), in the
  // same precedence render() uses.
  if (fns.wantsEvolve() !== 0) {
    if (inRect(x, y, EVO_BTN)) { choice = "evolve"; return true; }
    return false;
  }
  if (!inRect(x, y, FAR_BTN)) return false;
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

  // TP.choiceAction / TP.choiceKeep: 93,206 and 93,268, 280x52.
  const actFill = isEvolve ? UI.barBad : UI.barWarn;
  const keepFill = isEvolve ? UI.track : UI.barOK;
  ctx.fillStyle = actFill;
  roundRect(93, 206, 280, 52, 12); ctx.fill();
  ctx.fillStyle = keepFill;
  roundRect(93, 268, 280, 52, 12); ctx.fill();
  ctx.textBaseline = "middle";
  ctx.fillStyle = isEvolve ? UI.white : UI.ink;
  ctx.font = "bold 15px monospace";
  ctx.fillText(isEvolve ? fns.evolveButtonText() : fns.farewellGoText(), TP.cx, 206 + 26);
  ctx.fillStyle = isEvolve ? UI.ink : UI.white;
  ctx.fillText(isEvolve ? fns.evolveKeepText() : fns.farewellStayText(), TP.cx, 268 + 26);
  ctx.textBaseline = "alphabetic";

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
  if (x >= 93 && x <= 373 && y >= 206 && y <= 258) {
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
  if (x >= 93 && x <= 373 && y >= 268 && y <= 320) {
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
  // Scene behind the flash, as on iOS. The creature itself is a silhouette
  // here on purpose -- PetScreen.swift's drawEvolveFX draws both the old
  // and the new form with silhouette: true and reveals the result with
  // the white-out.
  const hour = sceneHour();
  drawScene(fns.dexBiome(fns.speciesId()), now, sceneIsNight(hour, false), hour);
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

// The creature itself during a ceremony: the real animated sprite in the
// given action (pose / walk / hurt), or a flat silhouette for the runaway's
// blink-out frames -- drawSpriteIdle(act:silhouette:) on iOS.
function drawCeremonySprite(x, groundY, act, silhouette, now) {
  if (!currentSprite) return;
  if (silhouette) { drawSilhouette(x, groundY, 3); return; }
  if (!spriteHas(currentSprite, act)) act = TPAct.idle;
  const a = currentSprite.actions[act];
  if (!a) return;
  const frame = frameIndexAt(a, now, true);
  const img = frameImageData(currentSprite, act, frame);
  if (!img) return;
  const s = spriteScale(currentSprite, a);
  const w = a.w * s, h = a.h * s;
  frameCanvas.width = a.w; frameCanvas.height = a.h;
  frameCtx.putImageData(img, 0, 0);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(frameCanvas, x - w / 2, groundY - (a.base > 0 ? a.base : a.h) * s, w, h);
}

// Port of drawCeremony(): a golden halo + rising hearts and a walk-off
// right for a farewell; rain + a flinch + fading walk-off left for a
// runaway.
function drawCeremonyFx(now) {
  const panic = fns.ceremony() === 2; // CER_RUNAWAY
  // The creature's own habitat behind the ending, as PetScreen.swift's
  // render() draws the scene before drawCeremony; a runaway happens under
  // a night sky.
  const hour = sceneHour();
  drawScene(fns.dexBiome(fns.speciesId()), now, panic || sceneIsNight(hour, false), hour);
  const t = fns.ceremonyProgress();
  const n = now;
  let x = TP.cx;
  let act = TPAct.idle;
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
      act = TPAct.hurt;
      x = TP.cx + 4 * Math.sin(n * 0.04);
    } else {
      act = TPAct.walkL;
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
        drawIcon(TPIcon.heart, px - 8, py - 8, 1);  // same glyph as PetScreen.swift's drawCeremony
      } else {
        ctx.fillStyle = i % 2 === 1 ? "#ffe79f" : "#ff9ac0";
        ctx.fillRect(px, py, 4, 4);
      }
    }
    if (t < 0.45) {
      act = TPAct.pose;
    } else {
      act = TPAct.walkR;
      x = TP.cx + ((t - 0.45) / 0.55) * (TP.cx + 140);
    }
  }

  // The real animated sprite -- bowing, then walking off (farewell), or
  // flinching, then a fading walk-off (runaway). Only the runaway's blink
  // frames are a silhouette, exactly as drawSpriteIdle(silhouette:) on iOS;
  // this used to draw a silhouette for the whole ceremony.
  drawCeremonySprite(x, 304, act, panic && hidden, now);
  if (!panic && fns.showHeart() !== 0) drawIcon(TPIcon.heart, x + 50, 304 - 190, 2);

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
