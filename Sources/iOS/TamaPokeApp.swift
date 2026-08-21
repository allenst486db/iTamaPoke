import SwiftUI

@main
struct TamaPokeApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            PetScreen()
                // The firmware's panel is a fixed 466x466 square; letterboxing it
                // on black is closer to the device than stretching would be.
                .background(Color.black)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
        .onChange(of: scenePhase) { _, phase in
            // Whatever the user has dropped into Documents/mons (Files app)
            // since last time gets a chance to reach the watch here, rather
            // than needing its own settings button -- see
            // Sources/Shared/TPWatchSpriteSync.swift for why this exists and
            // why it's cheap to call on every foreground.
            if phase == .active { TPWatchSpriteSync.shared.syncToWatch() }
        }
    }
}
