import SwiftUI
#if os(watchOS)
import WatchKit
#elseif os(iOS)
import UIKit
#endif

/// Owns the lifecycle the firmware's `setup()` / `loop()` handled: bring the
/// C++ state up once, tick it, and persist on the way out.
///
/// There is intentionally very little state here. The renderer reads `TPPet`
/// directly every frame, exactly as the firmware's `render()` read its global
/// `pet` — so there is no second copy of game state to keep in sync.
@MainActor
final class GameModel: ObservableObject {

    let pet = TPPet.shared

    /// Bumped every tick purely so SwiftUI re-renders. The renderer reads the
    /// C++ state directly, so this is the only published value that exists.
    @Published private(set) var frame: UInt64 = 0

    /// The current species' sprite, or nil when its TPK2 file is not bundled —
    /// the normal state, since sprites are never committed. Only one species is
    /// ever resident; it is reloaded when the pet changes form.
    @Published private(set) var sprite: TPSprite?
    private var spriteKey: Int32 = .min

    /// The form being evolved away from, held only while the flash plays so it
    /// can alternate with the new one. Upstream keeps this as a second PmdMon.
    private(set) var evoSprite: TPSprite?
    private var evoSpriteKey: Int32 = .min

    /// What to draw the creature as this frame. Computed on the tick rather than
    /// inside the `Canvas` closure, because deciding it advances state (the walk
    /// scheduler) and a draw pass must not mutate the model.
    struct PetPose {
        var act: TPAct = .idle
        var x: CGFloat = TP.cx
        var elapsedMs: UInt64 = 0
        var loop: Bool = true
    }
    private(set) var pose = PetPose()

    // Port of the .ino's file-scope `beh`: what the creature does when no mood
    // overrides it, and where it is standing.
    private var behMode = 0            // 0 look ahead, 1 stroll, 2 one-shot gesture
    private var behAct: TPAct = .idle
    private var behT0: UInt64 = 0
    private var behUntil: UInt64 = 0
    private var behX: CGFloat = TP.cx
    private var behTargetX: CGFloat = TP.cx
    private var lastPoseMs: UInt64 = 0

    /// Ball minigame and training sack. Both live here rather than in the view
    /// because they advance on the tick, and a Canvas draw must not step physics.
    private(set) var ball = TPBallGame()
    private(set) var sack = TPSackGame()
    /// Which one is running. Gating on the games' own fields instead would leave
    /// a finished sack's deadline pinned, and that stale value froze the ball.
    private enum ActiveGame { case none, ball, sack }
    private var activeGame: ActiveGame = .none
    private var lastGameMs: UInt64 = 0

    private var started = false
    private let epoch = Date()

    /// Milliseconds since launch, for the Swift-side scene animations
    /// (clouds, waves, snow) that upstream phases off `millis()`.
    var millis: UInt64 { UInt64(Date().timeIntervalSince(epoch) * 1000) }

    /// Set when a save file was picked up from the Files folder on this launch,
    /// so the UI can say so rather than silently swapping the creature.
    private(set) var importedSave = false

    func start() {
        guard !started else { return }
        started = true
        pet.begin()
        #if os(iOS)
        // Before the first render: an import replaces the creature wholesale, so
        // it has to land ahead of anything reading the live Pet.
        applyPendingImport()
        TPSaveFile.writeReadme()
        TPSaveFile.writeExport()
        #endif
        refreshSprite()
        if soundEnabled { TPAudio.shared.start() }
        // Upstream's ES8311 square-wave effects are reproduced by TPAudio; the
        // haptic goes alongside, since a phone can answer a tap both ways and a
        // silent phone should still feel responsive.
        TPSetSfxHandler { [weak self] id in
            self?.emitSfx(id)
        }
    }

    /// Plays an effect from the Swift side.
    ///
    /// `pet.cpp` raises hatch, evolve, medal, level and the farewells itself, but
    /// the ones tied to input — tap, eat, play, heart — are raised by
    /// `TamaPoke.ino`, which this port replaced with SwiftUI. They are re-raised
    /// at the same points rather than being lost.
    func playSfx(_ sfx: TPSfx) { emitSfx(sfx.rawValue) }

    private func emitSfx(_ id: UInt8) {
        guard soundEnabled else { return }
        TPAudio.shared.play(id)
        Self.playFeedback()
    }

    /// Reloads the sprite when the pet's form changes. Keyed on the egg flag too:
    /// the species is already set while the egg is intact, so hatching would
    /// otherwise not look like a change and the sprite would stay unloaded.
    private func refreshSprite() {
        let key = Int32(pet.speciesId) << 2 | (pet.shiny ? 2 : 0) | (pet.isEgg ? 1 : 0)
        guard key != spriteKey else { return }
        spriteKey = key
        sprite = pet.isEgg ? nil : TPSprite.load(dex: pet.speciesId, shiny: pet.shiny)
    }

    /// Loads (and later drops) the previous form's sprite for the evolution
    /// flash. Freed once the animation is over: it is only needed while both
    /// forms are on screen.
    private func refreshEvoSprite() {
        guard pet.evolvingNow, pet.prevSpeciesId > 0 else {
            if evoSprite != nil {
                evoSprite = nil
                evoSpriteKey = .min
            }
            return
        }
        let key = Int32(pet.prevSpeciesId) << 1 | (pet.shiny ? 1 : 0)
        guard key != evoSpriteKey else { return }
        evoSpriteKey = key
        evoSprite = TPSprite.load(dex: pet.prevSpeciesId, shiny: pet.shiny)
    }

    /// Called on the display tick. Advances animation timers and, once a minute,
    /// the game tick — same contract as `pet.update(millis())` in `loop()`.
    func tick() {
        pet.update()
        refreshSprite()
        refreshEvoSprite()
        advanceBehaviour(now: millis)
        stepGames(now: millis)
        frame &+= 1
    }

    // MARK: - Minigames

    func startBallGame() {
        ball.start()
        activeGame = .ball
        lastGameMs = millis
    }

    func startSack() {
        sack.start(now: millis)
        activeGame = .sack
        lastGameMs = millis
    }

    /// Clears the deadlines as well as stopping the clock, so a later run cannot
    /// inherit a finished one's state.
    func endGames() {
        activeGame = .none
        ball.overUntil = 0
        sack.until = 0
        sack.overUntil = 0
    }

    /// True when the tap connected, so the caller can fire haptics.
    func tapBall(_ p: CGPoint) -> Bool { ball.tap(p, now: millis) }

    func tapSack() { sack.tap(now: millis) }

    private func stepGames(now: UInt64) {
        let dt = now &- lastGameMs
        lastGameMs = now

        switch activeGame {
        case .ball:
            guard ball.overUntil == 0 else { return }
            ball.step(dtMs: dt, now: now) { score in
                let beatIt = score > self.pet.gameHigh
                self.pet.playResult(UInt8(min(score, 255)))
                // Upstream stings a record differently from an ordinary finish.
                self.playSfx(beatIt && score > 0 ? .medal : .level)
                return beatIt
            }
        case .sack:
            // When the 10s runs out, bank the hits as strength exactly once.
            if sack.overUntil == 0, now >= sack.until {
                sack.newHigh = sack.hits > pet.strengthHigh
                sack.gain = pet.trainStrength(sack.hits)
                sack.overUntil = now + 3500
                playSfx(sack.newHigh ? .medal : .play)
            }
            sack.shake *= 0.84
        case .none:
            break
        }
    }

    /// Port of `drawPetPMD`'s action choice: mood wins, otherwise the scheduler
    /// below decides between standing, strolling and a one-shot gesture.
    private func advanceBehaviour(now: UInt64) {
        guard let sprite else {
            pose = PetPose()
            return
        }
        let dtMs = now &- lastPoseMs
        lastPoseMs = now

        var act = TPAct.idle
        var loop = true

        switch pet.mood {
        case .sleeping where sprite.has(.sleep):
            act = .sleep
            behMode = 0
        case .eating where sprite.has(.eat):
            act = .eat
            behT0 = 0        // upstream free-runs the eat cycle off millis()
        case .sad where sprite.has(.hurt):
            act = .hurt
        default:
            if now > behUntil { behNext(now: now, sprite: sprite) }
            if behMode == 1 {
                let d = behTargetX - behX
                if abs(d) < 4 {
                    behNext(now: now, sprite: sprite)
                    act = .idle
                } else {
                    // Upstream moves 3px per render and renders every 100ms.
                    // Expressed as a rate so this port's 15fps tick walks at the
                    // same speed rather than 1.5x it; the clamp keeps a long
                    // stall (backgrounded, then foregrounded) from teleporting it.
                    let step = min(CGFloat(dtMs), 100) * 0.03
                    behX += d > 0 ? step : -step
                    act = d > 0 ? .walkR : .walkL
                }
            } else {
                act = behMode == 2 ? behAct : .idle
                loop = false
            }
            if !sprite.has(act) { act = .idle }
        }

        pose = PetPose(act: act, x: behX,
                       elapsedMs: now &- behT0,
                       loop: loop || act == .idle)
    }

    /// Port of upstream `behNext`: 35% stroll, 25% a gesture, else stand still.
    /// Hop and Sit are deliberately excluded from the gesture pool upstream —
    /// one jumps out of frame, the other turns its back.
    private func behNext(now: UInt64, sprite: TPSprite) {
        behT0 = now
        let r = Int.random(in: 0..<100)

        if r < 35, sprite.has(.walkL) || sprite.has(.walkR) {
            behMode = 1
            behTargetX = CGFloat(Int.random(in: 150..<326))
            behUntil = now + 15000
            return
        }
        if r < 60 {
            let flair = [TPAct.pose, .nod, .breath].filter { sprite.has($0) }
            if let pick = flair.randomElement() {
                behMode = 2
                behAct = pick
                behUntil = now + UInt64(sprite[pick]?.totalMs ?? 100)
                return
            }
        }
        behMode = 0
        behUntil = now + UInt64(Int.random(in: 2000..<5000))
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            #if os(iOS)
            // Covers dropping a save in while the app sat in the background.
            applyPendingImport()
            #endif
            // Re-applies wall-clock drift. This is the offline-progression path
            // the firmware runs off its RTC, and why backgrounding is harmless.
            pet.syncClock()
        case .inactive, .background:
            pet.flushSave()
            #if os(iOS)
            TPSaveFile.writeExport()
            #endif
        @unknown default:
            break
        }
    }

    #if os(iOS)
    /// Loads a save the user dropped into the Files folder, if there is one.
    private func applyPendingImport() {
        do {
            guard try TPSaveFile.consumeImport() else { return }
            // The live C++ Pet caches its own copy of everything, so rewriting
            // the store underneath it is not enough on its own.
            pet.reload()
            spriteKey = .min      // force the sprite to follow the new species
            refreshSprite()
            importedSave = true
        } catch {
            // A malformed file must not take the app down or wipe the creature:
            // TPSaveFile validates before it touches anything.
            NSLog("iTamaPoke: save import failed — \(error)")
        }
    }
    #endif

    /// Upstream's sound switch, driving both the tones and the haptic. Kept
    /// under the old key so an existing save's preference carries over.
    private(set) var soundEnabled = UserDefaults.standard.object(forKey: "tamapoke/haptics") as? Bool ?? true

    func setSound(_ on: Bool) {
        soundEnabled = on
        UserDefaults.standard.set(on, forKey: "tamapoke/haptics")
        if on {
            TPAudio.shared.start()
            TPAudio.shared.play(TPSfx.tap.rawValue)   // confirm when switching on
            Self.playFeedback()
        } else {
            TPAudio.shared.stop()
        }
    }

    private static func playFeedback() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #elseif os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
