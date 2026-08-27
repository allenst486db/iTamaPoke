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
import CoreGraphics

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

    /// Greedy wrap to `maxWidth`, measured by `width` rather than assumed from
    /// a character count -- the old `columns: Int` budget relied on the
    /// renderer's font advancing a fixed px/character, which is only true for
    /// the monospaced system font's Latin glyphs. Korean has no glyphs in
    /// that font at all (falls back to non-monospaced Apple SD Gothic Neo,
    /// ~1.44x wider per character -- see kor_patch/FEASIBILITY.ko.md), so
    /// wrapping it needs the same real-width measurement `gfxTextWidth` uses
    /// for alignment.
    ///
    /// `byCharacter` switches from word wrapping (space-delimited languages)
    /// to wrapping one character at a time, which is how Korean text is
    /// actually set: dex entries run long stretches with no spaces, so word
    /// wrapping barely wraps at all and the mid-word hard-split fallback
    /// below fires on nearly every line instead of being the rare case it is
    /// for the other languages.
    static func wrap(_ text: String, maxWidth: CGFloat, byCharacter: Bool = false,
                     width: (String) -> CGFloat) -> [String] {
        guard maxWidth > 0 else { return [text] }
        let units: [String] = byCharacter
            ? text.map { String($0) }
            : text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let sep = byCharacter ? "" : " "

        var lines: [String] = []
        var line = ""
        for unit in units {
            let candidate = line.isEmpty ? unit : line + sep + unit
            if width(candidate) <= maxWidth {
                line = candidate
                continue
            }
            if !line.isEmpty { lines.append(line); line = "" }
            if width(unit) <= maxWidth {
                line = unit
                continue
            }
            // A single unit alone is wider than the line (a long word in a
            // narrow box, or -- in character mode -- shouldn't happen since a
            // lone glyph always fits, but stays defensive): hard-split it
            // character by character rather than let it overflow the panel.
            var chunk = ""
            for ch in unit {
                let next = chunk + String(ch)
                if width(next) > maxWidth, !chunk.isEmpty {
                    lines.append(chunk)
                    chunk = String(ch)
                } else {
                    chunk = next
                }
            }
            line = chunk
        }
        if !line.isEmpty { lines.append(line) }
        return lines
    }
}
