//
// Hand-drawn pixel icons and their palette, translated from TamaPoke by
// Quique Tortosa, MIT licensed: https://github.com/socquique/TamaPoke
// (species.h's SPR_ICON_*/SPR_HEART/SPR_POOP glyph maps, and TamaPoke.ino's
// `drawMap`). See LICENSE.
//
// Not species art or Pokémon likenesses -- these are the firmware's own UI
// glyphs (berries, a candy, a heart, a poop), MIT-licensed like the rest of
// the engine. Unlike upstream/tools/sdcard/mons/, nothing here needs fetching
// or is gitignored.
//

import SwiftUI

/// `species.h`'s `spriteColor`: one character per palette entry, shared by every
/// hand-drawn icon below. Distinct from `TPSprite`'s palette, which is per-file
/// and already RGB565-encoded in the TPK2 data itself.
enum TPIconPalette {
    static func color(_ ch: Character) -> UInt16? {
        switch ch {
        case "k": return 0x18C4
        case "w": return 0xFFFF
        case "y": return 0xFED2
        case "Y": return 0xE5CC
        case "o": return 0xF427
        case "O": return 0xD2E5
        case "r": return 0xEA87
        case "R": return 0xB184
        case "f": return 0xFECB
        case "t": return 0x8EB6
        case "T": return 0x5D71
        case "g": return 0x5DCD
        case "G": return 0x3C49
        case "d": return 0x3BEC
        case "p": return 0xF454
        case "P": return 0xC2F0
        case "b": return 0x7E3D
        case "B": return 0x4C98
        case "N": return 0x3B74
        case "M": return 0x2A8F
        case "c": return 0xB3C8
        case "C": return 0x7AA6
        case "l": return 0x9D5C
        case "L": return 0x6BF7
        case "s": return 0xAD97
        case "S": return 0x7BF1
        default: return nil
        }
    }
}

/// A hand-drawn icon: n rows of an n-character string, one character per pixel,
/// "." transparent. Row/column order and every glyph match `species.h` exactly.
enum TPIcon {
    static let food: [String] = [
        "................",
        "................",
        "...........k....",
        "........k.kk....",
        "........k.......",
        ".......krk......",
        ".....kkrrrkk....",
        "....krwrrrrrk...",
        "....kwrrrrrrk...",
        "...krrrrrrrrRk..",
        "...krrrrrrrrRk..",
        "....krrrrrrrk...",
        "....krrrrrrRk...",
        ".....kkRRRkk....",
        ".......kkk......",
        "................",
    ]

    static let berryBlue: [String] = [
        "................",
        "................",
        "...........k....",
        "........k.k.....",
        "........k.......",
        ".......kbk......",
        ".....kkbbbkk....",
        "....kbwbbbbbk...",
        "....kwbbbbbbk...",
        "...kbbbbbbbbBk..",
        "...kbbbbbbbbBk..",
        "....kbbbbbbbk...",
        "....kbbbbbbBk...",
        ".....kkBBBkk....",
        ".......kkk......",
        "................",
    ]

    static let berryGreen: [String] = [
        "................",
        "................",
        "...........k....",
        "........k.k.....",
        "........k.......",
        ".......kgk......",
        ".....kkgggkk....",
        "....kgwgggggk...",
        "....kwggggggk...",
        "...kggggggggGk..",
        "...kggggggggGk..",
        "....kgggggggk...",
        "....kggggggGk...",
        ".....kkGGGkk....",
        ".......kkk......",
        "................",
    ]

    static let candy: [String] = [
        "................",
        "................",
        "................",
        "................",
        "................",
        "......kkkkk.....",
        "..k..kpwpppk.k..",
        "...kkpwpppppk...",
        "..kpppppPppPpk..",
        "...kkppppPpPk...",
        "..k..kppppPk.k..",
        "......kkkkk.....",
        "................",
        "................",
        "................",
        "................",
    ]

    static let poop: [String] = [
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................k...............",
        ".................k..............",
        "...............kkk..............",
        "..............kccck.............",
        ".............kccccck............",
        "..............kccck.............",
        "..............kCCCk.............",
        "............kkccccckk...........",
        "............kccccccck...........",
        "...........kccccccccCk..........",
        "............kccccccck...........",
        "............kcccccCCk...........",
        "...........kccCCCCCcck..........",
        "..........kccccccccccck.........",
        "..........kccccccccccCk.........",
        ".........kcccccccccccCCk........",
        "..........kccccccccccCk.........",
        "..........kcccccccccCCk.........",
        "...........kkkcCCCCkkk..........",
        "..............kkkkk.............",
        "................................",
        "................................",
        "................................",
    ]

    static let heart: [String] = [
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "........krrrrk....krrrrk........",
        ".......krrrrrrk..krrrrrrk.......",
        "......krrrrrrrrrrrrrrrrrrk......",
        ".....krrrrrrrrrrrrrrrrrrrrk.....",
        ".....krrwwrrrrrrrrrrrrrrRrk.....",
        ".....krwwrrrrrrrrrrrrrrRRrk.....",
        "......krrrrrrrrrrrrrrrrrrk......",
        ".......krrrrrrrrrrrrrrrrk.......",
        "........krrrrrrrrrrrrrrk........",
        ".........krrrrrrrrrrrrk.........",
        "..........krrrrrrrrrrk..........",
        "...........krrrrrrrrk...........",
        "............krrrrrrk............",
        ".............krrrrk.............",
        "..............krrk..............",
        "...............kk...............",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
    ]
}

extension GraphicsContext {
    /// Port of upstream's `drawMap`: one `fillRect` per non-transparent pixel,
    /// scaled by whole pixels, `(x, y)` at the top-left corner. `silhouette`
    /// paints every pixel ink-black -- upstream's evolution-flash effect reuses
    /// the same function this way.
    func drawIcon(_ map: [String], _ x: CGFloat, _ y: CGFloat, scale: CGFloat,
                  silhouette: Bool = false) {
        for (r, row) in map.enumerated() {
            for (c, ch) in row.enumerated() where ch != "." {
                guard let color = silhouette ? UI.ink : TPIconPalette.color(ch) else { continue }
                fillRect(x + CGFloat(c) * scale, y + CGFloat(r) * scale, scale, scale, color)
            }
        }
    }
}
