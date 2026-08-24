//
// The Pokedex detail view's second page shows a species' dex entry. That text
// is Nintendo / Game Freak's writing, so -- exactly like the sprites and the
// app icon -- it is NOT committed to this repository. It is read at runtime
// from `mons/dex_entries.txt`, resolved through TPMonsSource: Documents/mons
// first (drop a file in via Files -> On My iPhone -> iTamaPoke), then the app
// bundle. With no such file the page simply says so; nothing else changes.
//
// Format: one entry per line, `<dex number>|<text>`. Blank lines and lines
// starting with `#` are ignored, so a generated file can carry a header.
//
//     122|It uses its hands to create invisible walls.
//
// See README "Pokedex entries".
//

import Foundation

final class TPDexEntryText {

    static let shared = TPDexEntryText()

    /// Parsed on first use and kept: the file is small and never changes
    /// while the app is running.
    private lazy var entries: [Int16: String] = Self.load()

    private init() {}

    /// The entry for `dex`, or nil when no file is installed or it has no
    /// line for that species.
    func entry(dex: Int16) -> String? {
        guard let text = entries[dex], !text.isEmpty else { return nil }
        return text
    }

    /// Shown in place of an entry when none is installed. Deliberately plain:
    /// this is the normal state for a fresh checkout, not an error.
    let missingText = "NO DEX ENTRY"

    private static func load() -> [Int16: String] {
        guard let url = TPMonsSource.url(name: "dex_entries", ext: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8)
        else { return [:] }

        var out: [Int16: String] = [:]
        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard let sep = trimmed.firstIndex(of: "|") else { continue }
            guard let dex = Int16(trimmed[trimmed.startIndex..<sep].trimmingCharacters(in: .whitespaces))
            else { continue }
            let text = trimmed[trimmed.index(after: sep)...].trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { out[dex] = text }
        }
        return out
    }

    /// Greedy word wrap to `columns` characters. The renderer draws with a
    /// monospaced face, so a character count is an exact width budget; a word
    /// longer than the whole line is hard-split rather than allowed to
    /// overflow the panel.
    static func wrap(_ text: String, columns: Int) -> [String] {
        guard columns > 0 else { return [text] }
        var lines: [String] = []
        var line = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: true) {
            var word = String(word)
            while word.count > columns {
                if !line.isEmpty { lines.append(line); line = "" }
                lines.append(String(word.prefix(columns)))
                word = String(word.dropFirst(columns))
            }
            if line.isEmpty {
                line = word
            } else if line.count + 1 + word.count <= columns {
                line += " " + word
            } else {
                lines.append(line)
                line = word
            }
        }
        if !line.isEmpty { lines.append(line) }
        return lines
    }
}
