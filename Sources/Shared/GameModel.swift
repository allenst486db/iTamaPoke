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
        /// Vertical nudge applied on top of the frame, for motion the sprite
        /// sheet itself cannot express. Upstream does the same thing for its
        /// happy bounce (`y -= 6` in drawPetSD).
        var yOffset: CGFloat = 0
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

    /// One soap bubble, seeded when the bath starts and then swaying upward.
    struct Bubble {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var r: CGFloat = 0
        /// Phase offset so the bubbles do not sway in lockstep.
        var phase: CGFloat = 0
    }

    /// Bath state. Upstream seeds the bubbles once in `startBath` and keeps them
    /// in a file-scope array; they have to persist across frames to sway, so they
    /// belong here rather than being regenerated inside a draw.
    private(set) var bubbles = [Bubble](repeating: Bubble(), count: 14)
    private(set) var bathUntil: UInt64 = 0
    /// How long a bath runs, from upstream's `bathUntil = millis() + 3000`.
    /// Named because the renderer needs it to work out how far along it is.
    static let bathDuration: UInt64 = 3000
    /// Upstream defers `clean()` until the bath finishes, so the creature is
    /// still dirty while it is being washed. `bathPending` is what makes that
    /// fire exactly once.
    private var bathPending = false

    /// Minigames and the training sack. All live here rather than in the view
    /// because they advance on the tick, and a Canvas draw must not step physics.
    private(set) var ball = TPBallGame()
    private(set) var sack = TPSackGame()
    private(set) var catchGame = TPCatchGame()
    private(set) var memoGame = TPMemoGame()
    private(set) var cleanGame = TPCleanGame()
    private(set) var typeGame = TPTypeGame()
    /// Which one is running. Gating on the games' own fields instead would leave
    /// a finished sack's deadline pinned, and that stale value froze the ball.
    private enum ActiveGame { case none, ball, sack, catchGame, memo, clean, typeQuiz }
    private var activeGame: ActiveGame = .none
    private var lastGameMs: UInt64 = 0

    /// battleTypeEffectPct with a fixed single defender type, for the Type
    /// quiz's distractor filter (see TPTypeGame.nextQuestion).
    private let typeEffect: (UInt8, UInt8) -> Int = { atk, def in
        Int(TPBattle.typeEffectPct(atk, defender1: def, defender2: 0))
    }

    private var started = false
    private let epoch = Date()

    /// Real wall-clock resync, on a timer independent of scene-phase
    /// transitions. pet.syncClock() (and therefore every once-a-day system --
    /// daily goals, care streak, shake/walk caps -- since they all key off
    /// Pet::today(), which reads lastSeenEpoch) previously only refreshed at
    /// launch and on foreground return, so a session left open straight
    /// through the day boundary never saw it roll over: today() kept
    /// returning the same stale day number for as long as the app stayed
    /// foregrounded, no matter how many times a goal-tracked action re-ran
    /// the check. This is what made the reset look inconsistent -- it worked
    /// whenever the app happened to relaunch or come back from background
    /// after the boundary, and silently didn't otherwise.
    private var lastClockSyncMs: UInt64 = 0
    private static let clockSyncIntervalMs: UInt64 = 5 * 60 * 1000

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
        TPAudio.shared.mode = soundMode
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
        guard hapticEnabled else { return }
        if soundEnabled { TPAudio.shared.play(id) }
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
        if millis - lastClockSyncMs >= Self.clockSyncIntervalMs {
            lastClockSyncMs = millis
            pet.syncClock()
        }
        pet.update()
        refreshSprite()
        refreshEvoSprite()
        stepBath(now: millis)
        advanceBehaviour(now: millis)
        stepGames(now: millis)
        frame &+= 1
    }

    // MARK: - Bath

    /// Port of upstream `startBath`, including its guards — notably the
    /// `bathUntil` one, which stops a second tap restarting the animation.
    func startBath() {
        guard !pet.isEgg, !pet.sleeping, pet.ceremony == TPCeremony.none, bathUntil == 0 else {
            return
        }
        let now = millis
        bathUntil = now + Self.bathDuration
        bathPending = true
        let cx = behX
        for i in bubbles.indices {
            bubbles[i] = Bubble(x: cx - 70 + CGFloat(Int.random(in: 0..<140)),
                                y: TP.petGround - CGFloat(Int.random(in: 0..<150)),
                                r: CGFloat(8 + Int.random(in: 0..<16)),
                                phase: CGFloat(Int.random(in: 0..<64)))
        }
    }

    /// The tail of upstream's `drawBath`: when the timer runs out it washes the
    /// creature and sets it posing. Run on the tick because it mutates the Pet.
    private func stepBath(now: UInt64) {
        guard bathUntil != 0, now > bathUntil else { return }
        bathUntil = 0
        guard bathPending else { return }
        bathPending = false
        pet.clean()
        if let sprite, sprite.has(.pose), let pose = sprite[.pose] {
            behMode = 2
            behAct = .pose
            behT0 = now
            behUntil = now + UInt64(pose.totalMs * 2)
        }
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

    func startCatchGame() {
        catchGame.start(now: millis)
        activeGame = .catchGame
        lastGameMs = millis
    }

    func startMemoGame() {
        memoGame.start(now: millis)
        activeGame = .memo
        lastGameMs = millis
    }

    func startCleanGame() {
        cleanGame.start(now: millis)
        activeGame = .clean
        lastGameMs = millis
    }

    func startTypeGame() {
        typeGame.start(now: millis)
        typeGame.nextQuestion(now: millis, effectPct: typeEffect)
        activeGame = .typeQuiz
        lastGameMs = millis
    }

    /// Clears the deadlines as well as stopping the clock, so a later run cannot
    /// inherit a finished one's state.
    func endGames() {
        activeGame = .none
        ball.overUntil = 0
        sack.until = 0
        sack.overUntil = 0
        catchGame.overUntil = 0
        memoGame.overUntil = 0
        cleanGame.overUntil = 0
        typeGame.overUntil = 0
    }

    /// True when the tap connected, so the caller can fire haptics.
    func tapBall(_ p: CGPoint) -> Bool { ball.tap(p, now: millis) }

    func tapSack() { sack.tap(now: millis) }

    /// Unlike the ball, a miss here also counts toward game-over -- see
    /// TPCatchGame.tap.
    func tapCatch(_ p: CGPoint) -> TPCatchTapResult {
        catchGame.tap(p, now: millis) { score in
            let beatIt = score > self.pet.catchHigh
            _ = self.pet.applyCatchResult(UInt8(min(score, 255)))
            self.playSfx(beatIt && score > 0 ? .medal : .level)
            return beatIt
        }
    }

    func tapMemo(_ p: CGPoint) -> TPMemoGame.TapResult {
        memoGame.tap(p, now: millis) { rounds in self.finishMemo(rounds) }
    }

    func tapClean(_ p: CGPoint) -> TPCatchTapResult {
        cleanGame.tap(p, now: millis) { score in self.finishClean(score) }
    }

    func tapType(_ p: CGPoint) -> TPCatchTapResult {
        guard let choice = TPTypeGame.choiceAt(p) else { return .ignored }
        return typeGame.tap(choice: choice, now: millis, effectPct: typeEffect) { score in
            self.finishType(score)
        }
    }

    // Each returns (newHigh, gain) rather than writing straight to the game
    // struct's own fields -- see TPMemoGame.step's doc comment for why: the
    // struct these results belong on (self.memoGame etc.) is the very one
    // whose mutating step/tap call is still in progress when this closure
    // runs, and self.memoGame.gain = ... from in here would be a same-
    // instance exclusivity violation (a runtime crash, not just a lint).
    private func finishMemo(_ rounds: UInt16) -> (newHigh: Bool, gain: UInt8) {
        let beatIt = rounds > pet.memoHigh
        let gain = pet.applyMemoResult(UInt8(min(rounds, 255)))
        playSfx(beatIt && rounds > 0 ? .medal : .level)
        return (beatIt, gain)
    }

    private func finishClean(_ score: UInt16) -> (newHigh: Bool, gain: UInt8) {
        let beatIt = score > pet.cleanHigh
        let gain = pet.applyCleanResult(UInt8(min(score, 255)))
        playSfx(beatIt && score > 0 ? .medal : .level)
        return (beatIt, gain)
    }

    private func finishType(_ score: UInt16) -> (newHigh: Bool, gain: UInt8) {
        let beatIt = score > pet.typeHigh
        let gain = pet.applyTypeResult(UInt8(min(score, 255)))
        playSfx(beatIt && score > 0 ? .medal : .level)
        return (beatIt, gain)
    }

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
        case .catchGame:
            guard catchGame.overUntil == 0 else { return }
            catchGame.step(now: now) { score in
                let beatIt = score > self.pet.catchHigh
                _ = self.pet.applyCatchResult(UInt8(min(score, 255)))
                self.playSfx(beatIt && score > 0 ? .medal : .level)
                return beatIt
            }
        case .memo:
            memoGame.step(now: now, playPad: { pad in
                self.playSfx(TPSfx(rawValue: TPSfx.memoPad0.rawValue + UInt8(pad)) ?? .memoPad0)
            }, onGameOver: { rounds in self.finishMemo(rounds) })
        case .clean:
            cleanGame.step(now: now) { score in self.finishClean(score) }
        case .typeQuiz:
            let timedOut = typeGame.step(now: now, effectPct: typeEffect) { score in
                self.finishType(score)
            }
            if timedOut { playSfx(.minigameBad) }
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
        var yOffset: CGFloat = 0

        switch pet.mood {
        case .sleeping where sprite.has(.sleep):
            act = .sleep
            behMode = 0
        case .eating where sprite.has(.eat):
            act = .eat
            behT0 = 0        // upstream free-runs the eat cycle off millis()
        case .eating:
            // Only 28 of the 151 sprite sheets carry an Eat animation — the
            // SpriteCollab art simply does not have one for the rest, which is
            // why feeding a starter looks right and feeding its evolution looks
            // like nothing happened. Upstream falls through to the walk
            // scheduler here, so the creature may even wander off mid-meal.
            //
            // Fill the gap rather than copy it: stand still and chew. This only
            // ever runs when the sheet has no Eat frames, so a species that does
            // have them is untouched.
            act = .idle
            behMode = 0
            yOffset = (now / 170) % 2 == 0 ? -3 : 0
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
                       loop: loop || act == .idle,
                       yOffset: yOffset)
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
            // The system tears down the audio engine/session in the background
            // (neither platform declares a background-audio mode), so `stop()`
            // below leaves TPAudio's own `running` flag accurate; this is what
            // actually gets sound working again on return, not just SND being on.
            if soundEnabled { TPAudio.shared.start() }
        case .inactive, .background:
            TPAudio.shared.stop()
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

    /// Three-level sound mode (SILENT/VIBRATE/FULL) -- VIBRATE is new: sound
    /// and haptic used to be an all-or-nothing pair (whatever plays audio
    /// also buzzes), this splits them so a silenced phone can still feel
    /// responsive without making noise.
    ///
    /// Stored under its own key, "tamapoke/soundmode3", deliberately
    /// distinct from the old four-level scheme's "tamapoke/soundmode":
    /// this enum's raw values (0 SILENT, 1 VIBRATE, 2 FULL) collide with
    /// the old scheme's (0 OFF, 1 LOW, 2 MED, 3 FULL) at 1 and 2, so
    /// writing the new value into the old key made a save of FULL (2)
    /// read back on the next launch as the old scheme's MED, i.e. this
    /// enum's VIBRATE (2 falls into the `case 1, 2` migration branch
    /// below) -- FULL silently downgraded to VIBRATE on every relaunch.
    /// The old key is now read only once, as a one-time migration for a
    /// save that predates soundmode3 entirely.
    private(set) var soundMode: TPSoundMode = {
        if let v3 = UserDefaults.standard.object(forKey: "tamapoke/soundmode3") as? Int,
           let mode = TPSoundMode(rawValue: v3) {
            return mode
        }
        if let stored = UserDefaults.standard.object(forKey: "tamapoke/soundmode") as? Int {
            switch stored {
            case 0: return .silent
            case 1, 2: return .vibrate
            case 3: return .full
            default: break
            }
        }
        let legacy = UserDefaults.standard.object(forKey: "tamapoke/haptics") as? Bool ?? true
        return legacy ? .full : .silent
    }()

    var soundEnabled: Bool { soundMode == .full }
    var hapticEnabled: Bool { soundMode != .silent }

    /// The settings pill cycles FULL -> VIBRATE -> SILENT -> FULL.
    func cycleSound() {
        let next: TPSoundMode
        switch soundMode {
        case .full: next = .vibrate
        case .vibrate: next = .silent
        case .silent: next = .full
        }
        setSound(next)
    }

    func setSound(_ mode: TPSoundMode) {
        soundMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "tamapoke/soundmode3")
        TPAudio.shared.mode = mode
        if mode == .full {
            TPAudio.shared.start()
            TPAudio.shared.play(TPSfx.menu.rawValue)   // confirm at the new level
        } else {
            TPAudio.shared.stop()
        }
        if mode != .silent { Self.playFeedback() }     // vibrate confirms too, just quietly
    }

    private static func playFeedback() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #elseif os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
