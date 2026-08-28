// Ball-tapping minigame, ported from Sources/Shared/MiniGames.swift's
// TPBallGame (itself translated from TamaPoke.ino's startGame/respawnBall/
// stepGame/renderGame -- see LICENSE/NOTICE). Physics only: main.js owns
// drawing and input, same split as the Swift port keeps between
// MiniGames.swift and PetScreen.swift.
//
// The other four minigames (Catch/Memo/Clean/Type, all from the
// ShadowEnemyx/TamaPoke "Expanded" fork) are not ported yet -- see
// browser_ver/README.md's roadmap.

const BallGame = {
  score: 0,
  misses: 0,
  ballX: 233, ballY: 96,
  vx: 0, vy: 0,
  petX: 233,
  hitX: 0, hitY: 0, hitAt: 0,
  overUntil: 0,
  newHigh: false,
  running: false,

  start() {
    this.score = 0;
    this.misses = 0;
    this.overUntil = 0;
    this.hitAt = 0;
    this.petX = 233;
    this.running = true;
    this.respawn();
  },

  respawn() {
    this.ballX = 150 + Math.random() * 166;
    this.ballY = 96;
    const speed = Math.min(1.6 + this.score * 0.05, 4.0);
    this.vx = Math.random() < 0.5 ? speed : -speed;
    this.vy = 0;
  },

  // dtMs scaled against the fork's own ~85ms frame, same as the Swift port,
  // so the ball moves at the same speed regardless of this port's tick rate.
  step(dtMs, now) {
    if (!this.running || this.overUntil !== 0) return;
    const k = Math.min(dtMs, 100) / 85.0;
    const gravity = Math.min(0.40 + this.score * 0.013, 0.80);
    this.vy += gravity * k;
    this.ballX += this.vx * k;
    this.ballY += this.vy * k;

    const dx = this.ballX - TP.cx, dy = this.ballY - TP.cy;
    const d = Math.sqrt(dx * dx + dy * dy);
    if (d > 205 && d > 0) {
      const nx = dx / d, ny = dy / d;
      const dot = this.vx * nx + this.vy * ny;
      if (dot > 0) {
        this.vx = (this.vx - 2 * dot * nx) * 0.85;
        this.vy = (this.vy - 2 * dot * ny) * 0.85;
      }
      this.ballX = TP.cx + nx * 205;
      this.ballY = TP.cy + ny * 205;
    }

    if (this.ballY > 384) {
      this.misses += 1;
      if (this.misses >= 3) {
        this.newHigh = Module._tp_play_result(this.score) !== 0;
        this.overUntil = now + 4000;
      } else {
        this.respawn();
      }
    }

    this.petX += Math.max(Math.min((this.ballX - this.petX) * 0.12 * k, 7), -7);
  },

  // Returns true if the tap connected.
  tap(x, y, now) {
    if (this.overUntil !== 0) return false;
    const dx = this.ballX - x, dy = this.ballY - y;
    if (dx * dx + dy * dy >= 74 * 74) return false;
    this.score += 1;
    const lift = 6.6 + (this.score > 16 ? 3.5 : this.score * 0.22);
    this.vy = -lift;
    this.vx = Math.max(Math.min(this.vx + dx * 0.12, 6.5), -6.5);
    this.hitX = this.ballX;
    this.hitY = this.ballY;
    this.hitAt = now;
    return true;
  },
};
