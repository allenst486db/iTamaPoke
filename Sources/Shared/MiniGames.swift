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
