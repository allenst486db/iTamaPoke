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

    private var started = false
    private let epoch = Date()

    /// Milliseconds since launch, for the Swift-side scene animations
    /// (clouds, waves, snow) that upstream phases off `millis()`.
    var millis: UInt64 { UInt64(Date().timeIntervalSince(epoch) * 1000) }

    func start() {
        guard !started else { return }
        started = true
        pet.begin()
        refreshSprite()
        // The ES8311 tone synth is not ported. Haptics are the closest native
        // equivalent and keep taps feeling answered; real audio is a later step.
        TPSetSfxHandler { _ in Self.playFeedback() }
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

    /// Called on the display tick. Advances animation timers and, once a minute,
    /// the game tick — same contract as `pet.update(millis())` in `loop()`.
    func tick() {
        pet.update()
        refreshSprite()
        frame &+= 1
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // Re-applies wall-clock drift. This is the offline-progression path
            // the firmware runs off its RTC, and why backgrounding is harmless.
            pet.syncClock()
        case .inactive, .background:
            pet.flushSave()
        @unknown default:
            break
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
