// The five minigames, ported from Sources/Shared/MiniGames.swift. Ball is
// from TamaPoke.ino itself; Catch/Memo/Clean/Type are from the
// ShadowEnemyx/TamaPoke ("Expanded") fork -- see upstream-expanded/README.md
// and LICENSE/NOTICE. Physics/timers/sequence state only: main.js owns
// drawing and input, same split MiniGames.swift keeps from PetScreen.swift.
const rnd = (n) => Math.floor(Math.random() * n);

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

// Catch: tap a moving target before it (or your patience) runs out. Ports
// TPCatchGame -- mirrors spawnCatchTarget/catchTap/finishCatchGame.
const CatchGame = {
  score: 0, misses: 0,
  targetX: 233, targetY: 220,
  icon: 0, // 0 food, 1 red berry, 2 green berry
  targetUntil: 0, runUntil: 0,
  hitX: 0, hitY: 0, hitAt: 0,
  overUntil: 0, newHigh: false,

  start(now) {
    this.score = 0; this.misses = 0; this.overUntil = 0; this.hitAt = 0;
    this.runUntil = now + 20000;
    this.respawn(now);
  },
  respawn(now) {
    this.targetX = 86 + rnd(294);
    this.targetY = 118 + rnd(206);
    this.icon = rnd(3);
    const speedup = Math.min(this.score * 35, 530);
    this.targetUntil = now + (980 - speedup);
  },
  step(now) {
    if (this.overUntil !== 0) return;
    if (now >= this.runUntil || this.misses >= 3) {
      this.newHigh = Module._tp_catch_result(this.score) !== 0;
      this.overUntil = now + 4000;
      return;
    }
    if (now >= this.targetUntil) {
      this.misses += 1;
      if (this.misses >= 3) {
        this.newHigh = Module._tp_catch_result(this.score) !== 0;
        this.overUntil = now + 4000;
      } else {
        this.respawn(now);
      }
    }
  },
  // A bad tap ends the target immediately (unlike upstream, which leaves it
  // up for its last sliver of life -- see TPCatchGame.tap's own comment on
  // why the Swift port already made this deliberate change).
  tap(x, y, now) {
    if (this.overUntil !== 0) return "ignored";
    const dx = this.targetX - x, dy = this.targetY - y;
    if (dx * dx + dy * dy <= 52 * 52) {
      this.score += 1;
      this.hitX = this.targetX; this.hitY = this.targetY; this.hitAt = now;
      this.respawn(now);
      return "hit";
    }
    this.misses += 1;
    if (this.misses >= 3) {
      this.newHigh = Module._tp_catch_result(this.score) !== 0;
      this.overUntil = now + 4000;
    } else {
      this.respawn(now);
    }
    return "miss";
  },
};

// Memo: a Simon-style pad sequence, one step longer each round. Ports
// TPMemoGame -- mirrors startMemoRound/stepMemoGame/memoTap.
const MemoGame = {
  padX: [142, 324, 142, 324], padY: [164, 164, 318, 318],
  roundCompletePause: 900,

  seq: [], show: 0, input: 0, rounds: 0,
  activePad: -1, hintPad: -1,
  flashPad: -1, flashGood: false, flashUntil: 0,
  showing: false, nextAt: 0, failUntil: 0, turnUntil: 0,
  overUntil: 0, newHigh: false,

  get score() { return this.rounds; },

  start(now) {
    this.seq = []; this.rounds = 0; this.flashPad = -1; this.hintPad = -1;
    this.flashUntil = 0; this.failUntil = 0; this.turnUntil = 0; this.overUntil = 0;
    this.startRound(now, 350);
  },
  startRound(now, afterDelay = 350) {
    if (this.seq.length < 14) this.seq.push(rnd(4));
    this.show = 0; this.input = 0; this.activePad = -1; this.hintPad = -1;
    this.showing = true; this.nextAt = now + afterDelay; this.turnUntil = 0;
  },
  padAt(x, y) {
    for (let i = 0; i < 4; i++) {
      const dx = x - this.padX[i], dy = y - this.padY[i];
      if (dx * dx + dy * dy <= 54 * 54) return i;
    }
    return -1;
  },
  step(now) {
    if (this.overUntil !== 0) return;
    if (this.failUntil !== 0) {
      if (now >= this.failUntil) {
        this.failUntil = 0; this.hintPad = -1;
        this.newHigh = Module._tp_memo_result(this.rounds) !== 0;
        this.gain = Module._tp_last_gain();
        this.overUntil = now + 4000;
      }
      return;
    }
    if (!this.showing || now < this.nextAt) return;
    if (this.activePad >= 0) {
      this.activePad = -1;
      this.show += 1;
      if (this.show >= this.seq.length) {
        this.showing = false; this.input = 0; this.turnUntil = now + 520;
      } else {
        this.nextAt = now + 150;
      }
      return;
    }
    this.activePad = this.seq[this.show];
    playSfx(23 + this.activePad); // memoPad0..3
    this.nextAt = now + 480;
  },
  // Returns "pad" | "wrong" | "roundUp" | "finished" | "ignored", plus the
  // pad index tapped -- caller plays that pad's tone on every non-ignored
  // result, same as the Swift port's TapResult carries it through.
  tap(x, y, now) {
    if (this.overUntil !== 0 || this.showing || this.failUntil !== 0 || now < this.turnUntil) {
      return { kind: "ignored", pad: -1 };
    }
    const pad = this.padAt(x, y);
    if (pad < 0) return { kind: "ignored", pad: -1 };
    if (pad !== this.seq[this.input]) {
      this.flashPad = pad; this.flashGood = false;
      this.flashUntil = now + 620;
      this.hintPad = this.seq[this.input];
      this.failUntil = this.flashUntil;
      return { kind: "wrong", pad };
    }
    this.flashPad = pad; this.flashGood = true;
    this.input += 1;
    if (this.input >= this.seq.length) {
      this.rounds += 1;
      if (this.seq.length >= 14) {
        this.flashUntil = now + 180;
        this.newHigh = Module._tp_memo_result(this.rounds) !== 0;
        this.gain = Module._tp_last_gain();
        this.overUntil = now + 4000;
        return { kind: "finished", pad };
      }
      this.flashUntil = now + this.roundCompletePause;
      this.startRound(now, this.roundCompletePause);
      return { kind: "roundUp", pad };
    }
    this.flashUntil = now + 180;
    return { kind: "pad", pad };
  },
};

// Clean: dirt spots pop up around the habitat; scrub them before three slip
// past or the 18s run out. Ports TPCleanGame -- mirrors spawnCleanSpot/
// cleanTap/renderCleanGame.
const CleanGame = {
  score: 0, misses: 0,
  alive: [false, false, false, false],
  x: [0, 0, 0, 0], y: [0, 0, 0, 0],
  until: 0, spawnAt: 0,
  hitX: 0, hitY: 0, hitAt: 0,
  overUntil: 0, newHigh: false,

  start(now) {
    this.score = 0; this.misses = 0;
    this.alive = [false, false, false, false];
    this.hitAt = 0; this.overUntil = 0;
    this.until = now + 18000; this.spawnAt = now;
    this.spawn();
  },
  spawn() {
    for (let i = 0; i < 4; i++) {
      if (this.alive[i]) continue;
      this.x[i] = 88 + rnd(290);
      this.y[i] = 122 + rnd(224);
      this.alive[i] = true;
      return;
    }
  },
  step(now) {
    if (this.overUntil !== 0) return;
    if (now >= this.until || this.misses >= 3) {
      this.newHigh = Module._tp_clean_result(this.score) !== 0;
      this.gain = Module._tp_last_gain();
      this.overUntil = now + 4000;
      return;
    }
    if (now >= this.spawnAt) {
      if (this.alive.includes(false)) this.spawn();
      this.spawnAt = now + 720 - (this.score > 12 ? 260 : this.score * 20);
    }
  },
  tap(x, y, now) {
    if (this.overUntil !== 0) return "ignored";
    for (let i = 0; i < 4; i++) {
      if (!this.alive[i]) continue;
      const dx = x - this.x[i], dy = y - this.y[i];
      if (dx * dx + dy * dy <= 38 * 38) {
        this.alive[i] = false;
        this.score += 1;
        this.hitX = this.x[i]; this.hitY = this.y[i]; this.hitAt = now;
        return "hit";
      }
    }
    this.misses += 1;
    if (this.misses >= 3) {
      this.newHigh = Module._tp_clean_result(this.score) !== 0;
      this.gain = Module._tp_last_gain();
      this.overUntil = now + 4000;
    }
    return "miss";
  },
};

// Type: a type-effectiveness quiz -- pick which of three types beats the
// shown one before the 4.2s clock runs out. Ports TPTypeGame -- mirrors
// nextTypeQuestion/typeTap/renderTypeGame. Type ids are dex.h's TYPE_*
// values (1 NORMAL .. 18 FAIRY), matching browser_glue.cpp's
// tp_type_effect_pct wrapper around the real battleTypeEffectPct.
const TypeGame = {
  defenders: [5, 2, 3, 4, 13, 9, 10, 8, 11, 14, 15, 6, 16, 17, 18],
  counters: [2, 3, 5, 9, 3, 3, 4, 11, 12, 14, 6, 2, 7, 2, 17],
  options: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18],

  enemy: 0, choices: [0, 0, 0], correct: 0,
  until: 0, score: 0, misses: 0,
  overUntil: 0, newHigh: false,

  start(now) {
    this.score = 0; this.misses = 0; this.overUntil = 0;
    this.nextQuestion(now);
  },
  nextQuestion(now) {
    const q = rnd(this.defenders.length);
    this.enemy = this.defenders[q];
    const answer = this.counters[q];
    this.correct = rnd(3);
    this.choices = [0, 0, 0];
    this.choices[this.correct] = answer;
    for (let i = 0; i < 3; i++) {
      if (i === this.correct) continue;
      let cand;
      do {
        cand = this.options[rnd(this.options.length)];
      } while (cand === answer || this.choices.includes(cand) ||
               Module._tp_type_effect_pct(cand, this.enemy) > 100);
      this.choices[i] = cand;
    }
    this.until = now + 4200;
  },
  step(now) {
    if (this.overUntil !== 0) return;
    if (now < this.until) return;
    this.misses += 1;
    if (this.misses >= 3) {
      this.newHigh = Module._tp_type_result(this.score) !== 0;
      this.gain = Module._tp_last_gain();
      this.overUntil = now + 4000;
    } else {
      this.nextQuestion(now);
    }
  },
  choiceAt(x, y) {
    // Same three 290x48 buttons renderTypeGame draws at x 88, y 210+60i.
    for (let i = 0; i < 3; i++) {
      const by = 210 + i * 60;
      if (x >= 88 && x <= 378 && y >= by && y <= by + 48) return i;
    }
    return -1;
  },
  tap(choice, now) {
    if (this.overUntil !== 0) return "ignored";
    if (choice === this.correct) {
      this.score += 1;
      this.nextQuestion(now);
      return "hit";
    }
    this.misses += 1;
    if (this.misses >= 3) {
      this.newHigh = Module._tp_type_result(this.score) !== 0;
      this.gain = Module._tp_last_gain();
      this.overUntil = now + 4000;
    }
    return "miss";
  },
};

// Training sack: 10 seconds of tapping, then the strength it bought.
// Ports TPSackGame; scoring/high-score live in C++ (browser_card2.cpp's
// tp_sack_* -- see the Battle-page "TRAIN STRENGTH" button that opens
// this).
const SackGame = {
  shake: 0,
  start(now) { this.shake = 0; Module._tp_sack_start(now); },
  step(now) {
    Module._tp_sack_step(now);
    if (this.shake > 0) this.shake = Math.max(0, this.shake - 1);
  },
  tap(now) {
    if (Module._tp_sack_is_over() !== 0) return;
    Module._tp_sack_tap(now);
    this.shake = 16;
  },
};
