// The idle backdrop, ported line for line from Sources/Shared/
// SceneRenderer.swift -- itself translated from TamaPoke by Quique Tortosa,
// MIT licensed: https://github.com/socquique/TamaPoke (TamaPoke.ino's
// drawScene/drawClouds). The biome palette, star field and animation phases
// are his. See LICENSE.
//
// Sky painted from the real clock (dawn / day / dusk / night), ground from
// the species' type biome, sun/moon/clouds/stars and per-biome detail on top.
// The browser build used to paint a flat panel colour here, which is the
// single biggest reason it didn't *look* like the iOS app even once every
// screen was ported -- the creature's whole world was missing.

const SCENE_HORIZON = 232;  // TP.horizon: where sky meets ground

// Upstream's C565 / lerp565, component-wise in 565 space (not linear RGB)
// so gradients match the hardware -- and the iOS build -- exactly.
function c565(r, g, b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}
function lerp565(a, b, i, n) {
  if (n <= 0) return a;
  const ar = (a >> 11) & 31, ag = (a >> 5) & 63, ab = a & 31;
  const br = (b >> 11) & 31, bg = (b >> 5) & 63, bb = b & 31;
  const r = ar + Math.trunc((br - ar) * i / n);
  const g = ag + Math.trunc((bg - ag) * i / n);
  const bl = ab + Math.trunc((bb - ab) * i / n);
  return (r << 11) | (g << 5) | bl;
}

// Daytime ground per biome; night blends toward the night blue.
const BIOME_SOIL = [
  c565(0x7e, 0xc0, 0x7f),  // 0 meadow
  c565(0xdc, 0xca, 0x94),  // 1 beach (sand)
  c565(0x4f, 0x8a, 0x55),  // 2 forest
  c565(0x8a, 0x55, 0x44),  // 3 volcano
  c565(0xa8, 0x90, 0x6a),  // 4 mountain
  c565(0xe6, 0xee, 0xf5),  // 5 snow
];

const SCENE_STARS = [[120, 140], [330, 120], [370, 210], [95, 230], [280, 90], [160, 95]];

// Hour of day 0-23, in the device's local zone -- the sky follows the
// player's own clock, same as SceneRenderer.hour's TimeZone.current
// correction on iOS. Upstream's firmware reads a local RTC, which is why
// no timezone term appears there.
function sceneHour() {
  return new Date().getHours();
}

function sceneIsNight(hour, sleeping) {
  return sleeping || hour < 6 || hour >= 20;
}

function sceneFillRect(x, y, w, h, c565v) {
  ctx.fillStyle = rgb565(c565v);
  ctx.fillRect(x, y, w, h);
}
function sceneFillCircle(cx, cy, r, c565v) {
  ctx.fillStyle = rgb565(c565v);
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.fill();
}
function sceneFillTriangle(x0, y0, x1, y1, x2, y2, c565v) {
  ctx.fillStyle = rgb565(c565v);
  ctx.beginPath();
  ctx.moveTo(x0, y0);
  ctx.lineTo(x1, y1);
  ctx.lineTo(x2, y2);
  ctx.closePath();
  ctx.fill();
}
function sceneFillRoundRect(x, y, w, h, r, c565v) {
  ctx.fillStyle = rgb565(c565v);
  roundRect(x, y, w, h, r);
  ctx.fill();
}

function drawClouds(now, col) {
  for (let k = 0; k < 2; k++) {
    const cx = ((Math.floor(now / 50) + k * 250) % 560) - 40;
    const cy = 70 + k * 34;
    sceneFillCircle(cx, cy, 16, col);
    sceneFillCircle(cx + 18, cy + 3, 13, col);
    sceneFillCircle(cx - 15, cy + 4, 12, col);
  }
}

// `now` is milliseconds, matching upstream's millis() animation phases.
function drawScene(biome, now, night, h) {
  now = Math.floor(now);
  let top, bot;
  if (night) {
    top = c565(0x0c, 0x12, 0x24); bot = c565(0x1e, 0x26, 0x46);
  } else if (h < 8) {
    top = c565(0xd1, 0x6a, 0x86); bot = c565(0xf3, 0xb8, 0x7c);   // dawn
  } else if (h < 18) {
    top = c565(0x8f, 0xc8, 0xea); bot = c565(0xdc, 0xee, 0xe6);   // day
  } else {
    top = c565(0xc7, 0x5a, 0x4a); bot = c565(0xf0, 0xae, 0x64);   // dusk
  }

  // sky, in 8px bands
  const horizon = SCENE_HORIZON;
  for (let y = 0; y < horizon; y += 8) {
    sceneFillRect(0, y, TP.screen, 8, lerp565(top, bot, y, horizon));
  }

  // sun or moon
  if (night) {
    sceneFillCircle(360, 78, 24, c565(0xe8, 0xee, 0xf5));
    sceneFillCircle(370, 72, 22, lerp565(top, bot, 78, horizon));  // carve a crescent
    for (const st of SCENE_STARS) { ctx.fillStyle = UI.white; ctx.fillRect(st[0], st[1], 4, 4); }
  } else if (h < 18) {
    sceneFillCircle(360, 84, 26, h < 8 ? c565(0xff, 0xd9, 0x8a) : c565(0xff, 0xe7, 0x9f));
    drawClouds(now, c565(0xff, 0xff, 0xff));
  } else {
    sceneFillCircle(233, horizon - 6, 34, c565(0xff, 0xf1, 0xc8));  // setting sun
  }

  let soil = BIOME_SOIL[biome >= 0 && biome < 6 ? biome : 0];
  if (night) soil = lerp565(soil, c565(0x16, 0x1c, 0x30), 9, 16);

  // beach: a strip of sea above the sand
  if (biome === 1) {
    const sea = night ? c565(0x1c, 0x34, 0x52) : c565(0x4f, 0x96, 0xc4);
    sceneFillRect(0, horizon - 26, TP.screen, 26, sea);
    for (let i = 0; i < 3; i++) {
      const wy = horizon - 22 + i * 7;
      const fc = night ? c565(0x3a, 0x58, 0x78) : c565(0xbf, 0xe6, 0xf5);
      sceneFillRect(60 + ((Math.floor(now / 60) + i * 30) % 60), wy, 26, 2, fc);
      sceneFillRect(300 - ((Math.floor(now / 60) + i * 20) % 60), wy, 26, 2, fc);
    }
  }

  // ground
  sceneFillRect(0, horizon, TP.screen, TP.screen - horizon, soil);
  const hill = lerp565(soil, night ? c565(0x0c, 0x12, 0x24) : c565(0xff, 0xff, 0xff), 3, 16);
  sceneFillRoundRect(-60, horizon - 14, 586, 60, 30, hill);

  // biome detail
  const dk = lerp565(soil, c565(0x10, 0x18, 0x20), night ? 11 : 7, 16);
  switch (biome) {
    case 2:  // forest: conifer silhouettes
      for (const tx of [60, 150, 360, 416]) {
        sceneFillTriangle(tx, horizon - 46, tx - 16, horizon, tx + 16, horizon, dk);
        sceneFillTriangle(tx, horizon - 60, tx - 12, horizon - 28, tx + 12, horizon - 28, dk);
      }
      break;
    case 3:  // volcano: rocks and embers
      sceneFillTriangle(70, horizon, 40, horizon + 30, 100, horizon + 30, dk);
      sceneFillTriangle(400, horizon + 4, 372, horizon + 30, 430, horizon + 30, dk);
      if (!night) {
        for (let e = 0; e < 4; e++) {
          sceneFillRect(120 + e * 70, horizon + 8 + (e % 2) * 6, 4, 4, c565(0xff, 0x9b, 0x3a));
        }
      }
      break;
    case 4:  // mountain: peaks on the skyline
      sceneFillTriangle(140, horizon - 50, 60, horizon, 220, horizon, dk);
      sceneFillTriangle(330, horizon - 38, 250, horizon, 410, horizon, dk);
      break;
    case 5:  // snow: falling flakes (day only, like upstream's `where !night`)
      if (!night) {
        for (let f = 0; f < 10; f++) {
          const fx = (f * 53 + Math.floor(now / 40)) % 466;
          const fy = (f * 90 + Math.floor(now / 18)) % horizon;
          ctx.fillStyle = UI.white;
          ctx.fillRect(fx, fy, 3, 3);
        }
      }
      break;
    case 0:  // meadow: tufts of grass
      for (const gx of [80, 175, 300, 395]) {
        for (let b = -1; b <= 1; b++) {
          sceneFillRect(gx + b * 5, horizon + 6, 2, 8 + (b === 0 ? 4 : 0), dk);
        }
      }
      break;
    default:
      break;
  }
}
