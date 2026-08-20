//
// Save export/import through the iPhone Files app.
//
// Original to this port -- the firmware moves saves over USB with its own PUT
// protocol (tools/send_sd.py), which has no equivalent here.
//

import Foundation

/// Reads and writes the creature's state as a JSON document in the app's
/// Documents folder, which `UIFileSharingEnabled` publishes to Files.
///
/// The payload is the whole `tamapoke/` `UserDefaults` namespace rather than a
/// hand-listed set of fields. `Pet::save` writes ~35 keys and gains more as
/// upstream grows; enumerating them here would silently drop whichever ones a
/// submodule bump added, and a save that loses your Pokédex without erroring is
/// worse than one that fails loudly.
enum TPSaveFile {

    /// Written after every save, so the copy in Files is always current.
    static let exportName = "iTamaPoke-save.json"
    /// Drop a file under this name into the folder to load it on next launch.
    static let importName = "iTamaPoke-import.json"

    private static let prefix = "tamapoke/"
    private static let format = "itamapoke.save"
    private static let version = 1

    // MARK: - Locations

    static var documentsURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // MARK: - Encoding

    /// Values come back from `UserDefaults` as `NSNumber`, `String` or `NSData`.
    /// Each is tagged so the type survives the round trip: `Preferences::getBool`
    /// and `getUChar` both call through `NSNumber`, so an untagged number would
    /// still load, but data blobs (`dexreg`, `dexsh` — the Pokédex bitmaps) would
    /// not survive JSON without base64.
    static func encode() -> Data? {
        let store = UserDefaults.standard.dictionaryRepresentation()
        var values: [String: [String: Any]] = [:]

        for (key, value) in store where key.hasPrefix(prefix) {
            let short = String(key.dropFirst(prefix.count))
            if let data = value as? Data {
                values[short] = ["t": "d", "v": data.base64EncodedString()]
            } else if let string = value as? String {
                values[short] = ["t": "s", "v": string]
            } else if let number = value as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    values[short] = ["t": "b", "v": number.boolValue]
                } else {
                    values[short] = ["t": "i", "v": number.int64Value]
                }
            }
        }
        guard !values.isEmpty else { return nil }

        let doc: [String: Any] = [
            "format": format,
            "version": version,
            "exported": ISO8601DateFormatter().string(from: Date()),
            "values": values,
        ]
        return try? JSONSerialization.data(withJSONObject: doc,
                                           options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Decoding

    enum ImportError: Error, CustomStringConvertible {
        case unreadable
        case notASave
        case futureVersion(Int)
        case empty

        var description: String {
            switch self {
            case .unreadable:            return "file is not valid JSON"
            case .notASave:              return "not an iTamaPoke save file"
            case .futureVersion(let v):  return "save version \(v) is newer than this app understands"
            case .empty:                 return "save file contains no values"
            }
        }
    }

    /// Validates and applies a save document. Writes straight into the same
    /// `UserDefaults` keys the C++ `Preferences` shim reads; the caller must ask
    /// `TPPet` to reload afterwards, since the live Pet holds its own copy.
    static func apply(_ data: Data) throws {
        guard let doc = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw ImportError.unreadable
        }
        guard doc["format"] as? String == format else { throw ImportError.notASave }
        let v = doc["version"] as? Int ?? 0
        guard v <= version else { throw ImportError.futureVersion(v) }
        guard let values = doc["values"] as? [String: [String: Any]], !values.isEmpty else {
            throw ImportError.empty
        }

        let defaults = UserDefaults.standard
        // Clear the namespace first: a save from an earlier pet may legitimately
        // lack keys this device has, and leaving those behind would blend two
        // creatures together rather than replacing one.
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }

        for (short, entry) in values {
            let key = prefix + short
            switch entry["t"] as? String {
            case "d":
                if let s = entry["v"] as? String, let d = Data(base64Encoded: s) {
                    defaults.set(d, forKey: key)
                }
            case "s":
                if let s = entry["v"] as? String { defaults.set(s, forKey: key) }
            case "b":
                if let b = entry["v"] as? Bool { defaults.set(b, forKey: key) }
            case "i":
                if let n = entry["v"] as? NSNumber { defaults.set(n.intValue, forKey: key) }
            default:
                break
            }
        }
    }

    // MARK: - Files folder

    /// Refreshes the exported copy. Cheap enough to call on every save.
    @discardableResult
    static func writeExport() -> Bool {
        guard let dir = documentsURL, let data = encode() else { return false }
        do {
            try data.write(to: dir.appendingPathComponent(exportName), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Loads `iTamaPoke-import.json` if the user put one there, then renames it
    /// so the next launch does not silently re-apply it. Returns true when the
    /// live state changed and the Pet needs reloading.
    ///
    /// Import is deliberately opt-in by filename: the export sitting alongside it
    /// must never be re-imported on its own, or restarting the app would roll the
    /// creature back to whenever that file was written.
    static func consumeImport() throws -> Bool {
        guard let dir = documentsURL else { return false }
        let src = dir.appendingPathComponent(importName)
        guard FileManager.default.fileExists(atPath: src.path) else { return false }

        let data = try Data(contentsOf: src)
        try apply(data)

        let stamp = Int(Date().timeIntervalSince1970)
        let done = dir.appendingPathComponent("\(importName).imported-\(stamp)")
        try? FileManager.default.moveItem(at: src, to: done)
        return true
    }

    /// A short note in the folder itself, so the flow is discoverable from Files
    /// without having to find the README in the repo.
    static func writeReadme() {
        guard let dir = documentsURL else { return }
        let text = """
        iTamaPoke save data
        ===================

        \(exportName)
            Your creature, refreshed every time the app saves. Copy it somewhere
            safe, or onto another device, to keep a backup.

        To restore a save
            Put the file back in this folder, renamed to:

                \(importName)

            then open the app. It loads on launch and is renamed afterwards, so it
            will not be applied twice. Importing REPLACES the creature currently
            on this device.

        The format is plain JSON. It holds the same values the game saves --
        stats, species, Pokedex progress, streak and medals.
        """
        try? text.write(to: dir.appendingPathComponent("README.txt"),
                        atomically: true, encoding: .utf8)
    }
}
