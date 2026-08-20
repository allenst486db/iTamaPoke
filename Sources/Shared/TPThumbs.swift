//
// Reader for the Pokedex thumbnail atlas, translated from TamaPoke by
// Quique Tortosa, MIT licensed: https://github.com/socquique/TamaPoke
// (sdmon.cpp `SdThumbs`, and `drawThumb` in TamaPoke.ino). See LICENSE.
//

import CoreGraphics
import Foundation

/// The gallery's `thumbs.bin`: one small still per species, all in one file.
///
/// Separate from `TPSprite` because the two formats are unrelated — a thumb has
/// no actions or frames, and the whole atlas stays resident, where sprites are
/// loaded one species at a time. The grid draws 16 of these at once, so paging
/// through by loading 16 TPK2 files would be far heavier than this.
final class TPThumbs {

    /// Loaded once and shared: the atlas is a couple of hundred KB and every
    /// gallery page needs it.
    static let shared = TPThumbs()

    private let bytes: [UInt8]?
    private let count: Int
    private var cache: [Int: CGImage] = [:]

    var isLoaded: Bool { bytes != nil }

    private init() {
        guard let url = Bundle.main.url(forResource: "thumbs", withExtension: "bin",
                                        subdirectory: "mons"),
              let data = try? Data(contentsOf: url)
        else {
            bytes = nil
            count = 0
            return
        }
        let b = [UInt8](data)
        // "TPTH", u16 count, then a u32 offset per species.
        guard b.count > 6, b[0] == 0x54, b[1] == 0x50, b[2] == 0x54, b[3] == 0x48 else {
            bytes = nil
            count = 0
            return
        }
        let n = Int(b[4]) | Int(b[5]) << 8
        guard 6 + n * 4 <= b.count else {
            bytes = nil
            count = 0
            return
        }
        bytes = b
        count = n
    }

    /// Pixel size of a species' thumb, needed to centre it in its cell before
    /// the image itself is built.
    func size(dex: Int16) -> (w: Int, h: Int)? {
        guard let b = bytes, let off = offset(dex: dex), off + 3 <= b.count else { return nil }
        return (Int(b[off]), Int(b[off + 1]))
    }

    /// One thumbnail. `silhouette` paints every opaque pixel ink-black, which is
    /// how upstream shows a species you have not registered yet.
    func image(dex: Int16, silhouette: Bool) -> CGImage? {
        let key = Int(dex) << 1 | (silhouette ? 1 : 0)
        if let cached = cache[key] { return cached }

        guard let b = bytes, let off = offset(dex: dex), off + 3 <= b.count else { return nil }
        let w = Int(b[off]), h = Int(b[off + 1]), palCount = Int(b[off + 2])
        guard w > 0, h > 0, palCount > 0 else { return nil }

        let palStart = off + 3
        let dataStart = palStart + palCount * 2
        guard dataStart + w * h <= b.count else { return nil }

        var px = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) {
            let idx = Int(b[dataStart + i])
            guard idx != 0xFF, idx < palCount else { continue }  // 0xFF transparent
            let c: UInt16 = silhouette
                ? 0x18C4                                          // upstream's INK_K
                : UInt16(b[palStart + idx * 2]) | UInt16(b[palStart + idx * 2 + 1]) << 8
            px[i * 4 + 0] = UInt8(((c >> 11) & 0x1F) * 255 / 31)
            px[i * 4 + 1] = UInt8(((c >> 5) & 0x3F) * 255 / 63)
            px[i * 4 + 2] = UInt8((c & 0x1F) * 255 / 31)
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

    private func offset(dex: Int16) -> Int? {
        guard let b = bytes, dex >= 1, Int(dex) <= count else { return nil }
        let i = 6 + 4 * (Int(dex) - 1)
        return Int(b[i]) | Int(b[i + 1]) << 8 | Int(b[i + 2]) << 16 | Int(b[i + 3]) << 24
    }
}
