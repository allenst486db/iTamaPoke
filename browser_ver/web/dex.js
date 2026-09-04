// Pokedex grid + detail, ported from PetScreen.swift's renderGalleryGrid/
// renderGalleryDetail. TPThumbs' own sprite-atlas thumbnails aren't ported
// (that's a separate packed-atlas format this build doesn't parse); grid
// tiles instead reuse whatever full TPK2 sprite the user already picked
// locally for that species (see dexThumbFor below), falling back to the
// dex number for anything not picked yet.

// Was a second cache+in-flight-guard of its own; that's sprites.js's
// spriteFor() now, shared with the wild-battle opponent so there's one
// copy of the "sync peek, lazy load, don't refire" rule rather than two
// that can drift.
function dexThumbFor(dex) {
  return spriteFor(dex, false);
}

// Static idle-pose frame at a fixed box size -- grid thumbnails don't
// animate (16 of them redrawn every frame is enough cost already).
function drawDexThumb(sprite, x, y, box) {
  const a = sprite.actions[TPAct.idle];
  if (!a) return;
  const img = frameImageData(sprite, TPAct.idle, 0);
  if (!img) return;
  const s = Math.min(box / a.w, box / a.h);
  const w = a.w * s, h = a.h * s;
  frameCanvas.width = a.w; frameCanvas.height = a.h;
  frameCtx.putImageData(img, 0, 0);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(frameCanvas, x + (box - w) / 2, y + (box - h) / 2, w, h);
}

// The detail view's portrait plays the idle cycle, as the iOS detail
// view's sprite does; only the grid tiles stay static.
function drawDexPortrait(sprite, x, y, box, now) {
  const a = sprite.actions[TPAct.idle];
  if (!a) return;
  const frame = frameIndexAt(a, now, true);
  const img = frameImageData(sprite, TPAct.idle, frame);
  if (!img) return;
  const s = Math.min(box / a.w, box / a.h);
  const w = a.w * s, h = a.h * s;
  frameCanvas.width = a.w; frameCanvas.height = a.h;
  frameCtx.putImageData(img, 0, 0);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(frameCanvas, x + (box - w) / 2, y + (box - h) / 2, w, h);
}

const TYPE_COLORS = {
  1: "#a8a878", 2: "#f08030", 3: "#6890f0", 4: "#f8d030", 5: "#78c850",
  6: "#98d8d8", 7: "#c03028", 8: "#a040a0", 9: "#e0c068", 10: "#a890f0",
  11: "#f85888", 12: "#a8b820", 13: "#b8a038", 14: "#705898", 15: "#7038f8",
  16: "#705848", 17: "#b8b8d0", 18: "#ee99ac",
};

let dexScreen = "grid"; // grid | detail
let dexFilter = 0;      // 0 all, 1 raised, 2 caught
let dexPage = 0;
let dexDetailDex = 0;
let dexDetailPage = 0;  // 0 portrait, 1 dex entry text

function dexVisible(dex) {
  if (dexFilter === 1) return fns.dexRegistered(dex) !== 0;
  if (dexFilter === 2) return fns.dexCaught(dex) !== 0;
  return true;
}

function dexFilteredCount() {
  if (dexFilter === 0) return fns.dexCount();
  let n = 0;
  for (let d = 1; d <= fns.dexCount(); d++) if (dexVisible(d)) n++;
  return n;
}

function dexAt(index) {
  let i = index;
  const count = fns.dexCount();
  for (let d = 1; d <= count; d++) {
    if (!dexVisible(d)) continue;
    if (i === 0) return d;
    i--;
  }
  return 0;
}

function dexPageCount() {
  return Math.max(1, Math.ceil(dexFilteredCount() / 16));
}

// Labels from the string table (S_FILTER_ALL / S_RAISED_MARK / S_CAUGHT_MARK),
// same as PetScreen's filter row, so they follow the UI language.
const DEX_FILTER_PILLS = [
  { x: 74, w: 96, label: () => fns.filterAllText() },
  { x: 180, w: 96, label: () => fns.raisedMarkText() },
  { x: 286, w: 96, label: () => fns.caughtMarkText() },
];
const GAL_X = 71, GAL_Y = 96, GAL_CELL = 82;

function drawDexGrid() {
  ctx.fillStyle = UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  ctx.fillStyle = UI.ink;
  ctx.textAlign = "center";
  ctx.font = "bold 24px monospace";
  // Korean UIs title the gallery 도감, everything else keeps POKEDEX -- the
  // same one-off PetScreen.swift makes (no StrId exists for it upstream).
  const lang = fns.language();
  ctx.fillText(lang === 6 || lang === 7 ? "도감" : "POKEDEX", TP.cx, 30);
  ctx.font = "15px monospace";
  ctx.fillText(`${fns.raisedCaughtLine()}  /${fns.dexCount()}`, TP.cx, 54);

  for (let i = 0; i < 3; i++) {
    const p = DEX_FILTER_PILLS[i];
    const selected = i === dexFilter;
    ctx.fillStyle = selected ? UI.ink : UI.white;
    roundRect(p.x, 68, p.w, 22, 7);
    ctx.fill();
    ctx.strokeStyle = UI.ink;
    ctx.lineWidth = 1;
    roundRect(p.x, 68, p.w, 22, 7);
    ctx.stroke();
    ctx.fillStyle = selected ? UI.bgDay : UI.ink;
    ctx.font = "bold 13px monospace";
    ctx.fillText(p.label(), p.x + p.w / 2, 84);
  }

  if (dexPage >= dexPageCount()) dexPage = 0;
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 4; c++) {
      const dex = dexAt(dexPage * 16 + r * 4 + c);
      if (dex <= 0) continue;
      const x = GAL_X + c * GAL_CELL, y = GAL_Y + r * GAL_CELL;
      const registered = fns.dexRegistered(dex) !== 0;
      const caught = fns.dexCaught(dex) !== 0;
      const known = registered || caught;

      ctx.fillStyle = known ? (registered ? "#bfe8c8" : "#f5dca0") : "#dfe3ea";
      roundRect(x, y, 64, 64, 10);
      ctx.fill();
      ctx.strokeStyle = UI.ink;
      ctx.lineWidth = 1;
      roundRect(x, y, 64, 64, 10);
      ctx.stroke();

      // A thumbnail if this species' sprite has already been picked locally
      // (see sprites.js's spriteCache -- reused rather than re-parsed), the
      // dex number otherwise. Ports TPThumbs' silhouette-vs-real-art split
      // loosely: known-but-not-picked still falls back to the number rather
      // than a silhouette, since this port has no separate thumbnail atlas.
      // thumbs.bin first (real art if known, ink silhouette if not --
      // upstream's rule); without the atlas, the full sprite for a known
      // species; otherwise the number / "?".
      let drawn = thumbsLoaded() && drawThumb(dex, x + 6, y + 6, 52, !known);
      if (!drawn && known) {
        const thumb = dexThumbFor(dex);
        if (thumb) { drawDexThumb(thumb, x + 6, y + 6, 52); drawn = true; }
      }
      if (!drawn) {
        ctx.fillStyle = known ? UI.ink : "#9099a8";
        ctx.font = "bold 18px monospace";
        ctx.fillText(known ? `#${dex}` : "?", x + 32, y + 37);
      }
      if (fns.dexShiny(dex) !== 0) {
        ctx.fillStyle = UI.barWarn;
        ctx.font = "bold 15px monospace";
        ctx.fillText("*", x + 56, y + 13);
      } else if (caught && !registered) {
        ctx.fillStyle = UI.barWarn;
        ctx.font = "bold 12px monospace";
        ctx.fillText("C", x + 54, y + 13);
      }
    }
  }

  const pages = dexPageCount();
  const dotsX = TP.cx - (pages - 1) * 7;
  for (let i = 0; i < pages; i++) {
    const cx = dotsX + i * 14;
    ctx.beginPath();
    ctx.arc(cx, 436, i === dexPage ? 4 : 3, 0, Math.PI * 2);
    if (i === dexPage) { ctx.fillStyle = UI.ink; ctx.fill(); }
    else { ctx.strokeStyle = UI.ink; ctx.lineWidth = 1; ctx.stroke(); }
  }
  ctx.fillStyle = UI.track;
  ctx.font = "15px monospace";
  ctx.fillText("< prev · next >  ·  tap a tile", TP.cx, 456);

  statusEl.textContent = `Dex · page ${dexPage + 1}/${pages} · filter ${DEX_FILTER_PILLS[dexFilter].label()}`;
}

function drawDexDetail() {
  const dex = dexDetailDex;
  const registered = fns.dexRegistered(dex) !== 0;
  const caught = fns.dexCaught(dex) !== 0;
  const known = registered || caught;
  const shiny = fns.dexShiny(dex) !== 0;

  ctx.fillStyle = UI.bgDay;
  ctx.fillRect(0, 0, TP.screen, TP.screen);
  ctx.fillStyle = "rgb(216,31,38)";
  ctx.fillRect(0, 0, TP.screen, 64);
  ctx.fillStyle = UI.white;
  ctx.textAlign = "center";
  ctx.font = "bold 22px monospace";
  ctx.fillText("POKeDEX", TP.cx, 40);

  ctx.fillStyle = UI.track;
  ctx.font = "15px monospace";
  ctx.fillText(`#${String(dex).padStart(3, "0")}`, TP.cx, 90);
  const name = (known ? fns.dexName(dex) : "???") + (known && shiny ? " *" : "");
  ctx.fillStyle = UI.ink;
  ctx.font = "bold 28px monospace";
  ctx.fillText(name, TP.cx, 124);

  if (dexDetailPage === 0) {
    if (known) {
      const t1 = fns.dexType1(dex), t2 = fns.dexType2(dex);
      const types = t2 ? [t1, t2] : [t1];
      let totalW = 0;
      const labels = types.map((t) => TYPE_NAMES[t] || "?");
      ctx.font = "bold 14px monospace";
      const widths = labels.map((l) => ctx.measureText(l).width + 24);
      totalW = widths.reduce((a, b) => a + b, 0) + (types.length - 1) * 8;
      let cx = TP.cx - totalW / 2;
      for (let i = 0; i < types.length; i++) {
        ctx.fillStyle = TYPE_COLORS[types[i]] || "#888";
        roundRect(cx, 155, widths[i], 24, 12);
        ctx.fill();
        ctx.strokeStyle = UI.ink;
        ctx.lineWidth = 1;
        roundRect(cx, 155, widths[i], 24, 12);
        ctx.stroke();
        ctx.fillStyle = UI.white;
        ctx.fillText(labels[i], cx + widths[i] / 2, 171);
        cx += widths[i] + 8;
      }
    }

    // Portrait: the species' own sprite once it's been picked locally. This
    // used to be a 🐾 emoji for every known species regardless -- the grid
    // tiles right next door were already drawing real art via dexThumbFor,
    // so the detail view was the odd one out. Falls back to the same "?"
    // the grid uses when there's no local file for this species.
    const portrait = known ? dexThumbFor(dex) : null;
    if (portrait) {
      drawDexPortrait(portrait, TP.cx - 60, 200, 120, performance.now());
    } else if (thumbsLoaded() && drawThumb(dex, TP.cx - 60, 200, 120, !known)) {
      // atlas still (silhouette for an unseen species), as on iOS
    } else {
      ctx.font = "bold 56px monospace";
      ctx.fillStyle = known ? UI.ink : "#c8ccd4";
      ctx.fillText("?", TP.cx, 280);
    }

    ctx.font = "bold 17px monospace";
    if (registered) {
      ctx.fillStyle = UI.barOK;
      ctx.fillText(fns.raisedMarkText(), TP.cx, caught ? 384 : 396);
    }
    if (caught) {
      ctx.fillStyle = UI.barWarn;
      ctx.fillText(fns.caughtMarkText(), TP.cx, registered ? 406 : 396);
    }
  } else {
    drawDexEntryPage(dex, known);
  }

  if (dexDetailPage === 0 && known) drawCryButton(dex);

  // Two page dots -- tap either to switch pages, matching PetScreen.swift's
  // portrait/dex-entry split.
  const dotsX = TP.cx - 13;
  for (let i = 0; i < 2; i++) {
    const cx = dotsX + i * 26;
    ctx.beginPath();
    ctx.arc(cx, 400, i === dexDetailPage ? 5 : 4, 0, Math.PI * 2);
    if (i === dexDetailPage) { ctx.fillStyle = UI.ink; ctx.fill(); }
    else { ctx.strokeStyle = UI.ink; ctx.lineWidth = 1; ctx.stroke(); }
  }

  ctx.fillStyle = UI.track;
  ctx.font = "15px monospace";
  ctx.fillText(fns.detailBackText(), TP.cx, 424);

  statusEl.textContent = `Dex detail · #${dex} ${known ? fns.dexName(dex) : "???"}`;
}

// Port of PetScreen.swift's drawCryButton/cryButtonRect: a capsule that
// fills with the POKeDEX masthead's own red as the clip plays, sitting
// between the portrait and the page dots. Hidden entirely when this species
// has no cry file installed -- same guard as the tap handler's.
// Computed on call, not at load: dex.js is parsed before main.js, where TP
// is defined, so a top-level `TP.cx` here would throw during script load
// (and leave this const permanently in its temporal dead zone).
function cryBtnRect() {
  return { x: TP.cx - 75, y: 326, w: 150, h: 20 };
}

function drawCryButton(dex) {
  if (!hasCry(dex)) return;
  const r = cryBtnRect(), radius = r.h / 2;
  ctx.fillStyle = UI.white;
  roundRect(r.x, r.y, r.w, r.h, radius);
  ctx.fill();
  ctx.strokeStyle = UI.ink;
  ctx.lineWidth = 1;
  roundRect(r.x, r.y, r.w, r.h, radius);
  ctx.stroke();

  const progress = cryProgress(dex);
  if (progress !== null && progress > 0) {
    ctx.fillStyle = "rgb(216,31,38)";  // the masthead red, as on iOS
    roundRect(r.x + 2, r.y + 2, (r.w - 4) * progress, r.h - 4, radius - 2);
    ctx.fill();
  }

  // The icon gets its own circle at the capsule's left end rather than
  // sitting directly on the (sometimes red) track, so it stays legible
  // whether or not the gauge has reached that far yet.
  const icx = r.x + radius, icy = r.y + r.h / 2;
  const playing = progress !== null;
  ctx.beginPath();
  ctx.arc(icx, icy, radius - 2, 0, Math.PI * 2);
  ctx.fillStyle = playing ? "rgb(216,31,38)" : UI.ink;
  ctx.fill();
  ctx.fillStyle = UI.white;
  if (playing) {                       // pause bars
    ctx.fillRect(icx - 4, icy - 5, 3, 10);
    ctx.fillRect(icx + 1, icy - 5, 3, 10);
  } else {                             // play triangle
    ctx.beginPath();
    ctx.moveTo(icx - 3, icy - 5);
    ctx.lineTo(icx - 3, icy + 5);
    ctx.lineTo(icx + 5, icy);
    ctx.closePath();
    ctx.fill();
  }
}

// Port of drawDexEntry(): a bordered text box, shrink-and-wrap. Simplified
// from TPDexEntryText.wrap's real-width/character-mode wrapping to plain
// canvas measureText word-wrap -- good enough for the Latin-script text the
// picked entry files actually contain (PokeAPI's "ko" text wraps oddly as a
// result, same caveat the file-picker note below calls out).
function drawDexEntryPage(dex, known) {
  const x = 50, y = 146, w = 366, h = 236;
  ctx.fillStyle = UI.white;
  roundRect(x, y, w, h, 12); ctx.fill();
  ctx.strokeStyle = UI.ink; ctx.lineWidth = 1;
  roundRect(x, y, w, h, 12); ctx.stroke();

  const text = known ? dexEntryFor(dex) : null;
  if (!text) {
    ctx.fillStyle = UI.track;
    ctx.textAlign = "center";
    ctx.font = "15px monospace";
    ctx.fillText(known ? "NO DEX ENTRY" : "???", TP.cx, y + h / 2 + 5);
    return;
  }

  const pad = 14, usableW = w - 2 * pad;
  ctx.font = "15px monospace";
  ctx.textAlign = "left";
  const words = text.split(" ");
  const lines = [];
  let line = "";
  for (const word of words) {
    const candidate = line ? line + " " + word : word;
    if (ctx.measureText(candidate).width <= usableW) { line = candidate; continue; }
    if (line) lines.push(line);
    line = word;
  }
  if (line) lines.push(line);

  const lineH = 21;
  let ty = y + pad + 13;
  for (const l of lines) {
    if (ty > y + h - pad) break; // overflow: same "just stop" as a fixed box
    ctx.fillStyle = UI.ink;
    ctx.fillText(l, x + pad, ty);
    ty += lineH;
  }
}

function dexGridTap(x, y) {
  for (let i = 0; i < 3; i++) {
    const p = DEX_FILTER_PILLS[i];
    if (x >= p.x && x < p.x + p.w && y >= 70 && y < 88) {
      dexFilter = i; dexPage = 0;
      return;
    }
  }
  if (y >= GAL_Y && y < GAL_Y + 4 * GAL_CELL) {
    const c = Math.floor((x - GAL_X) / GAL_CELL);
    const r = Math.floor((y - GAL_Y) / GAL_CELL);
    if (c >= 0 && c < 4 && r >= 0 && r < 4) {
      const dex = dexAt(dexPage * 16 + r * 4 + c);
      if (dex > 0) { dexDetailDex = dex; dexDetailPage = 0; dexScreen = "detail"; return; }
    }
  }
  if (y >= 448 && y < 464) {
    const pages = dexPageCount();
    if (x < TP.cx) dexPage = (dexPage - 1 + pages) % pages;
    else dexPage = (dexPage + 1) % pages;
    return;
  }
  if (y > 460) screen = "idle";
}

function dexDetailTap(x, y) {
  // Cry capsule, page 0 only and only for a species with a file installed
  // -- tapping it again while it plays stops it, as on iOS.
  const known = fns.dexRegistered(dexDetailDex) !== 0 || fns.dexCaught(dexDetailDex) !== 0;
  const cb = cryBtnRect();
  if (dexDetailPage === 0 && known && hasCry(dexDetailDex) &&
      x >= cb.x && x <= cb.x + cb.w &&
      y >= cb.y - 6 && y <= cb.y + cb.h + 6) {
    if (cryProgress(dexDetailDex) !== null) stopCry();
    else playCry(dexDetailDex);
    return;
  }
  if (y >= 388 && y <= 412) {
    const next = x < TP.cx ? 0 : 1;
    if (next !== 0) stopCry();  // leaving page 0 -- its button goes with it
    dexDetailPage = next;
    return;
  }
  // Only the "tap: back" hint (drawn at y 424) closes the detail view now,
  // not the whole rest of the screen -- same reasoning as cardTap's fix.
  if (x >= 66 && x <= 400 && y >= 412 && y <= 444) {
    stopCry();
    dexScreen = "grid";
  }
}
