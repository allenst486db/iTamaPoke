//
// Translated from TamaPoke by Quique Tortosa, MIT licensed:
// https://github.com/socquique/TamaPoke (TamaPoke.ino -- render, onTap,
// drawHeader, drawBars, drawButtons, and the screen layout constants).
// See LICENSE.
//

import SwiftUI

/// Port of the firmware's `render()` + `onTap()` for the idle screen.
///
/// One Canvas and one hit-test, branching on game state exactly as the .ino
/// does, rather than a tree of SwiftUI views. That keeps the port readable
/// against the original and avoids duplicating game state into view state.
///
/// Not yet ported (phase 2): sprite rendering (TPK2 loader), Pokedex gallery,
/// stat card, ball minigame, training bag, bath scene, clock/settings, the
/// on-screen keyboard, and the evolution / farewell decision dialogs.
struct PetScreen: View {

    @StateObject private var model = GameModel()
    @Environment(\.scenePhase) private var scenePhase

    /// Mirrors the .ino's file-scope `feedMenuUntil`: a deadline in ms.
    @State private var feedMenuUntil: UInt64 = 0

    private let ticker = Timer.publish(every: 1.0 / 15.0, on: .main, in: .common).autoconnect()

    /// Bottom-arc buttons: feed / play / light / bath, with the SF Symbol that
    /// replaces each 16x16 pixel icon.
    private static let buttons: [(x: CGFloat, y: CGFloat, symbol: String)] = [
        (140, 390, "fork.knife"),
        (202, 404, "tennisball.fill"),
        (264, 404, "moon.fill"),
        (326, 390, "drop.fill"),
    ]

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                var c = ctx
                let s = min(size.width, size.height) / TP.screen
                c.translateBy(x: (size.width - TP.screen * s) / 2,
                              y: (size.height - TP.screen * s) / 2)
                c.scaleBy(x: s, y: s)
                render(c)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { v in onTap(toScreenSpace(v.location, in: geo.size)) }
            )
        }
        .background(Color(model.pet.sleeping ? UI.bgNight : UI.bgDay))
        .ignoresSafeArea()
        .onAppear { model.start() }
        .onReceive(ticker) { _ in model.tick() }
        .onChange(of: scenePhase) { _, phase in model.handleScenePhase(phase) }
    }

    /// View point -> the firmware's 466x466 coordinate space.
    private func toScreenSpace(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let s = min(size.width, size.height) / TP.screen
        guard s > 0 else { return .zero }
        return CGPoint(x: (p.x - (size.width - TP.screen * s) / 2) / s,
                       y: (p.y - (size.height - TP.screen * s) / 2) / s)
    }

    // MARK: - Render

    private func render(_ ctx: GraphicsContext) {
        let pet = model.pet
        let now = model.millis

        if pet.awaitingStarter {
            renderStarterSelect(ctx)
            return
        }

        let hour = SceneRenderer.hour(epoch: pet.lastSeenEpoch)
        let night = SceneRenderer.isNight(hour: hour, sleeping: pet.sleeping)
        let biome = pet.isEgg ? 0 : Int(TPDexBiome(pet.speciesId))
        SceneRenderer.draw(ctx, biome: biome, now: now, night: night, hour: hour)

        let ink = UI.inkColor(night: night)
        let panel = night ? UI.bgNight : UI.bgDay

        if pet.ceremony != TPCeremony.none {
            drawHeader(ctx, name: TPDexName(pet.speciesId),
                       nameColor: TPDexAccent(pet.speciesId),
                       message: pet.ceremonyMessage, ink: ink)
            return
        }

        if pet.isEgg {
            drawHeader(ctx, name: pet.headerName, nameColor: ink,
                       message: pet.eggMessage, ink: ink)
            drawEgg(ctx, cracks: pet.eggCracks)
            if let rarity = pet.eggRarityLabel {
                let c: UInt16 = pet.eggRarity == 3 ? UI.barWarn : 0x4C98
                ctx.gfxTextCentered(rarity, 316, 2, c)
            }
            ctx.fillRect(0, 312, TP.screen, 154, panel)
            ctx.gfxTextCentered(pet.pokedexLine, 348, 2, ink)
        } else {
            drawHeader(ctx, name: pet.headerName,
                       nameColor: night ? UI.inkNight : TPDexAccent(pet.speciesId),
                       message: pet.statusMessage, ink: ink)
            drawPet(ctx, ink: ink, now: now)
            // Port of drawPetPMD's trailing heart draw: shown while a like or a
            // pet registers, positioned relative to the (unported) walk
            // scheduler's rest position, which is always screen-centre here.
            if pet.showHeart { ctx.drawIcon(TPIcon.heart, TP.cx + 50, TP.petGround - 190, scale: 2) }
            drawPoops(ctx, count: Int(pet.poops))
            ctx.fillRect(0, 312, TP.screen, 154, panel)
            drawBars(ctx, ink: ink)
            drawButtons(ctx, ink: ink, sleeping: pet.sleeping)
        }

        if pet.sleeping { ctx.gfxText("Zz", 320, 130, 3, UI.inkNight) }
        if now < feedMenuUntil { drawFeedMenu(ctx, ink: ink) }
    }

    private func drawHeader(_ ctx: GraphicsContext, name: String,
                            nameColor: UInt16, message: String, ink: UInt16) {
        ctx.gfxTextCentered(name, 52, 3, nameColor)
        ctx.gfxTextCentered(message, 90, 2, ink)
    }

    /// Port of the firmware's `drawPetPMD`: pick the action from the pet's mood,
    /// then anchor the frame by its feet on the ground line.
    ///
    /// The walking/gesture scheduler (`behNext`) is not ported yet, so the
    /// creature stands centred rather than wandering.
    private func drawPet(_ ctx: GraphicsContext, ink: UInt16, now: UInt64) {
        guard let sprite = model.sprite else {
            drawPetFallback(ctx, ink: ink)
            return
        }
        let pet = model.pet

        var act = TPAct.idle
        switch pet.mood {
        case .sleeping where sprite.has(.sleep): act = .sleep
        case .eating where sprite.has(.eat):     act = .eat
        case .sad where sprite.has(.hurt):       act = .hurt
        default:                                 act = .idle
        }

        guard let a = sprite[act],
              let img = sprite.image(act, frame: TPSprite.frameIndex(a, elapsedMs: now, loop: true))
        else {
            drawPetFallback(ctx, ink: ink)
            return
        }

        let s = sprite.scale(for: a)
        let w = CGFloat(a.w * s), h = CGFloat(a.h * s)
        ctx.draw(Image(decorative: img, scale: 1).interpolation(.none),
                 in: CGRect(x: TP.cx - w / 2,
                            y: TP.petGround - CGFloat((a.base > 0 ? a.base : a.h) * s),
                            width: w, height: h))
    }

    /// Shown when the current species has no TPK2 file in the bundle. Reproduces
    /// the firmware's own behaviour with an empty SD card, and is the expected
    /// state for any build that did not have sprites copied in — see README.
    private func drawPetFallback(_ ctx: GraphicsContext, ink: UInt16) {
        ctx.gfxText("?", TP.cx - 18, TP.petCY - 80, 6, ink)
        let lines = TPNoSpritesLines()
        ctx.gfxTextCentered(lines[0], TP.petCY - 4, 2, ink)
        ctx.gfxTextCentered(lines[1], TP.petCY + 20, 2, ink)
    }

    private func drawEgg(_ ctx: GraphicsContext, cracks: UInt8) {
        let rect = CGRect(x: TP.cx - 60, y: TP.petCY - 75, width: 120, height: 150)
        ctx.fill(Path(ellipseIn: rect), with: .color(Color(rgb565(0xf6, 0xf0, 0xdc))))
        ctx.stroke(Path(ellipseIn: rect), with: .color(Color(UI.ink)), lineWidth: 3)
        for spot in [(-22.0, -10.0), (14.0, 8.0), (-6.0, 34.0)] {
            ctx.fillCircle(TP.cx + spot.0, TP.petCY + spot.1, 9, rgb565(0xd8, 0xc9, 0xa4))
        }
        // Crack marks appear at 1 and 2 taps; the third hatches.
        if cracks >= 1 { crack(ctx, from: CGPoint(x: TP.cx + 6, y: TP.petCY - 46), dx: 10) }
        if cracks >= 2 { crack(ctx, from: CGPoint(x: TP.cx - 18, y: TP.petCY + 4), dx: -12) }
    }

    private func crack(_ ctx: GraphicsContext, from: CGPoint, dx: CGFloat) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: CGPoint(x: from.x + dx, y: from.y + 12))
        p.addLine(to: CGPoint(x: from.x, y: from.y + 24))
        p.addLine(to: CGPoint(x: from.x + dx, y: from.y + 36))
        ctx.stroke(p, with: .color(Color(UI.ink)), lineWidth: 3)
    }

    private func drawPoops(_ ctx: GraphicsContext, count: Int) {
        for i in 0..<count {
            ctx.drawIcon(TPIcon.poop, 36 + CGFloat(i) * 46, 244, scale: 2)
        }
    }

    private func drawBars(_ ctx: GraphicsContext, ink: UInt16) {
        let pet = model.pet
        let rows: [(CGFloat, CGFloat, Int, UInt8)] = [
            (78, 318, 0, pet.fullness), (244, 318, 1, pet.joy),
            (78, 346, 2, pet.energy),   (244, 346, 3, pet.hygiene),
        ]
        for (x, y, label, value) in rows {
            ctx.gfxText(TPBarLabel(label), x, y, 2, ink)
            let bx = x + 48, bw: CGFloat = 100, bh: CGFloat = 15
            let fill: UInt16 = value >= 50 ? UI.barOK : (value >= 25 ? UI.barWarn : UI.barBad)
            ctx.fillRoundRect(bx, y, bw, bh, 4, UI.track)
            let fw = (bw - 4) * CGFloat(value) / 100
            if fw > 0 { ctx.fillRoundRect(bx + 2, y + 2, fw, bh - 4, 3, fill) }
        }
    }

    private func drawButtons(_ ctx: GraphicsContext, ink: UInt16, sleeping: Bool) {
        for (i, b) in Self.buttons.enumerated() {
            let off = sleeping && i != 2   // asleep, only the light button works
            if !sleeping {
                ctx.fillRoundRect(b.x - TP.btnHalf, b.y - TP.btnHalf,
                                  TP.btnHalf * 2, TP.btnHalf * 2, 14, UI.white)
            }
            ctx.drawRoundRect(b.x - TP.btnHalf, b.y - TP.btnHalf,
                              TP.btnHalf * 2, TP.btnHalf * 2, 14, ink)
            if !off { ctx.symbol(b.symbol, b.x, b.y, 26, UI.ink) }
        }
    }

    private func drawFeedMenu(_ ctx: GraphicsContext, ink: UInt16) {
        ctx.fillRoundRect(101, 288, 264, 64, 14, UI.white)
        ctx.drawRoundRect(101, 288, 264, 64, 14, ink)
        ctx.drawIcon(TPIcon.food, 110, 296, scale: 3)
        ctx.drawIcon(TPIcon.berryBlue, 176, 296, scale: 3)
        ctx.drawIcon(TPIcon.berryGreen, 242, 296, scale: 3)
        ctx.drawIcon(TPIcon.candy, 308, 296, scale: 3)
    }

    private func renderStarterSelect(_ ctx: GraphicsContext) {
        ctx.fillRect(0, 0, TP.screen, TP.screen, 0x0000)
        ctx.fillCircle(TP.cx, TP.cy, 231, UI.bgDay)
        ctx.gfxTextCentered(TPChooseStarterTitle(), 68, 2, UI.ink)
        for i in 0..<3 {
            let dex = TPStarterDex(i)
            let accent = TPDexAccent(dex)
            let ry = CGFloat(110 + i * 78)
            ctx.fillRoundRect(70, ry, 326, 70, 14, lerp565(accent, UI.white, 6, 8))
            ctx.drawRoundRect(70, ry, 326, 70, 14, accent)
            ctx.gfxText(TPDexName(dex), 178, ry + 24, 3, UI.ink)
        }
    }

    // MARK: - Input

    private func onTap(_ p: CGPoint) {
        let pet = model.pet

        if pet.awaitingStarter {
            for i in 0..<3 {
                let ry = CGFloat(110 + i * 78)
                if p.x >= 70, p.x <= 396, p.y >= ry, p.y <= ry + 70 {
                    pet.chooseStarter(TPStarterDex(i))
                    return
                }
            }
            return
        }

        if pet.ceremony != TPCeremony.none { return }  // no buttons during a ceremony

        if model.millis < feedMenuUntil {
            if p.y >= 288, p.y <= 352, p.x >= 101, p.x <= 365 {
                let item = Int((p.x - 101) / 66)
                if item == 3 { pet.feedCandy() } else { pet.feedBerry(UInt8(item)) }
            }
            feedMenuUntil = 0
            return
        }

        if pet.isEgg {
            pet.eggTap()
            return
        }

        for (i, b) in Self.buttons.enumerated() {
            let dx = p.x - b.x, dy = p.y - b.y
            guard dx * dx + dy * dy <= 36 * 36 else { continue }   // BTN_HIT
            if pet.sleeping && i != 2 { return }
            switch i {
            case 0: feedMenuUntil = model.millis + 4000
            case 1: pet.playWithPet()
            case 2: pet.toggleLight()
            default: pet.clean()
            }
            return
        }

        // inPetZone(): tapping the creature pets it
        if p.x > 110, p.x < 356, p.y > 95, p.y < 310 { pet.caress() }
    }
}
