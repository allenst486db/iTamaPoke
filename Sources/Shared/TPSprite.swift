//
// Reader for the firmware's TPK2 sprite files, translated from TamaPoke by
// Quique Tortosa, MIT licensed: https://github.com/socquique/TamaPoke
// (sdmon.h / sdmon.cpp `PmdMon::load`, and `pmdFrameAt` in TamaPoke.ino).
// See LICENSE.
//

import CoreGraphics
import Foundation

/// Action ids in upstream's `PMD_*` order (sdmon.h). The file stores an id per
/// action, so this order is part of the format, not a local convention.
enum TPAct: Int, CaseIterable {
    case idle = 0, walkL, walkR, sleep, eat, hurt, attack, pose, hop, nod, breath, sit
}

/// One action's frames, as a window into the sprite's blob.
struct TPSpriteAction {
    let w: Int
    let h: Int
    let frames: Int
    /// Row of the lowest non-transparent pixel, plus one. Actions are padded
    /// differently (Hurt and Attack use a taller canvas), so anchoring by this
    /// rather than by `h` is what keeps the creature's feet on one ground line.
    let base: Int
    /// Per-frame duration in ms.
    let ms: [Int]
    /// Byte offset of frame 0 within the blob.
    let offset: Int

    /// Upstream's `pmdActTotalMs`, including its floor: a zero total would make
    /// the frame walk below divide by nothing.
    var totalMs: Int {
        let t = ms.reduce(0, +)
        return t > 0 ? t : 100
    }
}

/// A single species' animated sprite, held as the raw TPK2 blob plus a decoded
/// palette. Frames are turned into `CGImage`s lazily and cached.
///
/// One instance is resident at a time (the current species). The firmware kept
/// the same discipline for the opposite reason -- it had 8 MB of PSRAM.
final class TPSprite {

    private let blob: [UInt8]
    /// Palette pre-expanded to RGBA8: 4 bytes per entry.
    private let palette: [UInt8]
    private let palCount: Int
    private let actions: [TPSpriteAction?]
    private var cache: [Int: CGImage] = [:]

    subscript(act: TPAct) -> TPSpriteAction? { actions[act.rawValue] }

    func has(_ act: TPAct) -> Bool { (self[act]?.frames ?? 0) > 0 }

    // MARK: - Loading

    /// Loads `mons/p<dex>.bin` from the app bundle, or `mons/ps<dex>.bin` when
    /// shiny — falling back to the normal sprite if no shiny file is bundled,
    /// exactly as `PmdMon::load` falls back on the SD card.
    ///
    /// Returns nil when the file is absent, which is the normal state: sprites
    /// are never committed to this repo, so a CI build has none. See README.
    static func load(dex: Int16, shiny: Bool) -> TPSprite? {
        guard dex > 0 else { return nil }
        var names: [String] = []
        if shiny { names.append(String(format: "ps%03d", dex)) }
        names.append(String(format: "p%03d", dex))

        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "bin",
                                            subdirectory: "mons"),
                  let data = try? Data(contentsOf: url),
                  let sprite = TPSprite(data: data)
            else { continue }
            return sprite
        }
        return nil
    }

    /// Parses the TPK2 layout:
    ///
    ///     "TPK2" | nActs:u8 | palCount:u16 | pal[palCount]:u16 (RGB565)
    ///     per action: id:u8 w:u8 h:u8 frames:u8 | ms[frames]:u16 | w*h*frames bytes
    ///
    /// Pixels are palette indices; 0xFF is transparent.
    init?(data: Data) {
        let b = [UInt8](data)
        guard b.count >= 7, b[0] == 0x54, b[1] == 0x50, b[2] == 0x4B, b[3] == 0x32 else {
            return nil  // not "TPK2"
        }
        let nActs = Int(b[4])
        let pc = Int(b[5]) | Int(b[6]) << 8
        guard pc > 0, pc <= 256, 7 + pc * 2 <= b.count else { return nil }

        var pal = [UInt8](repeating: 0, count: pc * 4)
        for i in 0..<pc {
            let c = UInt16(b[7 + i * 2]) | UInt16(b[8 + i * 2]) << 8
            pal[i * 4 + 0] = UInt8(((c >> 11) & 0x1F) * 255 / 31)
            pal[i * 4 + 1] = UInt8(((c >> 5) & 0x3F) * 255 / 63)
            pal[i * 4 + 2] = UInt8((c & 0x1F) * 255 / 31)
            pal[i * 4 + 3] = 255
        }

        var acts = [TPSpriteAction?](repeating: nil, count: TPAct.allCases.count)
        var p = 7 + pc * 2
        for _ in 0..<nActs {
            guard p + 4 <= b.count else { break }
            let id = Int(b[p]), w = Int(b[p + 1]), h = Int(b[p + 2]), nf = Int(b[p + 3])
            p += 4
            // Same bounds upstream enforces: anything else means a truncated or
            // foreign file, and a partial sprite is worse than no sprite.
            guard id < acts.count, w > 0, h > 0, nf > 0, nf <= 24,
                  p + nf * 2 + w * h * nf <= b.count
            else { return nil }

            var ms = [Int]()
            ms.reserveCapacity(nf)
            for k in 0..<nf { ms.append(Int(b[p + k * 2]) | Int(b[p + k * 2 + 1]) << 8) }
            p += nf * 2

            let offset = p
            p += w * h * nf

            // Lowest row carrying a pixel in any frame.
            var base = 1
            for f in 0..<nf {
                let fr = offset + f * w * h
                for r in stride(from: h - 1, through: 0, by: -1) {
                    if (0..<w).contains(where: { b[fr + r * w + $0] != 0xFF }) {
                        base = max(base, r + 1)
                        break
                    }
                }
            }
            acts[id] = TPSpriteAction(w: w, h: h, frames: nf, base: base, ms: ms, offset: offset)
        }

        guard acts.contains(where: { $0 != nil }) else { return nil }
        self.blob = b
        self.palette = pal
        self.palCount = pc
        self.actions = acts
    }

    // MARK: - Frames

    /// Upstream's `pmdFrameAt`, with one addition: the walk is bounded. Upstream
    /// spins forever if every duration in `ms[]` is zero, which a hand-made file
    /// can produce; here that yields frame 0 instead of hanging the UI.
    static func frameIndex(_ a: TPSpriteAction, elapsedMs: UInt64, loop: Bool) -> Int {
        let total = a.totalMs
        if !loop && elapsedMs >= UInt64(total) { return a.frames - 1 }
        var t = Int(elapsedMs % UInt64(total))
        var i = 0
        var steps = 0
        while t >= a.ms[i] {
            t -= a.ms[i]
            i = (i + 1) % a.frames
            steps += 1
            if steps > a.frames { return 0 }
        }
        return i
    }

    /// One frame as an image. Built once per (action, frame) and cached: the
    /// firmware could afford a `fillRect` per pixel, but a SwiftUI `Canvas`
    /// cannot — a 32x32 frame would be up to 1024 path fills every tick.
    func image(_ act: TPAct, frame: Int) -> CGImage? {
        guard let a = self[act], frame >= 0, frame < a.frames else { return nil }
        let key = act.rawValue << 8 | frame
        if let cached = cache[key] { return cached }

        let w = a.w, h = a.h
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let src = a.offset + frame * w * h
        for i in 0..<(w * h) {
            let idx = Int(blob[src + i])
            guard idx != 0xFF, idx < palCount else { continue }  // 0xFF = transparent
            px[i * 4 + 0] = palette[idx * 4 + 0]
            px[i * 4 + 1] = palette[idx * 4 + 1]
            px[i * 4 + 2] = palette[idx * 4 + 2]
            px[i * 4 + 3] = 255
        }

        guard let provider = CGDataProvider(data: Data(px) as CFData) else { return nil }
        let img = CGImage(width: w, height: h,
                          bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                          provider: provider, decode: nil,
                          shouldInterpolate: false, intent: .defaultIntent)
        cache[key] = img
        return img
    }

    /// Whole-pixel zoom, from upstream `drawPmdActM`: sized off the idle action
    /// so every action of one species draws at the same scale, then shrunk for
    /// the oversized frames (Attack, Hop).
    func scale(for a: TPSpriteAction, max maxS: Int = 5) -> Int {
        let idleH = self[.idle]?.h ?? 0
        var s = idleH > 0 ? 170 / idleH : maxS
        s = min(max(s, 2), maxS)
        while s > 2 && a.h * s > 250 { s -= 1 }
        return s
    }
}
