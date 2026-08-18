//
// Translated from TamaPoke by Quique Tortosa, MIT licensed:
// https://github.com/socquique/TamaPoke (TamaPoke.ino, drawScene/drawClouds).
// The biome palette, star field and animation phases are his. See LICENSE.
//

import SwiftUI

/// Line-for-line port of the firmware's `drawScene`: sky painted from the real
/// clock (dawn / day / dusk / night) and ground painted from the species' type
/// biome. `now` is milliseconds, matching upstream's `millis()` animation phases.
enum SceneRenderer {

    /// Daytime ground per biome; night blends toward the night blue.
    static let biomeSoil: [UInt16] = [
        rgb565(0x7e, 0xc0, 0x7f),  // 0 meadow
        rgb565(0xdc, 0xca, 0x94),  // 1 beach (sand)
        rgb565(0x4f, 0x8a, 0x55),  // 2 forest
        rgb565(0x8a, 0x55, 0x44),  // 3 volcano
        rgb565(0xa8, 0x90, 0x6a),  // 4 mountain
        rgb565(0xe6, 0xee, 0xf5),  // 5 snow
    ]

    static let stars: [(CGFloat, CGFloat)] = [
        (120, 140), (330, 120), (370, 210), (95, 230), (280, 90), (160, 95),
    ]

    /// Hour of day 0-23. 13 (mid-afternoon) when the clock has never been set,
    /// same fallback the firmware uses before its RTC is read.
    static func hour(epoch: UInt32) -> Int {
        epoch != 0 ? Int((epoch / 3600) % 24) : 13
    }

    static func isNight(hour h: Int, sleeping: Bool) -> Bool {
        sleeping || h < 6 || h >= 20
    }

    private static func drawClouds(_ ctx: GraphicsContext, _ now: UInt64, _ col: UInt16) {
        for k in 0..<2 {
            let cx = CGFloat((now / 50 + UInt64(k) * 250) % 560) - 40
            let cy = 70 + CGFloat(k) * 34
            ctx.fillCircle(cx, cy, 16, col)
            ctx.fillCircle(cx + 18, cy + 3, 13, col)
            ctx.fillCircle(cx - 15, cy + 4, 12, col)
        }
    }

    static func draw(_ ctx: GraphicsContext, biome: Int, now: UInt64, night: Bool, hour h: Int) {
        let top: UInt16, bot: UInt16
        if night {
            top = rgb565(0x0c, 0x12, 0x24); bot = rgb565(0x1e, 0x26, 0x46)
        } else if h < 8 {
            top = rgb565(0xd1, 0x6a, 0x86); bot = rgb565(0xf3, 0xb8, 0x7c)   // dawn
        } else if h < 18 {
            top = rgb565(0x8f, 0xc8, 0xea); bot = rgb565(0xdc, 0xee, 0xe6)   // day
        } else {
            top = rgb565(0xc7, 0x5a, 0x4a); bot = rgb565(0xf0, 0xae, 0x64)   // dusk
        }

        // sky, in 8px bands
        let horizon = Int(TP.horizon)
        for y in stride(from: 0, to: horizon, by: 8) {
            ctx.fillRect(0, CGFloat(y), TP.screen, 8, lerp565(top, bot, y, horizon))
        }

        // sun or moon
        if night {
            ctx.fillCircle(360, 78, 24, rgb565(0xe8, 0xee, 0xf5))
            ctx.fillCircle(370, 72, 22, lerp565(top, bot, 78, horizon))  // carve a crescent
            for st in stars { ctx.fillRect(st.0, st.1, 4, 4, UI.white) }
        } else if h < 18 {
            ctx.fillCircle(360, 84, 26, h < 8 ? rgb565(0xff, 0xd9, 0x8a) : rgb565(0xff, 0xe7, 0x9f))
            drawClouds(ctx, now, rgb565(0xff, 0xff, 0xff))
        } else {
            ctx.fillCircle(233, TP.horizon - 6, 34, rgb565(0xff, 0xf1, 0xc8))  // setting sun
        }

        var soil = biomeSoil[biome >= 0 && biome < 6 ? biome : 0]
        if night { soil = lerp565(soil, rgb565(0x16, 0x1c, 0x30), 9, 16) }

        // beach: a strip of sea above the sand
        if biome == 1 {
            let sea = night ? rgb565(0x1c, 0x34, 0x52) : rgb565(0x4f, 0x96, 0xc4)
            ctx.fillRect(0, TP.horizon - 26, TP.screen, 26, sea)
            for i in 0..<3 {
                let wy = TP.horizon - 22 + CGFloat(i) * 7
                let fc = night ? rgb565(0x3a, 0x58, 0x78) : rgb565(0xbf, 0xe6, 0xf5)
                ctx.fillRect(60 + CGFloat((now / 60 + UInt64(i) * 30) % 60), wy, 26, 2, fc)
                ctx.fillRect(300 - CGFloat((now / 60 + UInt64(i) * 20) % 60), wy, 26, 2, fc)
            }
        }

        // ground
        ctx.fillRect(0, TP.horizon, TP.screen, TP.screen - TP.horizon, soil)
        let hill = lerp565(soil, night ? rgb565(0x0c, 0x12, 0x24) : rgb565(0xff, 0xff, 0xff), 3, 16)
        ctx.fillRoundRect(-60, TP.horizon - 14, 586, 60, 30, hill)

        // biome detail
        let dk = lerp565(soil, rgb565(0x10, 0x18, 0x20), night ? 11 : 7, 16)
        switch biome {
        case 2:  // forest: conifer silhouettes
            for tx in [CGFloat(60), 150, 360, 416] {
                ctx.fillTriangle(tx, TP.horizon - 46, tx - 16, TP.horizon, tx + 16, TP.horizon, dk)
                ctx.fillTriangle(tx, TP.horizon - 60, tx - 12, TP.horizon - 28, tx + 12, TP.horizon - 28, dk)
            }
        case 3:  // volcano: rocks and embers
            ctx.fillTriangle(70, TP.horizon, 40, TP.horizon + 30, 100, TP.horizon + 30, dk)
            ctx.fillTriangle(400, TP.horizon + 4, 372, TP.horizon + 30, 430, TP.horizon + 30, dk)
            if !night {
                for e in 0..<4 {
                    ctx.fillRect(120 + CGFloat(e) * 70, TP.horizon + 8 + CGFloat(e % 2) * 6,
                                 4, 4, rgb565(0xff, 0x9b, 0x3a))
                }
            }
        case 4:  // mountain: peaks on the skyline
            ctx.fillTriangle(140, TP.horizon - 50, 60, TP.horizon, 220, TP.horizon, dk)
            ctx.fillTriangle(330, TP.horizon - 38, 250, TP.horizon, 410, TP.horizon, dk)
        case 5 where !night:  // snow: falling flakes
            for f in 0..<10 {
                let fx = CGFloat((UInt64(f) * 53 + now / 40) % 466)
                let fy = CGFloat((UInt64(f) * 90 + now / 18) % UInt64(horizon))
                ctx.fillRect(fx, fy, 3, 3, UI.white)
            }
        case 0:  // meadow: tufts of grass
            for gx in [CGFloat(80), 175, 300, 395] {
                for b in -1...1 {
                    ctx.fillRect(gx + CGFloat(b) * 5, TP.horizon + 6,
                                 2, CGFloat(8 + (b == 0 ? 4 : 0)), dk)
                }
            }
        default:
            break
        }
    }
}
