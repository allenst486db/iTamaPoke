//
// The coordinate constants, UI palette and `lerp565` / `C565` colour maths are
// translated from TamaPoke by Quique Tortosa, MIT licensed:
// https://github.com/socquique/TamaPoke (species.h, TamaPoke.ino). See LICENSE.
//

import SwiftUI

/// The firmware draws into a fixed 466x466 framebuffer.
///
/// Keeping that coordinate space verbatim is the whole trick of this port: every
/// `drawScene` / `drawBars` / `drawButtons` call site ports line-for-line, and
/// iPhone vs. Apple Watch collapses into a single scale factor. The round panel
/// becomes a square viewport here, so corners the firmware hid are simply visible.
enum TP {
    static let screen: CGFloat = 466
    static let cx: CGFloat = 233
    static let cy: CGFloat = 233
    static let petCY: CGFloat = 202   // vertical centre of the sprite
    static let petGround: CGFloat = 304  // ground line the sprite's feet sit on
    static let horizon: CGFloat = 232 // where sky meets ground
    static let btnHalf: CGFloat = 26  // buttons are 52x52

    // Decision call-to-action buttons, from the .ino's EVO_BTN_*/FAR_BTN_* defines.
    static let evoBtn = CGRect(x: cx - 128, y: 172, width: 256, height: 64)
    static let farBtn = CGRect(x: cx - 204, y: 176, width: 408, height: 58)
    // The two stacked options inside the choice dialog.
    static let choiceAction = CGRect(x: 93, y: 206, width: 280, height: 52)
    static let choiceKeep = CGRect(x: 93, y: 268, width: 280, height: 52)

    // Pokedex grid: 4x4 cells per page, from the .ino's GAL_* defines.
    // galY is 100 here, not upstream's 84: the All/Raised/Caught filter row
    // (a fork addition, drawn at y 74-92) didn't exist in the original, and
    // at 84 the tallest thumbnails ran up into it.
    static let galX: CGFloat = 73
    static let galY: CGFloat = 100
    static let galCell: CGFloat = 80

    /// "Train strength" and "wild battle" buttons on the stat card's battle
    /// page (the second ported from ShadowEnemyx/TamaPoke "Expanded" --
    /// see upstream-expanded/README.md, hence sitting above the original).
    static let wildBattleBtn = CGRect(x: 96, y: 290, width: 274, height: 36)
    /// Expedition HUD chip on the idle screen (ShadowEnemyx fork).
    static let expeditionHud = CGRect(x: 310, y: 106, width: 112, height: 34)
    // Bottom edge lands at 368, six units clear of the card's page-dot row
    // (drawn at a fixed y: 374 shared by every page -- see renderCard).
    static let trainBtn = CGRect(x: 96, y: 332, width: 274, height: 36)
    // "Let it go?" confirmation buttons.
    static let releaseYes = CGRect(x: 118, y: 252, width: 100, height: 52)
    static let releaseNo = CGRect(x: 248, y: 252, width: 100, height: 52)

    /// The stat/info card's "tap: back" hint at the bottom of every page
    /// (drawn at y 400 by renderCard) -- the only spot a tap should close
    /// the card from. It used to be the whole page below the buttons that
    /// closed on any tap, which made it too easy to lose your place on the
    /// card (e.g. mid-battle-launch) with a stray tap. Generously sized for
    /// touch (and watch) even though the label itself is short.
    static let cardBackHint = CGRect(x: 66, y: 388, width: 334, height: 32)
    /// Same idea for the Pokédex detail view's own back hint (renderGalleryDetail,
    /// drawn at y 424) -- narrowing "any tap closes this" down to just this
    /// label also means a near-miss on the cry button (drawCryButton, small
    /// and close by, worst on watch) just does nothing instead of bouncing
    /// you all the way back out to the grid.
    static let galleryDetailBackHint = CGRect(x: 66, y: 412, width: 334, height: 32)

    /// Height of one `gfxText` line box at `size` — measured via
    /// `resolve(_:).measure(in:)` (a fixed `Text("Hg8")` at each size,
    /// screenshotted through a throwaway debug readout on the Settings
    /// screen): exactly `size * 12` for this font. Upstream's bitmap font is
    /// `size * 8`, which is why ports of its y values run low here.
    static func lineHeight(_ size: Int) -> CGFloat { CGFloat(size) * 12 }

    /// The `y` to hand `gfxText` so its line box centres on `centerY`.
    ///
    /// `gfxText`'s y is the TOP of the line box, not a baseline and not a
    /// centre. Upstream can draw a label at a bar's own top edge and have it
    /// look centred, because its bitmap glyphs are only `size * 8` tall
    /// against a ~15px bar; here the same y puts the text's centre ~5px below
    /// the bar's, which reads as every label sagging. Anything drawn beside a
    /// bar, inside a box, or against a fixed-height row wants this.
    static func textTop(centeredOn centerY: CGFloat, size: Int) -> CGFloat {
        centerY - lineHeight(size) / 2
    }
}

// MARK: - RGB565

/// Upstream's `C565` macro: the panel's native pixel format, and the format
/// every colour constant in `species.h` / `dex.h` is already written in.
func rgb565(_ r: Int, _ g: Int, _ b: Int) -> UInt16 {
    UInt16((r >> 3) << 11) | UInt16((g >> 2) << 5) | UInt16(b >> 3)
}

/// Upstream's `lerp565`, component-wise in 565 space (not linear RGB) so
/// gradients match the hardware exactly.
func lerp565(_ a: UInt16, _ b: UInt16, _ i: Int, _ n: Int) -> UInt16 {
    guard n > 0 else { return a }
    let ar = Int((a >> 11) & 31), ag = Int((a >> 5) & 63), ab = Int(a & 31)
    let br = Int((b >> 11) & 31), bg = Int((b >> 5) & 63), bb = Int(b & 31)
    let r = ar + (br - ar) * i / n
    let g = ag + (bg - ag) * i / n
    let bl = ab + (bb - ab) * i / n
    return UInt16(r << 11) | UInt16(g << 5) | UInt16(bl)
}

extension Color {
    init(_ v: UInt16) {
        self.init(red: Double((v >> 11) & 31) / 31.0,
                  green: Double((v >> 5) & 63) / 63.0,
                  blue: Double(v & 31) / 31.0)
    }
}

/// Palette from `species.h`.
enum UI {
    static let bgDay: UInt16 = 0xF77C
    static let bgNight: UInt16 = 0x10C5
    static let ink: UInt16 = 0x2946
    static let inkNight: UInt16 = 0xDEFE
    static let track: UInt16 = 0xDE97
    static let barOK: UInt16 = 0x5DCD
    static let barWarn: UInt16 = 0xED07
    static let barBad: UInt16 = 0xEA87
    static let white: UInt16 = 0xFFFF

    static func inkColor(night: Bool) -> UInt16 { night ? inkNight : ink }
}

/// Backing store for `gfxTextWidth`'s cache. A plain global rather than a
/// stored property because `GraphicsContext` is a value type re-created every
/// frame, so per-instance caching would cache nothing.
private enum TPTextWidthCache {
    struct Key: Hashable { let size: Int; let string: String }
    static var storage: [Key: CGFloat] = [:]
}

/// Backing store for the point-size `gfxTextWidth(_:pt:)` variant -- see
/// its doc comment for why this is a separate cache from the one above.
private enum TPTextWidthPtCache {
    struct Key: Hashable { let pt: CGFloat; let string: String }
    static var storage: [Key: CGFloat] = [:]
}

// MARK: - Arduino_GFX primitives on GraphicsContext

extension GraphicsContext {

    func fillRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: UInt16) {
        fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(Color(c)))
    }

    func fillRoundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                       _ r: CGFloat, _ c: UInt16) {
        let p = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
        fill(p, with: .color(Color(c)))
    }

    func drawRoundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                       _ r: CGFloat, _ c: UInt16) {
        let p = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
        stroke(p, with: .color(Color(c)), lineWidth: 1)
    }

    func fillCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ c: UInt16) {
        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        fill(Path(ellipseIn: rect), with: .color(Color(c)))
    }

    func strokeCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ c: UInt16) {
        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        stroke(Path(ellipseIn: rect), with: .color(Color(c)), lineWidth: 1)
    }

    /// Draws an image's opaque shape in a single colour — upstream's `silhouette`
    /// flag on `drawMap`/`drawPmdActM`, used for unregistered Pokedex entries.
    /// The image is used as a mask so only its alpha matters.
    func drawSilhouette(_ image: CGImage, in rect: CGRect, _ c: UInt16) {
        drawLayer { layer in
            layer.clipToLayer { mask in
                mask.draw(Image(decorative: image, scale: 1).interpolation(.none), in: rect)
            }
            layer.fill(Path(rect), with: .color(Color(c)))
        }
    }

    func drawLine(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ c: UInt16) {
        var p = Path()
        p.move(to: CGPoint(x: x0, y: y0))
        p.addLine(to: CGPoint(x: x1, y: y1))
        stroke(p, with: .color(Color(c)), lineWidth: 1)
    }

    func fillTriangle(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat,
                      _ x2: CGFloat, _ y2: CGFloat, _ c: UInt16) {
        var p = Path()
        p.move(to: CGPoint(x: x0, y: y0))
        p.addLine(to: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x2, y: y2))
        p.closeSubpath()
        fill(p, with: .color(Color(c)))
    }

    // MARK: Text
    //
    // Arduino_GFX's built-in font advances 6*size px per glyph from a top-left
    // cursor, which is why the firmware's own centring idiom is
    // `CX - strlen(s) * (3*size)`. The monospaced system font this port draws
    // with matches that closely enough for ASCII (~3% off), but has no glyphs
    // at all for Hangul -- Korean falls back to Apple SD Gothic Neo, which
    // isn't monospaced and measures ~1.44x wider per character. Mixed strings
    // (Korean + a space, say) even split into runs in different fonts. See
    // kor_patch/FEASIBILITY.ko.md. `gfxTextWidth` below measures the actual
    // resolved glyphs instead of assuming a fixed advance, so every centring/
    // right-align/fit call site is correct in every language, not just ASCII.

    /// Draws like `setCursor(x, y); print(s)` — `y` is the top of the glyph box.
    func gfxText(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: Int, _ c: UInt16) {
        let t = Text(s)
            .font(.system(size: CGFloat(size) * 10, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(c))
        draw(t, at: CGPoint(x: x, y: y), anchor: .topLeading)
    }

    /// The real rendered width of `s` at `size`, replacing the firmware's
    /// `strlen(s) * 6 * size` assumption. Cached by (size, string): this runs
    /// every frame for on-screen labels, and `resolve(_:).measure(in:)` is not
    /// free.
    func gfxTextWidth(_ s: String, _ size: Int) -> CGFloat {
        let key = TPTextWidthCache.Key(size: size, string: s)
        if let cached = TPTextWidthCache.storage[key] { return cached }
        let t = Text(s)
            .font(.system(size: CGFloat(size) * 10, weight: .semibold, design: .monospaced))
        let w = resolve(t).measure(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity)).width
        TPTextWidthCache.storage[key] = w
        return w
    }

    /// `gfxText` at an arbitrary point size rather than one of the `size`
    /// steps -- for continuous shrink-to-fit (see `gfxTextWidth(_:pt:)`),
    /// where snapping straight from one step to the next would drop a label
    /// that overflows its step by a single point all the way down to the
    /// step below, when it could have shrunk by a few points and still read
    /// clearly.
    func gfxText(_ s: String, _ x: CGFloat, _ y: CGFloat, pt: CGFloat, _ c: UInt16) {
        let t = Text(s)
            .font(.system(size: pt, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(c))
        draw(t, at: CGPoint(x: x, y: y), anchor: .topLeading)
    }

    /// The real rendered width of `s` at an arbitrary point size. Cached
    /// separately from the `size`-step cache above: shrink-to-fit computes
    /// its own continuous point size per string, and rounding that into the
    /// integer-step keyspace would either collide with a real step or lose
    /// the precision the fit needs.
    func gfxTextWidth(_ s: String, pt: CGFloat) -> CGFloat {
        let key = TPTextWidthPtCache.Key(pt: pt, string: s)
        if let cached = TPTextWidthPtCache.storage[key] { return cached }
        let t = Text(s).font(.system(size: pt, weight: .semibold, design: .monospaced))
        let w = resolve(t).measure(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity)).width
        TPTextWidthPtCache.storage[key] = w
        return w
    }

    /// The largest point size in `minPt...maxPt` at which `s` measures no
    /// wider than `budget`, assuming width scales linearly with point size
    /// (true for this monospaced font at a fixed string -- no per-glyph
    /// hinting kicks in across this range) -- one measurement at `maxPt`
    /// plus a ratio, rather than a search. Never returns above `maxPt` (a
    /// short string just keeps its natural size) or below `minPt` (a
    /// string that still overflows there is left to overflow rather than
    /// shrink to illegibility).
    func gfxFitPointSize(_ s: String, maxPt: CGFloat, minPt: CGFloat, budget: CGFloat) -> CGFloat {
        let wAtMax = gfxTextWidth(s, pt: maxPt)
        guard wAtMax > budget else { return maxPt }
        return max(minPt, maxPt * budget / wAtMax)
    }

    /// Centred on `TP.cx`, matching the firmware's `CX - strlen(s) * (3*size)` idiom.
    func gfxTextCentered(_ s: String, _ y: CGFloat, _ size: Int, _ c: UInt16) {
        gfxText(s, TP.cx - gfxTextWidth(s, size) / 2, y, size, c)
    }

    /// Centred within a `w`-wide box starting at `x` (a button label, say),
    /// rather than on the whole panel like `gfxTextCentered`.
    func gfxTextCentered2(_ s: String, _ x: CGFloat, _ w: CGFloat, _ y: CGFloat,
                          _ size: Int, _ c: UInt16) {
        gfxText(s, x + (w - gfxTextWidth(s, size)) / 2, y, size, c)
    }

    /// An SF Symbol where the firmware drew a 16x16 pixel-map icon. Deliberate
    /// platform swap: the pixel icons were sized for a 466px panel, and parsing
    /// `species.h`'s glyph maps to reproduce them buys nothing on a Retina screen.
    func symbol(_ name: String, _ cx: CGFloat, _ cy: CGFloat, _ pt: CGFloat, _ c: UInt16) {
        let t = Text(Image(systemName: name))
            .font(.system(size: pt))
            .foregroundColor(Color(c))
        draw(t, at: CGPoint(x: cx, y: cy), anchor: .center)
    }
}
