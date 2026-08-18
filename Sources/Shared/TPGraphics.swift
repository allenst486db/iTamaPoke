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
    static let horizon: CGFloat = 232 // where sky meets ground
    static let btnHalf: CGFloat = 26  // buttons are 52x52
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
    // cursor. A monospaced face at 10*size pt advances 6*size, which keeps every
    // `CX - strlen(s) * 6` centring expression in the firmware correct as written.

    /// Draws like `setCursor(x, y); print(s)` — `y` is the top of the glyph box.
    func gfxText(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: Int, _ c: UInt16) {
        let t = Text(s)
            .font(.system(size: CGFloat(size) * 10, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(c))
        draw(t, at: CGPoint(x: x, y: y), anchor: .topLeading)
    }

    /// Centred on `TP.cx`, matching the firmware's `CX - strlen(s) * (3*size)` idiom.
    func gfxTextCentered(_ s: String, _ y: CGFloat, _ size: Int, _ c: UInt16) {
        gfxText(s, TP.cx - CGFloat(s.count) * CGFloat(size) * 3, y, size, c)
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
