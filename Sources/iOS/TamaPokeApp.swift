import SwiftUI

@main
struct TamaPokeApp: App {
    var body: some Scene {
        WindowGroup {
            PetScreen()
                // The firmware's panel is a fixed 466x466 square; letterboxing it
                // on black is closer to the device than stretching would be.
                .background(Color.black)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
