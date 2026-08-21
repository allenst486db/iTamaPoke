import SwiftUI

@main
struct TamaPokeWatchApp: App {
    // Touching .shared activates the WCSession that receives sprite files
    // from the phone -- see Sources/Shared/TPWatchSpriteSync.swift.
    private let spriteSync = TPWatchSpriteSync.shared

    var body: some Scene {
        WindowGroup {
            PetScreen()
                .background(Color.black)
        }
    }
}
