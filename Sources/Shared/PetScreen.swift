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
/// Not yet ported: the Pokedex gallery, stat card, ball minigame, training bag,
/// bath scene, clock/settings, the on-screen keyboard, the evolution and
/// ceremony animations, and the swipe gestures that open most of those.
struct PetScreen: View {

    @StateObject private var model = GameModel()
    @Environment(\.scenePhase) private var scenePhase

    /// Mirrors the .ino's file-scope `feedMenuUntil`: a deadline in ms.
    @State private var feedMenuUntil: UInt64 = 0

    /// Mirrors `choiceKind` / `choiceUntil`: which decision dialog is open, and
    /// when it gives up waiting. Upstream lets both lapse after 12s.
    private enum Choice { case none, evolve, farewell }
    @State private var choice: Choice = .none
    @State private var choiceUntil: UInt64 = 0

    private let ticker = Timer.publish(every: 1.0 / 15.0, on: .main, in: .common).autoconnect()

    /// Bottom-arc buttons: feed / play / light / bath, each with the firmware's
    /// own 16x16 colour icon (upstream's `buttons[]` table).
    private static let buttons: [(x: CGFloat, y: CGFloat, icon: [String])] = [
        (140, 390, TPIcon.food),
        (202, 404, TPIcon.play),
        (264, 404, TPIcon.light),
        (326, 390, TPIcon.clean),
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
        .onReceive(ticker) { _ in
            model.tick()
            // Upstream drops the dialog once choiceUntil passes, so an unanswered
            // question does not wedge the screen.
            if choice != .none, model.millis > choiceUntil { choice = .none }
        }
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
            // Port of drawPetPMD's trailing heart draw, following the creature.
            if pet.showHeart {
                ctx.drawIcon(TPIcon.heart, model.pose.x + 50, TP.petGround - 190, scale: 2)
            }
            drawPoops(ctx, count: Int(pet.poops))
            ctx.fillRect(0, 312, TP.screen, 154, panel)
            drawBars(ctx, ink: ink)
            drawButtons(ctx, ink: ink, sleeping: pet.sleeping)
            // Exactly upstream's precedence: evolution first, then the neglect
            // ending, then the voluntary farewell — they share screen space.
            if pet.wantsEvolveButton {
                drawEvolveButton(ctx, now: now)
            } else if pet.canRunawayNow {
                drawEndingButton(ctx, now: now, text: pet.runawayButtonText,
                                 fill: rgb565(0x3a, 0x44, 0x5a),
                                 border: rgb565(0x70, 0x80, 0x98),
                                 textColor: rgb565(0xc8, 0xd2, 0xe0),
                                 amplitude: 3, rate: 0.003)
            } else if pet.wantsFarewellButton {
                drawEndingButton(ctx, now: now, text: pet.farewellButtonText,
                                 fill: UI.barWarn, border: UI.ink, textColor: UI.ink,
                                 amplitude: 4, rate: 0.005)
            }
        }

        if pet.sleeping { ctx.gfxText("Zz", 320, 130, 3, UI.inkNight) }
        if now < feedMenuUntil { drawFeedMenu(ctx, ink: ink) }
        if choice != .none { drawChoiceDialog(ctx, choice: choice) }
    }

    private func drawHeader(_ ctx: GraphicsContext, name: String,
                            nameColor: UInt16, message: String, ink: UInt16) {
        ctx.gfxTextCentered(name, 52, 3, nameColor)
        ctx.gfxTextCentered(message, 90, 2, ink)
    }

    /// Draws whichever pose the model settled on this tick, anchored by the
    /// creature's feet on the ground line.
    private func drawPet(_ ctx: GraphicsContext, ink: UInt16, now: UInt64) {
        guard let sprite = model.sprite else {
            drawPetFallback(ctx, ink: ink)
            return
        }
        let pose = model.pose

        guard let a = sprite[pose.act],
              let img = sprite.image(pose.act,
                                     frame: TPSprite.frameIndex(a, elapsedMs: pose.elapsedMs,
                                                                loop: pose.loop))
        else {
            drawPetFallback(ctx, ink: ink)
            return
        }

        let s = sprite.scale(for: a)
        let w = CGFloat(a.w * s), h = CGFloat(a.h * s)
        ctx.draw(Image(decorative: img, scale: 1).interpolation(.none),
                 in: CGRect(x: pose.x - w / 2,
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
            // 16x16 at scale 2, drawn from its top-left corner: the firmware's
            // `cx - 16, cy - 16` centres a 32px icon on the button.
            if !off { ctx.drawIcon(b.icon, b.x - 16, b.y - 16, scale: 2) }
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

    // MARK: - Decisions

    /// The red "EVOLVE!" call to action. Upstream pulses the rectangle itself by
    /// ±5px off a sine of millis, so the button breathes rather than blinking.
    private func drawEvolveButton(_ ctx: GraphicsContext, now: UInt64) {
        let p = CGFloat(Int(5 * sin(Double(now) * 0.006)))
        let r = TP.evoBtn.insetBy(dx: -p, dy: -p)
        ctx.fillRoundRect(r.minX, r.minY, r.width, r.height, 18, UI.barBad)
        ctx.drawRoundRect(r.minX, r.minY, r.width, r.height, 18, UI.white)
        ctx.drawRoundRect(r.minX + 2, r.minY + 2, r.width - 4, r.height - 4, 16, UI.white)
        let t = model.pet.evolveButtonText
        ctx.gfxText(t, TP.cx - CGFloat(t.count) * 9, r.midY - 11, 3, UI.white)
    }

    /// The farewell and runaway calls to action share a rectangle and differ only
    /// in palette and pulse, so they share a draw.
    private func drawEndingButton(_ ctx: GraphicsContext, now: UInt64, text: String,
                                  fill: UInt16, border: UInt16, textColor: UInt16,
                                  amplitude: Double, rate: Double) {
        let p = CGFloat(Int(amplitude * sin(Double(now) * rate)))
        let r = TP.farBtn.insetBy(dx: -p, dy: -p)
        ctx.fillRoundRect(r.minX, r.minY, r.width, r.height, 16, fill)
        ctx.drawRoundRect(r.minX, r.minY, r.width, r.height, 16, border)
        ctx.gfxText(text, TP.cx - CGFloat(text.count) * 6, r.midY - 8, 2, textColor)
    }

    /// Two stacked options over a white card: act, or keep things as they are.
    private func drawChoiceDialog(_ ctx: GraphicsContext, choice: Choice) {
        let pet = model.pet
        let question: String, act: String, keep: String
        let actFill: UInt16, actInk: UInt16, keepFill: UInt16, keepInk: UInt16
        if choice == .evolve {
            question = pet.evolveQuestion; act = pet.evolveButtonText; keep = pet.evolveKeepText
            actFill = UI.barBad; actInk = UI.white; keepFill = UI.track; keepInk = UI.ink
        } else {
            question = pet.farewellQuestion; act = pet.farewellGoText; keep = pet.farewellStayText
            actFill = UI.barWarn; actInk = UI.ink; keepFill = UI.barOK; keepInk = UI.white
        }

        ctx.fillRoundRect(73, 156, 320, 188, 16, UI.white)
        ctx.drawRoundRect(73, 156, 320, 188, 16, UI.ink)
        ctx.gfxTextCentered(question, 176, 2, UI.ink)

        let a = TP.choiceAction, k = TP.choiceKeep
        ctx.fillRoundRect(a.minX, a.minY, a.width, a.height, 12, actFill)
        ctx.gfxTextCentered(act, 224, 2, actInk)
        ctx.fillRoundRect(k.minX, k.minY, k.width, k.height, 12, keepFill)
        ctx.gfxTextCentered(keep, 286, 2, keepInk)
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

        // A decision dialog swallows the tap whether or not it hit an option,
        // and closes either way — same as upstream.
        if choice != .none {
            if TP.choiceAction.contains(p) {
                if choice == .evolve { pet.evolve() } else { pet.startFarewell() }
            } else if TP.choiceKeep.contains(p) {
                if choice == .evolve { pet.declineEvolve() } else { pet.declineFarewell() }
            }
            choice = .none
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

        // The evolve CTA opens a dialog; the runaway CTA has no dialog upstream,
        // it just leaves. Both are checked before the action buttons because they
        // are drawn over the scene, above the bottom panel.
        if pet.wantsEvolveButton, TP.evoBtn.contains(p) {
            choice = .evolve
            choiceUntil = model.millis + 12000
            return
        }
        if TP.farBtn.contains(p) {
            if pet.canRunawayNow { pet.startRunaway(); return }
            if pet.wantsFarewellButton {
                choice = .farewell
                choiceUntil = model.millis + 12000
                return
            }
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
