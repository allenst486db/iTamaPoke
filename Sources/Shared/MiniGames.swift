//
// The ball minigame and the training sack, translated from TamaPoke by
// Quique Tortosa, MIT licensed: https://github.com/socquique/TamaPoke
// (startGame/respawnBall/stepGame/renderGame and startSack/sackTap/renderSack
// in TamaPoke.ino). See LICENSE.
//

import SwiftUI

/// Ball-tapping minigame state. Upstream keeps this in file-scope globals and
/// steps it inside `renderGame`; here the physics lives in the model so a draw
/// pass stays free of side effects, same split as the walk scheduler.
struct TPBallGame {
    var score: UInt16 = 0
    var misses = 0
    var ballX: CGFloat = 233
    var ballY: CGFloat = 96
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    /// Where the creature is chasing the ball from.
    var petX: CGFloat = 233
    /// Impact ring: where and when the last hit landed.
    var hitX: CGFloat = 0
    var hitY: CGFloat = 0
    var hitAt: UInt64 = 0
    /// Non-zero once the run is over, holding the deadline for the result card.
    var overUntil: UInt64 = 0
    var newHigh = false

    mutating func start() {
        score = 0
        misses = 0
        overUntil = 0
        hitAt = 0
        petX = 233
        respawn()
    }

    mutating func respawn() {
        ballX = CGFloat(Int.random(in: 150..<316))
        ballY = 96
        let speed = min(1.6 + CGFloat(score) * 0.05, 4.0)
        vx = Bool.random() ? speed : -speed
        vy = 0
    }

    /// One physics step. `dt` is scaled against upstream's ~85ms frame so the
    /// ball moves at the same speed regardless of this port's tick rate.
    mutating func step(dtMs: UInt64, now: UInt64, onGameOver: (UInt16) -> Bool) {
        let k = min(CGFloat(dtMs), 100) / 85.0
        let gravity = min(0.40 + CGFloat(score) * 0.013, 0.80)
        vy += gravity * k
        ballX += vx * k
        ballY += vy * k

        // Bounce off the round wall, losing a little energy each time.
        let dx = ballX - TP.cx, dy = ballY - TP.cy
        let d = sqrt(dx * dx + dy * dy)
        if d > 205, d > 0 {
            let nx = dx / d, ny = dy / d
            let dot = vx * nx + vy * ny
            if dot > 0 {
                vx = (vx - 2 * dot * nx) * 0.85
                vy = (vy - 2 * dot * ny) * 0.85
            }
            ballX = TP.cx + nx * 205
            ballY = TP.cy + ny * 205
        }

        if ballY > 384 {                      // hit the floor
            misses += 1
            if misses >= 3 {
                newHigh = onGameOver(score)
                overUntil = now + 4000
            } else {
                respawn()
            }
        }

        // The creature trails the ball along the ground.
        petX += max(min((ballX - petX) * 0.12 * k, 7), -7)
    }

    /// Returns true when the tap connected with the ball.
    mutating func tap(_ p: CGPoint, now: UInt64) -> Bool {
        guard overUntil == 0 else { return false }
        let dx = ballX - p.x, dy = ballY - p.y
        guard dx * dx + dy * dy < 74 * 74 else { return false }
        score += 1
        let lift = 6.6 + (score > 16 ? 3.5 : CGFloat(score) * 0.22)
        vy = -lift
        vx = max(min(vx + dx * 0.12, 6.5), -6.5)
        hitX = ballX
        hitY = ballY
        hitAt = now
        return true
    }
}

/// Catch minigame: tap a moving target before it (or your patience) runs out.
/// Translated from ShadowEnemyx/TamaPoke ("TamaPoke — Expanded"), a separate
/// community fork -- not from the upstream/ submodule; see
/// upstream-expanded/README.md. Mirrors spawnCatchTarget/catchTap/
/// finishCatchGame in that fork's TamaPoke.ino.
struct TPCatchGame {
    var score: UInt16 = 0
    var misses = 0
    var targetX: CGFloat = 233
    var targetY: CGFloat = 220
    /// 0 food, 1 red berry, 2 green berry -- which icon the target draws as.
    var icon = 0
    var targetUntil: UInt64 = 0
    var runUntil: UInt64 = 0
    /// Impact ring: where and when the last hit landed.
    var hitX: CGFloat = 0
    var hitY: CGFloat = 0
    var hitAt: UInt64 = 0
    var overUntil: UInt64 = 0
    var newHigh = false

    mutating func start(now: UInt64) {
        score = 0
        misses = 0
        overUntil = 0
        hitAt = 0
        runUntil = now + 20000
        respawn(now: now)
    }

    mutating func respawn(now: UInt64) {
        targetX = CGFloat(86 + Int.random(in: 0..<294))
        targetY = CGFloat(118 + Int.random(in: 0..<206))
        icon = Int.random(in: 0..<3)
        let speedup = min(UInt64(score) * 35, 530)
        targetUntil = now + (980 - speedup)
    }

    /// Call once per frame; fires `onGameOver` when the timer or three misses
    /// end the run.
    mutating func step(now: UInt64, onGameOver: (UInt16) -> Bool) {
        guard overUntil == 0 else { return }
        if now >= runUntil || misses >= 3 {
            newHigh = onGameOver(score)
            overUntil = now + 4000
            return
        }
        if now >= targetUntil {
            misses += 1
            if misses >= 3 {
                newHigh = onGameOver(score)
                overUntil = now + 4000
            } else {
                respawn(now: now)
            }
        }
    }

    /// A miss (unlike the ball game's) counts toward the same three strikes
    /// as a missed target -- upstream's catchTap ends the run on a bad tap
    /// same as on a timeout.
    mutating func tap(_ p: CGPoint, now: UInt64, onGameOver: (UInt16) -> Bool) -> TPCatchTapResult {
        guard overUntil == 0 else { return .ignored }
        let dx = targetX - p.x, dy = targetY - p.y
        if dx * dx + dy * dy <= 52 * 52 {
            score += 1
            hitX = targetX
            hitY = targetY
            hitAt = now
            respawn(now: now)
            return .hit
        }
        misses += 1
        if misses >= 3 {
            newHigh = onGameOver(score)
            overUntil = now + 4000
        }
        return .miss
    }
}

enum TPCatchTapResult { case hit, miss, ignored }

/// Memo minigame: a Simon-style pad sequence that grows one step per round.
/// Translated from ShadowEnemyx/TamaPoke ("TamaPoke — Expanded") -- see
/// upstream-expanded/README.md. Mirrors startMemoRound/stepMemoGame/memoTap.
struct TPMemoGame {
    /// The four pads' centres and hit radius, from the fork's memoPadAt.
    static let padX: [CGFloat] = [142, 324, 142, 324]
    static let padY: [CGFloat] = [164, 164, 318, 318]

    var seq: [Int] = []
    var show = 0
    var input = 0
    var rounds: UInt16 = 0
    /// Pad currently lit during playback, or the correct pad during the
    /// you-got-it-wrong flash; -1 otherwise.
    var activePad = -1
    var hintPad = -1
    /// Player-tap feedback ring: which pad, whether it was right, until when.
    var flashPad = -1
    var flashGood = false
    var flashUntil: UInt64 = 0
    var showing = false
    var nextAt: UInt64 = 0
    var failUntil: UInt64 = 0
    /// Brief pause between playback ending and input opening.
    var turnUntil: UInt64 = 0
    var overUntil: UInt64 = 0
    var newHigh = false
    var gain: UInt8 = 0

    var score: UInt16 { rounds }

    mutating func start(now: UInt64) {
        seq = []
        rounds = 0
        flashPad = -1
        hintPad = -1
        flashUntil = 0
        failUntil = 0
        turnUntil = 0
        overUntil = 0
        gain = 0
        startRound(now: now)
    }

    mutating func startRound(now: UInt64) {
        if seq.count < 14 { seq.append(Int.random(in: 0..<4)) }
        show = 0
        input = 0
        activePad = -1
        hintPad = -1
        showing = true
        nextAt = now + 350
        turnUntil = 0
    }

    /// Advances the playback and the fail timer. `playPad` fires the pad's own
    /// tone as it lights; `onGameOver` runs once when a wrong tap's flash ends
    /// and returns the record flag and stat gain to store -- returned rather
    /// than written by the caller, since the caller's own state (GameModel's
    /// `memoGame`) is this very struct, still under this call's mutating
    /// access; writing back through `self` from inside the closure is a
    /// same-instance exclusivity violation and crashes at runtime.
    mutating func step(now: UInt64, playPad: (Int) -> Void,
                       onGameOver: (UInt16) -> (newHigh: Bool, gain: UInt8)) {
        guard overUntil == 0 else { return }
        if failUntil != 0 {
            if now >= failUntil {
                failUntil = 0
                hintPad = -1
                (newHigh, gain) = onGameOver(rounds)
                overUntil = now + 4000
            }
            return
        }
        guard showing, now >= nextAt else { return }
        if activePad >= 0 {
            activePad = -1
            show += 1
            if show >= seq.count {
                showing = false
                input = 0
                turnUntil = now + 520
            } else {
                nextAt = now + 150
            }
            return
        }
        activePad = seq[show]
        playPad(activePad)
        nextAt = now + 480
    }

    static func padAt(_ p: CGPoint) -> Int {
        for i in 0..<4 {
            let dx = p.x - padX[i], dy = p.y - padY[i]
            if dx * dx + dy * dy <= 54 * 54 { return i }
        }
        return -1
    }

    enum TapResult { case pad(Int), wrong, roundUp, finished, ignored }

    /// One tap during the player's turn. A wrong pad starts the fail flash (the
    /// game ends when it runs out, via step); completing the sequence starts
    /// the next round, or finishes at the 14-step cap.
    mutating func tap(_ p: CGPoint, now: UInt64,
                      onGameOver: (UInt16) -> (newHigh: Bool, gain: UInt8)) -> TapResult {
        guard overUntil == 0, !showing, failUntil == 0, now >= turnUntil else { return .ignored }
        let pad = Self.padAt(p)
        guard pad >= 0 else { return .ignored }
        if pad != seq[input] {
            flashPad = pad
            flashGood = false
            flashUntil = now + 620
            hintPad = seq[input]
            failUntil = flashUntil
            return .wrong
        }
        flashPad = pad
        flashGood = true
        flashUntil = now + 180
        input += 1
        if input >= seq.count {
            rounds += 1
            if seq.count >= 14 {
                (newHigh, gain) = onGameOver(rounds)
                overUntil = now + 4000
                return .finished
            }
            startRound(now: now)
            return .roundUp
        }
        return .pad(pad)
    }
}

/// Clean minigame: dirt spots pop up around the habitat; scrub them before
/// three slip past your fingers or the 18 seconds run out. Translated from
/// ShadowEnemyx/TamaPoke ("TamaPoke — Expanded") -- see
/// upstream-expanded/README.md. Mirrors spawnCleanSpot/cleanTap/renderCleanGame.
struct TPCleanGame {
    var score: UInt16 = 0
    var misses = 0
    var alive = [Bool](repeating: false, count: 4)
    var x = [CGFloat](repeating: 0, count: 4)
    var y = [CGFloat](repeating: 0, count: 4)
    var until: UInt64 = 0
    var spawnAt: UInt64 = 0
    /// Impact ring: where and when the last scrub landed.
    var hitX: CGFloat = 0
    var hitY: CGFloat = 0
    var hitAt: UInt64 = 0
    var overUntil: UInt64 = 0
    var newHigh = false
    var gain: UInt8 = 0

    mutating func start(now: UInt64) {
        score = 0
        misses = 0
        alive = [false, false, false, false]
        hitAt = 0
        overUntil = 0
        gain = 0
        until = now + 18000
        spawnAt = now
        spawn()
    }

    mutating func spawn() {
        for i in 0..<4 where !alive[i] {
            x[i] = CGFloat(88 + Int.random(in: 0..<290))
            y[i] = CGFloat(122 + Int.random(in: 0..<224))
            alive[i] = true
            return
        }
    }

    /// See TPMemoGame.step's doc comment for why `onGameOver` returns rather
    /// than the caller writing this struct's fields directly.
    mutating func step(now: UInt64, onGameOver: (UInt16) -> (newHigh: Bool, gain: UInt8)) {
        guard overUntil == 0 else { return }
        if now >= until || misses >= 3 {
            (newHigh, gain) = onGameOver(score)
            overUntil = now + 4000
            return
        }
        if now >= spawnAt {
            if alive.contains(false) { spawn() }
            spawnAt = now + 720 - (score > 12 ? 260 : UInt64(score) * 20)
        }
    }

    /// A miss counts toward the same three strikes as the timer, like the
    /// catch game's.
    mutating func tap(_ p: CGPoint, now: UInt64,
                      onGameOver: (UInt16) -> (newHigh: Bool, gain: UInt8)) -> TPCatchTapResult {
        guard overUntil == 0 else { return .ignored }
        for i in 0..<4 where alive[i] {
            let dx = p.x - x[i], dy = p.y - y[i]
            if dx * dx + dy * dy <= 38 * 38 {
                alive[i] = false
                score += 1
                hitX = x[i]
                hitY = y[i]
                hitAt = now
                return .hit
            }
        }
        misses += 1
        if misses >= 3 {
            (newHigh, gain) = onGameOver(score)
            overUntil = now + 4000
        }
        return .miss
    }
}

/// Type minigame: a type-effectiveness quiz — pick which of three types beats
/// the shown one before the 4.2s clock runs out. Translated from
/// ShadowEnemyx/TamaPoke ("TamaPoke — Expanded") -- see
/// upstream-expanded/README.md. Mirrors nextTypeQuestion/typeTap/renderTypeGame.
/// Type ids are dex.h's TYPE_* values (1 NORMAL ... 18 FAIRY).
struct TPTypeGame {
    /// The fork's question pools: each defender pairs with one super-effective
    /// counter; distractors come from the option pool, filtered so none of
    /// them is also super-effective (checked via battleTypeEffectPct).
    static let defenders: [UInt8] = [5, 2, 3, 4, 13, 9, 10, 8, 11, 14, 15, 6]
    static let counters: [UInt8] = [2, 3, 5, 9, 3, 3, 4, 11, 12, 14, 6, 2]
    static let options: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

    var enemy: UInt8 = 0
    var choices: [UInt8] = [0, 0, 0]
    var correct = 0
    var until: UInt64 = 0
    var score: UInt16 = 0
    var misses = 0
    var overUntil: UInt64 = 0
    var newHigh = false
    var gain: UInt8 = 0

    mutating func start(now: UInt64) {
        score = 0
        misses = 0
        overUntil = 0
        gain = 0
        nextQuestion(now: now)
    }

    /// `effectPct` is battleTypeEffectPct(attacker, defender, TYPE_NONE),
    /// injected so this struct stays free of the C++ bridge.
    mutating func nextQuestion(now: UInt64, effectPct: (UInt8, UInt8) -> Int = { _, _ in 100 }) {
        let q = Int.random(in: 0..<Self.defenders.count)
        enemy = Self.defenders[q]
        let answer = Self.counters[q]
        correct = Int.random(in: 0..<3)
        choices = [0, 0, 0]
        choices[correct] = answer
        for i in 0..<3 where i != correct {
            var cand: UInt8
            repeat {
                cand = Self.options.randomElement()!
            } while cand == answer || choices.contains(cand) || effectPct(cand, enemy) > 100
            choices[i] = cand
        }
        until = now + 4200
    }

    /// Fires on the question clock: a timeout costs a miss and (below three)
    /// deals the next question — the caller passes the same distractor filter
    /// nextQuestion needs.
    mutating func step(now: UInt64, effectPct: (UInt8, UInt8) -> Int,
                       onGameOver: (UInt16) -> (newHigh: Bool, gain: UInt8)) -> Bool {
        guard overUntil == 0 else { return false }
        guard now >= until else { return false }
        misses += 1
        if misses >= 3 {
            (newHigh, gain) = onGameOver(score)
            overUntil = now + 4000
            return false
        }
        nextQuestion(now: now, effectPct: effectPct)
        return true
    }

    /// The three answer rows' hit areas, from the fork's typeTap.
    static func choiceAt(_ p: CGPoint) -> Int? {
        for i in 0..<3 {
            let by = CGFloat(210 + i * 60)
            if p.x >= 70, p.x <= 396, p.y >= by - 8, p.y <= by + 56 { return i }
        }
        return nil
    }

    mutating func tap(choice: Int, now: UInt64, effectPct: (UInt8, UInt8) -> Int,
                      onGameOver: (UInt16) -> (newHigh: Bool, gain: UInt8)) -> TPCatchTapResult {
        guard overUntil == 0 else { return .ignored }
        if choice == correct {
            score += 1
            nextQuestion(now: now, effectPct: effectPct)
            return .hit
        }
        misses += 1
        if misses >= 3 {
            (newHigh, gain) = onGameOver(score)
            overUntil = now + 4000
        }
        return .miss
    }
}

/// Training sack state: 10 seconds of tapping, then the strength it bought.
struct TPSackGame {
    var hits: UInt16 = 0
    var until: UInt64 = 0
    /// Non-zero once time is up, holding the deadline for the result card.
    var overUntil: UInt64 = 0
    var gain: UInt8 = 0
    var newHigh = false
    /// Decaying shake applied to the sack after each hit.
    var shake: CGFloat = 0

    mutating func start(now: UInt64) {
        hits = 0
        gain = 0
        newHigh = false
        shake = 0
        overUntil = 0
        until = now + 10000
    }

    mutating func tap(now: UInt64) {
        guard now < until else { return }
        hits += 1
        shake = 16
    }
}
