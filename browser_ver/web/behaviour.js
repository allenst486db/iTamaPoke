// What the creature does on the idle screen when no mood overrides it, and
// where it is standing -- ported from GameModel.swift's advanceBehaviour/
// behNext (themselves a port of the .ino's file-scope `beh` scheduler and
// drawPetPMD's action choice), plus the bath that CLEAN starts (startBath/
// stepBath, upstream's drawBath tail).
//
// The browser build used to draw one looping idle frame at screen centre,
// forever. On iOS the creature looks around, strolls to a random spot,
// does a one-shot gesture, chews when fed, curls up when asleep, flinches
// when sad -- so the two builds didn't read as the same creature even with
// identical sprites. This is that scheduler, ported line for line.

// sprites.js's TPAct, under the shorter name this file uses throughout.
const ACT = TPAct;
// PetMood, matching pet.h.
const MOOD = { happy: 0, sad: 1, eating: 2, sleeping: 3 };

// The pose the draw pass reads. Recomputed on the tick, never in a draw.
const petPose = { act: ACT.idle, x: 233, elapsedMs: 0, loop: true, yOffset: 0 };

let behMode = 0;         // 0 look ahead, 1 stroll, 2 one-shot gesture
let behAct = ACT.idle;
let behT0 = 0;
let behUntil = 0;
let behX = 233;          // TP.cx
let behTargetX = 233;
let lastPoseMs = 0;

function spriteHas(sprite, act) {
  const a = sprite && sprite.actions[act];
  return !!(a && a.frames > 0);
}
function actTotalMs(sprite, act) {
  const a = sprite.actions[act];
  if (!a) return 100;
  const total = a.ms.reduce((s, v) => s + v, 0);
  return total || 100;
}

// Port of upstream `behNext`: 35% stroll, 25% a gesture, else stand still.
// Hop and Sit are deliberately excluded from the gesture pool upstream --
// one jumps out of frame, the other turns its back.
function behNext(now, sprite) {
  behT0 = now;
  const r = Math.floor(Math.random() * 100);
  if (r < 35 && (spriteHas(sprite, ACT.walkL) || spriteHas(sprite, ACT.walkR))) {
    behMode = 1;
    behTargetX = 150 + Math.floor(Math.random() * 176);   // 150..<326
    behUntil = now + 15000;
    return;
  }
  if (r < 60) {
    const flair = [ACT.pose, ACT.nod, ACT.breath].filter((a) => spriteHas(sprite, a));
    if (flair.length) {
      behMode = 2;
      behAct = flair[Math.floor(Math.random() * flair.length)];
      behUntil = now + actTotalMs(sprite, behAct);
      return;
    }
  }
  behMode = 0;
  behUntil = now + 2000 + Math.floor(Math.random() * 3000);
}

// Port of drawPetPMD's action choice: mood wins, otherwise the scheduler
// decides between standing, strolling and a one-shot gesture.
function advanceBehaviour(now, sprite, mood) {
  if (!sprite) {
    petPose.act = ACT.idle; petPose.x = TP.cx; petPose.elapsedMs = 0;
    petPose.loop = true; petPose.yOffset = 0;
    return;
  }
  const dtMs = now - lastPoseMs;
  lastPoseMs = now;

  let act = ACT.idle;
  let loop = true;
  let yOffset = 0;

  if (mood === MOOD.sleeping && spriteHas(sprite, ACT.sleep)) {
    act = ACT.sleep;
    behMode = 0;
  } else if (mood === MOOD.eating && spriteHas(sprite, ACT.eat)) {
    act = ACT.eat;
    behT0 = 0;        // upstream free-runs the eat cycle off millis()
  } else if (mood === MOOD.eating) {
    // Only some sprite sheets carry an Eat animation. Fill the gap rather
    // than copy it (upstream falls through to the walk scheduler here, so
    // the creature may wander off mid-meal): stand still and chew.
    act = ACT.idle;
    behMode = 0;
    yOffset = Math.floor(now / 170) % 2 === 0 ? -3 : 0;
  } else if (mood === MOOD.sad && spriteHas(sprite, ACT.hurt)) {
    act = ACT.hurt;
  } else {
    if (now > behUntil) behNext(now, sprite);
    if (behMode === 1) {
      const d = behTargetX - behX;
      if (Math.abs(d) < 4) {
        behNext(now, sprite);
        act = ACT.idle;
      } else {
        // Upstream moves 3px per render and renders every 100ms. Expressed
        // as a rate so any frame cadence walks at the same speed; the clamp
        // keeps a long stall (backgrounded tab) from teleporting it.
        const step = Math.min(dtMs, 100) * 0.03;
        behX += d > 0 ? step : -step;
        act = d > 0 ? ACT.walkR : ACT.walkL;
      }
    } else {
      act = behMode === 2 ? behAct : ACT.idle;
      loop = false;
    }
    if (!spriteHas(sprite, act)) act = ACT.idle;
  }

  petPose.act = act;
  petPose.x = behX;
  petPose.elapsedMs = now - behT0;
  petPose.loop = loop || act === ACT.idle;
  petPose.yOffset = yOffset;
}

// --- Bath ------------------------------------------------------------------
//
// Soap suds over the creature after CLEAN -- no tub. Upstream seeds the
// bubbles once in startBath and defers the actual clean() until the suds
// finish, so the creature is still dirty while it is being washed;
// `bathPending` is what makes that fire exactly once.

const BATH_DURATION = 3000;
const bathBubbles = Array.from({ length: 14 }, () => ({ x: 0, y: 0, r: 0, phase: 0 }));
let bathUntil = 0;
let bathPending = false;

function startBath(now, isEgg, sleeping, ceremony) {
  if (isEgg || sleeping || ceremony !== 0 || bathUntil !== 0) return false;
  bathUntil = now + BATH_DURATION;
  bathPending = true;
  const cx = behX;
  for (const b of bathBubbles) {
    b.x = cx - 70 + Math.floor(Math.random() * 140);
    b.y = TP.petGround - Math.floor(Math.random() * 150);
    b.r = 8 + Math.floor(Math.random() * 16);
    b.phase = Math.floor(Math.random() * 64);
  }
  return true;
}

// The tail of upstream's drawBath: when the timer runs out it washes the
// creature and sets it posing. Run on the tick because it mutates the Pet.
function stepBath(now, sprite) {
  if (bathUntil === 0 || now <= bathUntil) return;
  bathUntil = 0;
  if (!bathPending) return;
  bathPending = false;
  Module._tp_clean();
  if (spriteHas(sprite, ACT.pose)) {
    behMode = 2;
    behAct = ACT.pose;
    behT0 = now;
    behUntil = now + actTotalMs(sprite, ACT.pose) * 2;
  }
}

// Port of drawBath: the bubbles sway on a sine, drift upward as the three
// seconds run down, and in the last 800ms pop into little sparkle crosses.
function drawBath(now) {
  if (bathUntil <= now) return;
  const left = bathUntil - now;
  const elapsed = BATH_DURATION > left ? BATH_DURATION - left : 0;
  if (left > 800) {
    const t = now / 220;
    for (const b of bathBubbles) {
      const bx = b.x + Math.sin(t + b.phase) * 6;
      const by = b.y - elapsed / 90;
      ctx.fillStyle = UI.white;
      ctx.beginPath(); ctx.arc(bx, by, b.r, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = rgb565(0x7E3D); ctx.lineWidth = 1;
      ctx.beginPath(); ctx.arc(bx, by, b.r, 0, Math.PI * 2); ctx.stroke();
      // The little highlight that reads as a soap bubble.
      ctx.fillStyle = UI.bgDay;
      ctx.beginPath(); ctx.arc(bx - b.r / 3, by - b.r / 3, b.r / 4, 0, Math.PI * 2); ctx.fill();
    }
  } else {
    for (let i = 0; i < 8; i++) {
      const b = bathBubbles[i];
      const sx = b.x + (i % 3) * 6 - 6;
      const sy = b.y - 18;
      ctx.fillStyle = i % 2 === 1 ? UI.barWarn : UI.white;
      ctx.fillRect(sx - 6, sy - 1, 13, 3);
      ctx.fillRect(sx - 1, sy - 6, 3, 13);
    }
  }
}
