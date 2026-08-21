//
// Resolves where a `mons/` file (a sprite or the thumb atlas) actually comes
// from at runtime, mirroring the firmware's own SD card: `PmdMon::load` reads
// whatever is on the card, not something baked into the firmware image.
//
// A build made without Scripts/fetch_sprites.sh (every CI build, and any
// sideloaded .ipa) ships this app's Documents folder empty and its bundle
// empty too. Documents/mons is what Files -> On My iPhone -> iTamaPoke
// exposes, so a user who drops sprite files there this way gets them without
// ever touching Xcode. A local build that DID run fetch_sprites.sh still
// works exactly as before: nothing is in Documents, so this falls through to
// the bundle every time, silently.
//

import Foundation

enum TPMonsSource {

    /// `Documents/mons/`, creating it on first use so a user opening Files
    /// before ever launching the app still finds a folder to drop files into
    /// rather than having to create one themselves.
    static var documentsMons: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = docs.appendingPathComponent("mons", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// `Documents/mons/<name>.<ext>` if the user has put one there, else the
    /// same file in the app bundle's `mons/` -- the same fallback order as
    /// upstream's own "SD card present?" check, just phrased for iOS.
    static func url(name: String, ext: String) -> URL? {
        if let dir = documentsMons {
            let candidate = dir.appendingPathComponent(name).appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "mons")
    }

    /// Every `.bin` currently sitting in Documents/mons, for the watch-sync
    /// picker (Settings) to enumerate. Bundle-only sprites are not listed
    /// here -- they are already inside the .ipa the watch app installed from,
    /// so there is nothing to sync for them.
    static var documentsMonFiles: [URL] {
        guard let dir = documentsMons,
              let items = try? FileManager.default.contentsOfDirectory(
                  at: dir, includingPropertiesForKeys: [.fileSizeKey])
        else { return [] }
        return items.filter { $0.pathExtension.lowercased() == "bin" }
    }
}
