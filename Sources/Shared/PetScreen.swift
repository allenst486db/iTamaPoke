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
/// Screens are reached the way upstream reaches them: swipe left for the
/// Pokedex, up for the stat card, down for settings, and hold the creature to
/// be asked about letting it go.

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

    /// Which screen is up. Upstream keeps these as separate `*Open` booleans;
    /// one enum makes the "only one at a time" rule structural.
    private enum Screen { case idle, gallery, card, sack, keyboard, settings, game }
    @State private var screen: Screen = .idle
    @State private var galleryPage = 0
    /// Dex number of the species in the detail view, 0 for the grid.
    @State private var galleryDetail: Int16 = 0
    /// Stat card page: 0 profile, 1 personality, 2 daily, 3 box, 4 battle,
    /// 5 medals, 6 progress. Pages 1-3 are ported from ShadowEnemyx/TamaPoke
    /// ("Expanded") -- see upstream-expanded/README.md.
    @State private var cardPage = 0
    private let cardPageCount = 7
    /// Box page (page 3's own internal pagination, BOX_ROWS-per-page).
    @State private var boxPage = 0
    /// Pokedex filter: 0 all, 1 raised, 2 caught.
    @State private var galleryFilter = 0

    /// Rename keyboard buffer.
    @State private var nameDraft = ""

    /// "Let it go?" confirmation deadline, upstream's `confirmUntil`.
    @State private var confirmUntil: UInt64 = 0

    /// Where and when the current drag started, for classifying it on release
    /// and for spotting a hold without a competing gesture recogniser.
    @State private var dragStart: CGPoint?
    @State private var dragNow: CGPoint?
    @State private var dragStartAt: UInt64 = 0
    @State private var holdFired = false

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
                    // Stored already converted to the 466px space, so the hold
                    // check can compare against upstream's own thresholds.
                    .onChanged { v in
                        if dragStart == nil {
                            dragStart = toScreenSpace(v.startLocation, in: geo.size)
                            dragStartAt = model.millis
                            holdFired = false
                        }
                        dragNow = toScreenSpace(v.location, in: geo.size)
                    }
                    .onEnded { v in
                        let from = dragStart ?? toScreenSpace(v.startLocation, in: geo.size)
                        dragStart = nil
                        dragNow = nil
                        // A fired hold has already acted; upstream swallows the
                        // gesture rather than also treating the release as a tap.
                        if holdFired {
                            holdFired = false
                            return
                        }
                        onGesture(from: from, to: toScreenSpace(v.location, in: geo.size))
                    }
            )
        }
        .background(Color(letterboxColor))
        .ignoresSafeArea()
        .onAppear { model.start() }
        .onReceive(ticker) { _ in
            model.tick()
            // Upstream drops the dialog once choiceUntil passes, so an unanswered
            // question does not wedge the screen.
            if choice != .none, model.millis > choiceUntil { choice = .none }
            // Both result cards dismiss themselves, as upstream's do — otherwise
            // the screen sits on the score with no way back.
            if screen == .game, model.ball.overUntil != 0, model.millis > model.ball.overUntil {
                screen = .idle
                model.endGames()
            }
            if screen == .sack, model.sack.overUntil != 0, model.millis > model.sack.overUntil {
                screen = .card
                model.endGames()
            }
            checkHold()
        }
        .onChange(of: scenePhase) { _, phase in model.handleScenePhase(phase) }
    }

    /// Upstream fires the release confirmation mid-hold, from inside its touch
    /// handler, rather than through a separate recogniser — and that matters
    /// here: a SwiftUI long-press gesture alongside the drag swallowed every
    /// tap, so the action buttons stopped working entirely.
    private func checkHold() {
        guard !holdFired, screen == .idle,
              let start = dragStart, let now = dragNow,
              model.millis &- dragStartAt > 3000,
              abs(now.x - start.x) < 30, abs(now.y - start.y) < 30
        else { return }

        let pet = model.pet
        let p = start
        guard p.x > 110, p.x < 356, p.y > 95, p.y < 310,   // inPetZone
              !pet.isEgg, pet.ceremony == TPCeremony.none, choice == .none,
              model.millis >= confirmUntil, model.millis >= feedMenuUntil
        else { return }

        confirmUntil = model.millis + 10000
        holdFired = true
    }

    /// Fills the area outside the 466x466 square on a screen taller than it.
    ///
    /// The firmware's panel is round, so it has neither corners nor letterbox
    /// and never needed a colour here. Matching whatever the square paints at
    /// its own edge is what makes the seam invisible: the panel screens are
    /// always `bgDay`, and only the idle scene follows the day/night sky.
    private var letterboxColor: UInt16 {
        if model.pet.awaitingStarter { return UI.bgDay }   // also a panel screen
        switch screen {
        case .idle, .game, .sack:
            return model.pet.sleeping ? UI.bgNight : UI.bgDay
        case .gallery, .card, .keyboard, .settings:
            return UI.bgDay
        }
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

        if screen == .gallery {
            renderGallery(ctx, now: now)
            return
        }
        if screen == .card {
            renderCard(ctx, now: now)
            return
        }
        if screen == .keyboard {
            renderKeyboard(ctx)
            return
        }
        if screen == .game {
            renderGame(ctx, now: now)
            return
        }
        if screen == .sack {
            renderSack(ctx, now: now)
            return
        }
        if screen == .settings {
            renderSettings(ctx)
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
            drawCeremony(ctx, now: now, ink: ink)
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
            drawStreakBadge(ctx, ink: ink)
            drawPet(ctx, ink: ink, now: now)
            drawBath(ctx, now: now)
            // Port of drawPetPMD's trailing heart draw, following the creature.
            if pet.showHeart {
                ctx.drawIcon(TPIcon.heart, model.pose.x + 50, TP.petGround - 190, scale: 2)
            }
            drawPoops(ctx, count: Int(pet.poops))
            ctx.fillRect(0, 312, TP.screen, 154, panel)
            drawBars(ctx, ink: ink)
            drawButtons(ctx, ink: ink, sleeping: pet.sleeping)
            drawCelebration(ctx)
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
        if now < confirmUntil { drawReleaseDialog(ctx) }
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
        // Evolving replaces the creature entirely, as upstream's drawPetPMD does
        // before it reaches the pose logic.
        if model.pet.evolvingNow {
            drawEvolveFX(ctx, now: now)
            return
        }
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
                            y: TP.petGround - CGFloat((a.base > 0 ? a.base : a.h) * s)
                               + pose.yOffset,
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

    // MARK: - Evolution and ceremony animations

    /// Draws one sprite's idle frame standing on `groundY`, optionally as a flat
    /// silhouette. Shared by the evolution flash and the ceremony walk-off.
    private func drawSpriteIdle(_ ctx: GraphicsContext, _ sprite: TPSprite,
                                x: CGFloat, groundY: CGFloat, elapsedMs: UInt64,
                                act: TPAct = .idle, maxScale: Int = 5,
                                silhouette: Bool = false) {
        let use = sprite.has(act) ? act : .idle
        guard let a = sprite[use],
              let img = sprite.image(use, frame: TPSprite.frameIndex(a, elapsedMs: elapsedMs,
                                                                    loop: true))
        else { return }
        let s = sprite.scale(for: a, max: maxScale)
        let w = CGFloat(a.w * s), h = CGFloat(a.h * s)
        let rect = CGRect(x: x - w / 2,
                          y: groundY - CGFloat((a.base > 0 ? a.base : a.h) * s),
                          width: w, height: h)
        if silhouette {
            ctx.drawSilhouette(img, in: rect, UI.ink)
        } else {
            ctx.draw(Image(decorative: img, scale: 1).interpolation(.none), in: rect)
        }
    }

    /// Port of `drawEvolveFX`: a pulsing halo, turning rays, the old and new
    /// forms flickering against each other, sparks, and a white-out reveal.
    private func drawEvolveFX(_ ctx: GraphicsContext, now: UInt64) {
        let t = CGFloat(model.pet.evolveProgress)      // 0..1
        let cx = TP.cx, cy = TP.petGround - 96
        let n = Double(now)

        let halo = 36 + t * 150 + CGFloat(8 * sin(n * 0.02))
        for k in 0..<4 {
            let r = halo - CGFloat(k) * 7
            if r > 0 { ctx.strokeCircle(cx, cy, r, UI.white) }
        }

        let base = n * 0.004
        for i in 0..<12 {
            let a = base + Double(i) * (.pi / 6)
            let len = 90 + 70 * (0.5 + 0.5 * sin(n * 0.012 + Double(i)))
            ctx.drawLine(cx, cy, cx + CGFloat(cos(a) * len), cy + CGFloat(sin(a) * len), UI.white)
        }

        // Flicker between the two forms, quickening as it goes, then settle on
        // the new one for the flash.
        let period = UInt64(60 + 220 * (1 - t))
        let showOld = t < 0.9 && model.evoSprite != nil && (now / max(period, 1)) % 2 == 0
        if showOld, let old = model.evoSprite {
            drawSpriteIdle(ctx, old, x: cx, groundY: TP.petGround, elapsedMs: 0, silhouette: true)
        } else if let new = model.sprite {
            drawSpriteIdle(ctx, new, x: cx, groundY: TP.petGround, elapsedMs: 0, silhouette: true)
        }

        for i in 0..<10 {
            let a = Double(i) * (.pi / 5) + Double(t) * 4.0
            let d = CGFloat((now / 14 + UInt64(i) * 33) % 200)
            let sx = cx + CGFloat(cos(a)) * d, sy = cy + CGFloat(sin(a)) * d
            ctx.fillRect(sx - 2, sy - 2, 5, 5,
                         i & 1 == 1 ? rgb565(0xff, 0xe0, 0x70) : UI.white)
        }

        if t > 0.9 { ctx.fillCircle(cx, cy, 300 * (t - 0.9) / 0.1, UI.white) }
    }

    /// Port of `drawCeremony`: the two endings. A farewell gets a golden halo,
    /// rising hearts and a bow before it walks off right; a runaway gets rain,
    /// a flinch and a fading walk off left.
    private func drawCeremony(_ ctx: GraphicsContext, now: UInt64, ink: UInt16) {
        let pet = model.pet
        let t = CGFloat(pet.ceremonyProgress)          // 0..1 over ten seconds
        let panic = pet.ceremony == .runaway
        let n = Double(now)
        var x = TP.cx
        var act = TPAct.idle
        var fade = false

        if panic {
            for i in 0..<46 {
                let rx = CGFloat((UInt64(i) * 47 + now / 3) % 466)
                let ry = CGFloat((UInt64(i) * 91 + now / 2) % 470)
                ctx.drawLine(rx, ry, rx - 3, ry + 12, rgb565(0x6a, 0x84, 0xb0))
            }
            if t < 0.30 {
                act = .hurt
                x = TP.cx + CGFloat(4 * sin(n * 0.04))
            } else {
                act = .walkL
                x = TP.cx - ((t - 0.30) / 0.70) * (TP.cx + 120)
                fade = t > 0.6 && (now / 160) % 2 == 0
            }
        } else {
            // Pulsing golden halo.
            let gcy = TP.petGround - 96
            for k in 0..<4 {
                let r = 60 + CGFloat(k) * 34 + CGFloat(10 * sin(n * 0.02))
                ctx.strokeCircle(TP.cx, gcy, r, rgb565(0xff, 0xdf, 0x8a))
            }
            for i in 0..<16 {
                let px = CGFloat((i * 71 + 28) % 466)
                let py = 410 - CGFloat((now / 8 + UInt64(i) * 70) % 360)
                if py < 30 { continue }
                if i % 4 == 0 {
                    ctx.drawIcon(TPIcon.heart, px - 8, py - 8, scale: 1)
                } else {
                    ctx.fillRect(px, py, 4, 4,
                                 i % 2 == 1 ? rgb565(0xff, 0xe7, 0x9f) : rgb565(0xff, 0x9a, 0xc0))
                }
            }
            if t < 0.45 {
                act = .pose
            } else {
                act = .walkR
                x = TP.cx + ((t - 0.45) / 0.55) * (TP.cx + 140)
            }
        }

        if let sprite = model.sprite {
            drawSpriteIdle(ctx, sprite, x: x, groundY: TP.petGround, elapsedMs: now,
                           act: act, silhouette: panic ? fade : false)
            if !panic, pet.showHeart {
                ctx.drawIcon(TPIcon.heart, x + 50, TP.petGround - 190, scale: 2)
            }
        }

        // A tear, while it is still standing there.
        if panic, t < 0.55 {
            let ty = TP.petGround - 150 + CGFloat((now / 6) % 40)
            ctx.fillRect(x + 6, ty, 3, 6, rgb565(0x9a, 0xc4, 0xe8))
        }
    }

    /// Flame and streak count, top-left of the idle screen.
    private func drawStreakBadge(_ ctx: GraphicsContext, ink: UInt16) {
        guard model.pet.streak >= 1 else { return }
        drawFlame(ctx, x: 26, y: 16, height: 17)
        ctx.gfxText("\(model.pet.streak)", 48, 18, 2, ink)
    }

    /// Temporary banner for a new medal or a streak milestone.
    private func drawCelebration(_ ctx: GraphicsContext) {
        let pet = model.pet
        let title: String, detail: String
        if pet.showMedal, let name = pet.newMedalName {
            title = pet.medalBannerTitle
            detail = name
        } else if pet.showMilestone {
            title = pet.milestoneTitle
            detail = pet.milestoneLine
        } else {
            return
        }
        ctx.fillRoundRect(73, 150, 320, 96, 16, UI.barWarn)
        ctx.drawRoundRect(73, 150, 320, 96, 16, UI.ink)
        ctx.gfxTextCentered(title, 176, 3, UI.ink)
        ctx.gfxTextCentered(detail, 212, 2, UI.ink)
    }

    /// Port of upstream's `drawBath`: soap suds over the creature — no tub.
    ///
    /// The bubbles sway on a sine, drift upward as the three seconds run down,
    /// and in the last 800ms pop into little sparkle crosses.
    private func drawBath(_ ctx: GraphicsContext, now: UInt64) {
        let until = model.bathUntil
        guard until > now else { return }
        let left = until - now

        // Saturating, not `bathDuration - left`: upstream does this in wrapping
        // uint32_t arithmetic, and the same expression traps in Swift the moment
        // `left` exceeds the duration.
        let elapsed = GameModel.bathDuration > left ? GameModel.bathDuration - left : 0

        if left > 800 {
            let t = Double(now) / 220.0
            for b in model.bubbles {
                let bx = b.x + CGFloat(sin(t + Double(b.phase)) * 6)
                let by = b.y - CGFloat(elapsed / 90)
                ctx.fillCircle(bx, by, b.r, UI.white)
                ctx.strokeCircle(bx, by, b.r, 0x7E3D)
                // The little highlight that reads as a soap bubble.
                ctx.fillCircle(bx - b.r / 3, by - b.r / 3, b.r / 4, UI.bgDay)
            }
        } else {
            for i in 0..<8 {
                let b = model.bubbles[i]
                let sx = b.x + CGFloat(i % 3) * 6 - 6
                let sy = b.y - 18
                let col: UInt16 = i % 2 == 1 ? UI.barWarn : UI.white
                ctx.fillRect(sx - 6, sy - 1, 13, 3, col)
                ctx.fillRect(sx - 1, sy - 6, 3, 13, col)
            }
        }
    }

    /// "Let it go?" — upstream's long-press confirmation, two buttons.
    private func drawReleaseDialog(_ ctx: GraphicsContext) {
        let pet = model.pet
        ctx.fillRoundRect(94, 168, 278, 152, 16, UI.white)
        ctx.drawRoundRect(94, 168, 278, 152, 16, UI.ink)
        ctx.gfxTextCentered(pet.releaseQuestion, 196, 2, UI.ink)
        let yes = TP.releaseYes, no = TP.releaseNo
        ctx.fillRoundRect(yes.minX, yes.minY, yes.width, yes.height, 12, UI.barOK)
        ctx.gfxText(pet.yesText, yes.midX - CGFloat(pet.yesText.count) * 6, 270, 2, UI.white)
        ctx.fillRoundRect(no.minX, no.minY, no.width, no.height, 12, UI.barBad)
        ctx.gfxText(pet.noText, no.midX - CGFloat(pet.noText.count) * 6, 270, 2, UI.white)
    }

    // MARK: - Settings

    /// Upstream's clock screen, minus the clock.
    ///
    /// Its hour/minute dial exists because the ESP32 has no idea what time it is
    /// and the sky depends on it. iOS already knows, and pointing the game at a
    /// hand-set time instead of the system clock is precisely the bug that made
    /// the sky run nine hours early. What remains is the rest of that screen:
    /// the language picker and the sound toggle, which are real settings.
    private static let langCodes = ["ES", "EN", "FR", "DE", "IT", "PT"]
    private static let langPill = CGRect(x: 336, y: 296, width: 96, height: 30)
    private static let sndPill = CGRect(x: 34, y: 296, width: 96, height: 30)

    private func renderSettings(_ ctx: GraphicsContext) {
        ctx.fillRect(0, 0, TP.screen, TP.screen, UI.bgDay)
        ctx.fillCircle(TP.cx, TP.cy, 231, UI.bgDay)
        ctx.gfxTextCentered(model.pet.settingsTitle, 44, 3, UI.ink)

        // Local time, shown rather than set: it comes from the device.
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let clock = f.string(from: Date())
        ctx.gfxText(clock, TP.cx - 105, 120, 7, UI.ink)
        ctx.gfxTextCentered(TimeZone.current.identifier, 210, 2, UI.track)

        let snd = model.soundEnabled
        let s = Self.sndPill
        ctx.fillRoundRect(s.minX, s.minY, s.width, s.height, 8, snd ? UI.barOK : UI.white)
        ctx.drawRoundRect(s.minX, s.minY, s.width, s.height, 8, UI.ink)
        let sl = snd ? model.pet.soundOnText : model.pet.soundOffText
        ctx.gfxText(sl, s.minX + (s.width - CGFloat(sl.count) * 12) / 2, s.minY + 8, 2,
                    snd ? UI.bgDay : UI.ink)

        let l = Self.langPill
        ctx.fillRoundRect(l.minX, l.minY, l.width, l.height, 8, UI.white)
        ctx.drawRoundRect(l.minX, l.minY, l.width, l.height, 8, UI.ink)
        let lp = "\(Self.langCodes[Int(TPLanguage())]) >"
        ctx.gfxText(lp, l.minX + (l.width - CGFloat(lp.count) * 12) / 2, l.minY + 8, 2, UI.ink)

        ctx.gfxTextCentered(model.pet.backHint, 410, 2, UI.track)
    }

    private func settingsTap(_ p: CGPoint) {
        if Self.sndPill.contains(p) {
            model.setSound(!model.soundEnabled)
            return
        }
        if Self.langPill.contains(p) {
            TPSetLanguage((TPLanguage() + 1) % UInt8(Self.langCodes.count))
            model.playSfx(.tap)
            return
        }
        if p.y > 380 { screen = .idle }
    }

    // MARK: - Rename keyboard

    /// 26 letters plus "." and "-", then backspace and OK.
    private static let kbKeys = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ.-")
    private static let kbCols = 6
    private static let kbX: CGFloat = 40
    private static let kbY: CGFloat = 150
    private static let kbW: CGFloat = 64
    private static let kbH: CGFloat = 52

    private func renderKeyboard(_ ctx: GraphicsContext) {
        ctx.fillRect(0, 0, TP.screen, TP.screen, UI.bgDay)
        ctx.fillCircle(TP.cx, TP.cy, 231, UI.bgDay)
        ctx.gfxTextCentered(model.pet.nameLabel, 56, 2, UI.ink)

        ctx.fillRoundRect(83, 84, 300, 40, 8, UI.white)
        ctx.drawRoundRect(83, 84, 300, 40, 8, UI.ink)
        ctx.gfxText(nameDraft.isEmpty ? "_" : nameDraft, 95, 94, 3, UI.ink)

        for i in 0..<30 {
            let x = Self.kbX + CGFloat(i % Self.kbCols) * Self.kbW
            let y = Self.kbY + CGFloat(i / Self.kbCols) * Self.kbH
            let special = i >= 28
            ctx.fillRoundRect(x, y, Self.kbW - 6, Self.kbH - 6, 6,
                              special ? UI.barWarn : UI.white)
            ctx.drawRoundRect(x, y, Self.kbW - 6, Self.kbH - 6, 6, UI.ink)
            if i < 28 {
                ctx.gfxText(String(Self.kbKeys[i]), x + Self.kbW / 2 - 9,
                            y + Self.kbH / 2 - 10, 2, UI.ink)
            } else {
                ctx.gfxText(i == 28 ? "<-" : "OK", x + Self.kbW / 2 - 15,
                            y + Self.kbH / 2 - 10, 2, UI.ink)
            }
        }
    }

    private func keyboardTap(_ p: CGPoint) {
        let col = Int((p.x - Self.kbX) / Self.kbW)
        let row = Int((p.y - Self.kbY) / Self.kbH)
        guard col >= 0, col < Self.kbCols, row >= 0, row < 5 else { return }
        let i = row * Self.kbCols + col
        guard i < 30 else { return }

        if i == 28 {
            if !nameDraft.isEmpty { nameDraft.removeLast() }
        } else if i == 29 {
            model.pet.renamePet(nameDraft)
            screen = .card
        } else if nameDraft.count < 11 {     // upstream's nameBuf is 12 bytes
            nameDraft.append(Self.kbKeys[i])
        }
    }

    // MARK: - Minigames

    /// Shared backdrop for both minigames: the creature's own habitat, so they
    /// do not look like a different app. Upstream's `drawGameScene`.
    private func drawGameScene(_ ctx: GraphicsContext, now: UInt64) -> UInt16 {
        let pet = model.pet
        let hour = SceneRenderer.hour(epoch: pet.lastSeenEpoch)
        let night = SceneRenderer.isNight(hour: hour, sleeping: false)
        let biome = pet.isEgg ? 0 : Int(TPDexBiome(pet.speciesId))
        SceneRenderer.draw(ctx, biome: biome, now: now, night: night, hour: hour)
        return UI.inkColor(night: night)
    }

    private func renderGame(_ ctx: GraphicsContext, now: UInt64) {
        let pet = model.pet
        let ink = drawGameScene(ctx, now: now)
        let g = model.ball

        if g.overUntil != 0 {
            let score = pet.scoreLine(g.score)
            ctx.gfxText(score, TP.cx - CGFloat(score.count) * 12, 160, 4, ink)
            if g.newHigh, g.score > 0 {
                ctx.gfxTextCentered(pet.newRecordText, 214, 2, UI.barWarn)
            } else {
                ctx.gfxTextCentered(pet.recordLine(pet.gameHigh), 214, 2, ink)
            }
            ctx.gfxTextCentered(pet.playResultMessage(g.score), 250, 2, ink)
            return
        }

        let s = "\(g.score)"
        ctx.gfxText(s, TP.cx - CGFloat(s.count) * 12, 30, 4, ink)
        ctx.gfxTextCentered(pet.shortRecordLine(pet.gameHigh), 76, 2, ink)
        for i in 0..<3 {
            let cx = 180 + CGFloat(i) * 28
            if i < 3 - g.misses { ctx.fillCircle(cx, 104, 6, UI.barBad) }
            else { ctx.strokeCircle(cx, 104, 6, UI.track) }
        }

        // The creature chases the ball along the ground.
        if let sprite = model.sprite {
            var act = TPAct.idle
            if g.ballX > g.petX + 4 { act = .walkR }
            else if g.ballX < g.petX - 4 { act = .walkL }
            if !sprite.has(act) { act = .idle }
            if let a = sprite[act],
               let img = sprite.image(act, frame: TPSprite.frameIndex(a, elapsedMs: now, loop: true)) {
                let sc = sprite.scale(for: a, max: 3)
                let w = CGFloat(a.w * sc), h = CGFloat(a.h * sc)
                ctx.draw(Image(decorative: img, scale: 1).interpolation(.none),
                         in: CGRect(x: g.petX - w / 2,
                                    y: 394 - CGFloat((a.base > 0 ? a.base : a.h) * sc),
                                    width: w, height: h))
            }
        }

        // Expanding impact ring, upstream's soft hit feedback.
        let since = now &- g.hitAt
        if g.hitAt != 0, since < 260 {
            let rad = 22 + CGFloat(since) / 6
            ctx.strokeCircle(g.hitX, g.hitY, rad, rgb565(0xff, 0xe7, 0x9f))
            ctx.strokeCircle(g.hitX, g.hitY, rad - 2, rgb565(0xff, 0xd9, 0x8a))
        }

        ctx.drawIcon(TPIcon.play, g.ballX - 24, g.ballY - 24, scale: 3)
    }

    private func renderSack(_ ctx: GraphicsContext, now: UInt64) {
        let pet = model.pet
        let ink = drawGameScene(ctx, now: now)
        let s = model.sack

        if s.overUntil != 0 {
            let hits = pet.hitsLine(s.hits)
            ctx.gfxText(hits, TP.cx - CGFloat(hits.count) * 12, 150, 4, ink)
            let gain = pet.strengthGainLine(s.gain)
            ctx.gfxText(gain, TP.cx - CGFloat(gain.count) * 9, 210, 3, UI.barBad)
            if s.newHigh, s.hits > 0 {
                ctx.gfxTextCentered(pet.newRecordText, 256, 2, UI.barWarn)
            } else {
                ctx.gfxTextCentered(pet.recordLine(pet.strengthHigh), 256, 2, ink)
            }
            return
        }

        // The sack swings for a moment after each hit.
        let off = s.shake * CGFloat(sin(Double(now) * 0.05))
        let sx = TP.cx + off, top: CGFloat = 86
        ctx.fillRect(TP.cx - 3, 56, 6, top - 56, ink)          // rope
        ctx.fillRect(sx - 4, top - 30, 8, 34, ink)             // chain
        ctx.fillRoundRect(sx - 42, top, 84, 150, 26, rgb565(0xb5, 0x3a, 0x3a))
        ctx.fillRoundRect(sx - 42, top, 84, 22, 18, rgb565(0x7e, 0x28, 0x28))
        ctx.drawRoundRect(sx - 42, top, 84, 150, 26, ink)
        ctx.fillRect(sx - 42, top + 70, 84, 4, rgb565(0x7e, 0x28, 0x28))

        let count = "\(s.hits)"
        ctx.gfxText(count, TP.cx - CGFloat(count.count) * 18, 268, 6, ink)
        ctx.gfxTextCentered(pet.hitFastText, 322, 2, ink)

        let left = s.until > now ? s.until - now : 0
        let bw: CGFloat = 280
        let fw = bw * CGFloat(left) / 10000
        ctx.fillRoundRect(TP.cx - bw / 2, 350, bw, 16, 5, UI.track)
        if fw > 2 { ctx.fillRoundRect(TP.cx - bw / 2, 350, fw, 16, 5, UI.barOK) }
    }

    private func gameTap(_ p: CGPoint) {
        if model.ball.overUntil != 0 { return }
        if p.y < 72 {                       // header leaves without a reward
            screen = .idle
            model.endGames()
            return
        }
        if model.tapBall(p) { model.playSfx(.play) }
    }

    private func sackTap(_ p: CGPoint) {
        if model.sack.overUntil != 0 { return }
        if p.y < 72 {
            screen = .card
            model.endGames()
            return
        }
        model.tapSack()
    }

    // MARK: - Stat card

    /// Port of `renderCard`: seven pages over the round panel, swiped between.
    private func renderCard(_ ctx: GraphicsContext, now: UInt64) {
        ctx.fillRect(0, 0, TP.screen, TP.screen, UI.bgDay)
        ctx.fillCircle(TP.cx, TP.cy, 231, UI.bgDay)

        switch cardPage {
        case 0:  renderCardProfile(ctx, now: now)
        case 1:  renderCardPersonality(ctx)
        case 2:  renderCardDaily(ctx)
        case 3:  renderCardBox(ctx)
        case 4:  renderCardStats(ctx)
        case 5:  renderCardMedals(ctx)
        default: renderCardProgress(ctx)
        }

        let dotsX = TP.cx - CGFloat(cardPageCount - 1) * 13
        for i in 0..<cardPageCount {
            let cx = dotsX + CGFloat(i) * 26
            if i == cardPage { ctx.fillCircle(cx, 374, 5, UI.ink) }
            else { ctx.strokeCircle(cx, 374, 4, UI.ink) }
        }
        ctx.gfxTextCentered(model.pet.backHint, 398, 2, UI.track)
    }

    private func renderCardProfile(_ ctx: GraphicsContext, now: UInt64) {
        let pet = model.pet
        let head = pet.headerName
        // Upstream shrinks the title rather than let a long name run off the
        // narrow top of the round panel.
        let size = head.count <= 11 ? 3 : 2
        ctx.gfxTextCentered(head, size == 3 ? 34 : 40, size, TPDexAccent(pet.speciesId))
        if !pet.nick.isEmpty {
            ctx.gfxTextCentered("(\(pet.speciesName))", 64, 2, UI.track)
        }

        if let sprite = model.sprite, let a = sprite[.idle],
           let img = sprite.image(.idle, frame: TPSprite.frameIndex(a, elapsedMs: now, loop: true)) {
            let s = sprite.scale(for: a, max: 4)
            let w = CGFloat(a.w * s), h = CGFloat(a.h * s)
            ctx.draw(Image(decorative: img, scale: 1).interpolation(.none),
                     in: CGRect(x: TP.cx - w / 2,
                                y: 206 - CGFloat((a.base > 0 ? a.base : a.h) * s),
                                width: w, height: h))
        }

        drawFlame(ctx, x: 138, y: 224)
        ctx.gfxText(pet.streakLine, 162, 226, 2, UI.ink)
        drawCardStat(ctx, y: 258, label: pet.bondLabel, value: UInt16(pet.bond),
                     maxBar: 100, color: rgb565(0xd4, 0x52, 0x7e))
        ctx.gfxTextCentered(pet.infoLine, 296, 2, UI.ink)
        ctx.gfxTextCentered(pet.renameHint, 332, 2, UI.track)
    }

    // MARK: - Personality / Daily / Box
    // Ported from ShadowEnemyx/TamaPoke ("TamaPoke — Expanded"), a separate
    // community fork socquique's own README links to -- not from the
    // upstream/ submodule. See upstream-expanded/README.md.

    /// personalityKind: 0 balanced, 1 playful, 2 brave, 3 calm, 4 lazy.
    private func personalityColor(_ kind: Int) -> UInt16 {
        switch kind {
        case 1:  return UI.barWarn   // playful
        case 2:  return UI.barBad    // brave
        case 3:  return 0x4C98       // calm
        case 4:  return 0xB3C8       // lazy
        default: return UI.barOK     // balanced
        }
    }

    private func renderCardPersonality(_ ctx: GraphicsContext) {
        let pet = model.pet
        let col = personalityColor(pet.personalityKind)
        ctx.gfxTextCentered(pet.personalityTitle, 44, 3, UI.ink)

        ctx.fillRoundRect(62, 86, 342, 70, 16, col)
        let name = pet.personalityName
        let nameSize = name.count <= 10 ? 3 : 2
        ctx.gfxTextCentered(name, nameSize == 3 ? 104 : 111, nameSize, UI.bgDay)
        ctx.gfxTextCentered(pet.personalityHint, 136, 2, UI.bgDay)

        drawCardStat(ctx, y: 182, label: pet.bondLabel, value: UInt16(pet.bond),
                     maxBar: 100, color: rgb565(0xd4, 0x52, 0x7e))
        drawCardStat(ctx, y: 220, label: TPBarLabel(1), value: UInt16(pet.joy),
                     maxBar: 100, color: UI.barWarn)

        // Upstream's GFX bitmap font is much more compact vertically than the
        // system monospaced font this draws with, so these two lines (12px
        // apart in the original) collide at size 2; the age line drops to
        // size 1 and the gap widens well past what the original needed.
        ctx.gfxTextCentered(pet.personalityAgeLine, 246, 1, UI.track)
        ctx.gfxTextCentered(pet.recordsTitle, 268, 2, UI.ink)
        drawPersonalityRecord(ctx, x: 52,  y: 294, label: pet.ballRecordLabel,  value: pet.gameHigh,  color: UI.barOK)
        drawPersonalityRecord(ctx, x: 178, y: 294, label: pet.catchRecordLabel, value: pet.catchHigh, color: UI.barWarn)
        drawPersonalityRecord(ctx, x: 304, y: 294, label: pet.memoRecordLabel,  value: pet.memoHigh,  color: 0x4C98)
        drawPersonalityRecord(ctx, x: 52,  y: 334, label: pet.cleanRecordLabel, value: pet.cleanHigh, color: UI.barOK)
        drawPersonalityRecord(ctx, x: 178, y: 334, label: pet.typeRecordLabel,  value: pet.typeHigh,  color: 0xF3B7)
        drawPersonalityRecord(ctx, x: 304, y: 334, label: pet.battleTitle,      value: pet.bestBattleStreak, color: UI.barBad)
    }

    /// Port of `drawPersonalityRecord`: a small bordered box, label top-left,
    /// number bottom-right.
    private func drawPersonalityRecord(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat,
                                       label: String, value: UInt16, color: UInt16) {
        ctx.fillRoundRect(x, y, 118, 34, 8, UI.white)
        ctx.drawRoundRect(x, y, 118, 34, 8, color)
        ctx.gfxText(label, x + 10, y + 6, 1, color)
        let num = "\(value)"
        ctx.gfxText(num, x + 118 - 12 - CGFloat(num.count) * 12, y + 14, 2, UI.ink)
    }

    private func dailyGoalColor(_ kind: Int) -> UInt16 {
        switch kind {
        case 1:  return UI.barWarn                    // play
        case 2:  return UI.barBad                      // battle
        case 3:  return UI.barOK                        // catch
        case 4:  return 0x4C98                          // memo
        default: return rgb565(0xd4, 0x52, 0x7e)        // care
        }
    }

    private func renderCardDaily(_ ctx: GraphicsContext) {
        let pet = model.pet
        pet.ensureDailyGoals()
        ctx.gfxTextCentered(pet.dailyTitle, 44, 3, UI.ink)
        ctx.gfxTextCentered(pet.dayPhaseLabel, 78, 1, UI.track)

        var done = 0
        for i in 0..<pet.dailyGoalCount {
            drawDailyGoalRow(ctx, y: 104 + CGFloat(i) * 70, index: i)
            if pet.dailyGoalComplete(at: i) { done += 1 }
        }
        ctx.gfxTextCentered(pet.dailyRewardLine, 324, 2,
                            done == pet.dailyGoalCount ? UI.barOK : UI.track)
    }

    /// Port of `drawDailyGoalRow`: a filled pill once complete, outline until
    /// then, with a checkmark once done.
    private func drawDailyGoalRow(_ ctx: GraphicsContext, y: CGFloat, index: NSInteger) {
        let pet = model.pet
        let done = pet.dailyGoalComplete(at: index)
        let col = dailyGoalColor(pet.dailyGoalKind(at: index))
        ctx.fillRoundRect(58, y, 350, 52, 12, done ? col : UI.white)
        ctx.drawRoundRect(58, y, 350, 52, 12, col)
        ctx.gfxText(pet.dailyGoalLabel(at: index), 82, y + 18, 2, done ? UI.bgDay : UI.ink)

        let progress = pet.dailyGoalProgress(at: index)
        let target = pet.dailyGoalTarget(at: index)
        if done {
            ctx.gfxText(pet.doneText, 286, y + 18, 2, UI.bgDay)
            ctx.fillCircle(374, y + 26, 12, UI.bgDay)
            ctx.gfxText("v", 368, y + 18, 2, col)
        } else {
            ctx.gfxText("\(progress)/\(target)", 286, y + 18, 2, UI.ink)
        }
    }

    private func renderCardBox(_ ctx: GraphicsContext) {
        let pet = model.pet
        let rows = 5
        let pages = pet.boxPageCount(withRowsPerPage: rows)
        if boxPage >= pages { boxPage = max(0, pages - 1) }

        // Left-aligned rather than upstream's centred title: centring it
        // collides with "CAUGHT x/151" below, which is also left-aligned at
        // x=72 -- upstream can afford both centred (title) and left-aligned
        // (count) this close together because its bitmap font is far more
        // compact than the system font this draws with.
        ctx.gfxText(pet.boxTitle, 72, 34, 3, UI.ink)

        let sort = pet.boxSortLabel
        ctx.fillRoundRect(302, 62, 106, 28, 9, UI.white)
        ctx.drawRoundRect(302, 62, 106, 28, 9, UI.ink)
        ctx.gfxText(sort, 302 + (106 - CGFloat(sort.count) * 6) / 2, 73, 1, UI.ink)

        // caughtCountLine/knownCountLine share the same x as
        // renderCardPersonality's age/records pair, and the same fix: the
        // second (smaller, secondary) line drops to size 1 for clearance.
        ctx.gfxText(pet.caughtCountLine, 72, 74, 2, UI.ink)
        ctx.gfxText(pet.knownCountLine, 72, 100, 1, UI.track)
        ctx.gfxText(pet.dexGoalLine, 258, 100, 1, UI.track)

        if pet.caughtCount == 0 {
            ctx.fillRoundRect(82, 178, 302, 72, 16, UI.white)
            ctx.drawRoundRect(82, 178, 302, 72, 16, UI.track)
            ctx.gfxTextCentered(pet.noCatchesText, 207, 2, UI.track)
            return
        }

        for i in 0..<rows {
            let dex = pet.boxDex(at: boxPage * rows + i)
            guard dex > 0 else { break }
            let y = 122 + CGFloat(i) * 42
            let raised = pet.isRegistered(dex)
            ctx.fillRoundRect(58, y, 350, 34, 9, UI.white)
            ctx.drawRoundRect(58, y, 350, 34, 9, TPDexAccent(dex))
            let name = String(format: "#%03d %@", dex, TPDexName(dex))
            ctx.gfxText(name, 72, y + (name.count <= 16 ? 7 : 5), name.count <= 16 ? 2 : 1, UI.ink)
            ctx.gfxText(pet.typeText(forDex: dex), 72, y + 24, 1, pet.typeColor(forDex: dex))
            if raised {
                ctx.gfxText(pet.raisedMarkText, 330, y + 15, 1, UI.barOK)
            }
        }

        let prevOn = boxPage > 0
        let nextOn = boxPage + 1 < pages
        ctx.fillRoundRect(76, 348, 94, 38, 11, prevOn ? UI.track : 0xE71C)
        ctx.fillRoundRect(296, 348, 94, 38, 11, nextOn ? UI.track : 0xE71C)
        ctx.gfxText("<", 111, 357, 3, UI.bgDay)
        ctx.gfxText(">", 331, 357, 3, UI.bgDay)
        ctx.gfxTextCentered(pet.pageLine(forPage: boxPage + 1, count: pages), 360, 2, UI.track)
    }

    private func renderCardStats(_ ctx: GraphicsContext) {
        let pet = model.pet
        ctx.gfxTextCentered(pet.battleTitle, 48, 3, UI.ink)
        drawCardStat(ctx, y: 118, label: pet.statLabel(0), value: pet.atkStat,
                     maxBar: 260, color: UI.barBad)
        drawCardStat(ctx, y: 160, label: pet.statLabel(1), value: pet.defStat,
                     maxBar: 260, color: 0x4C98)
        drawCardStat(ctx, y: 202, label: pet.statLabel(2), value: pet.speStat,
                     maxBar: 260, color: UI.barWarn)
        drawCardStat(ctx, y: 244, label: pet.statLabel(3), value: UInt16(pet.weight),
                     maxBar: 100, color: 0xB3C8)

        let b = TP.trainBtn
        ctx.fillRoundRect(b.minX, b.minY, b.width, b.height, 12, UI.barBad)
        ctx.gfxTextCentered(pet.trainButtonText, 311, 2, UI.bgDay)
    }

    private func renderCardMedals(_ ctx: GraphicsContext) {
        let pet = model.pet
        ctx.gfxTextCentered(pet.medalsLine, 48, 3, UI.ink)
        for i in 0..<pet.medalCount {
            let x = 28 + CGFloat(i % 2) * 206
            let y = 104 + CGFloat(i / 2) * 54
            let got = pet.hasMedal(at: i)
            ctx.fillRoundRect(x, y, 196, 44, 10, got ? UI.barOK : UI.track)
            if got {
                ctx.fillCircle(x + 22, y + 22, 11, UI.bgDay)
                ctx.gfxText("v", x + 16, y + 13, 2, UI.barOK)
            }
            ctx.gfxText(pet.medalDescription(at: i), x + 44, y + 14, 2,
                        got ? UI.bgDay : 0x8410)
        }
    }

    private func renderCardProgress(_ ctx: GraphicsContext) {
        let pet = model.pet
        ctx.gfxTextCentered(pet.progressTitle, 44, 3, UI.ink)

        let lv = pet.levelLine
        ctx.gfxText(lv, TP.cx - CGFloat(lv.count) * 15, 86, 5, UI.ink)

        let bx: CGFloat = 93, bw: CGFloat = 280, by: CGFloat = 158, bh: CGFloat = 22
        ctx.fillRoundRect(bx, by, bw, bh, 6, UI.track)
        let fw = (bw - 4) * CGFloat(pet.minutesIntoLevel) / CGFloat(pet.minutesPerLevel)
        if fw > 0 { ctx.fillRoundRect(bx + 2, by + 2, fw, bh - 4, 5, UI.barOK) }
        ctx.gfxTextCentered(pet.nextLevelLine, by + 32, 2, UI.ink)

        ctx.gfxTextCentered(pet.evolutionLabel, 230, 2, UI.track)
        let evoColor: UInt16
        switch pet.evolutionStatusKind {
        case 1:  evoColor = UI.barOK
        case 2:  evoColor = UI.barBad
        default: evoColor = UI.ink
        }
        ctx.gfxTextCentered(pet.evolutionStatus, 256, 2, evoColor)
        ctx.gfxTextCentered(pet.mistakesLine, 312, 2,
                            pet.careMistakes > 0 ? UI.barBad : UI.ink)
    }

    /// Upstream's `drawCardStat`: label, value and a proportional bar.
    private func drawCardStat(_ ctx: GraphicsContext, y: CGFloat, label: String,
                              value: UInt16, maxBar: UInt16, color: UInt16) {
        ctx.gfxText(label, 96, y, 2, UI.ink)
        ctx.gfxText("\(value)", 330, y, 2, UI.ink)
        let bw: CGFloat = 160
        let fw = min(CGFloat(value) * bw / CGFloat(maxBar), bw)
        ctx.fillRoundRect(150, y + 2, bw, 11, 3, UI.track)
        if fw > 2 { ctx.fillRoundRect(150, y + 2, fw, 11, 3, color) }
    }

    /// The little streak flame, drawn as two stacked triangles.
    private func drawFlame(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat,
                           height h: CGFloat = 18) {
        ctx.fillTriangle(x + 8, y, x + 1, y + h, x + 15, y + h, UI.barBad)
        ctx.fillTriangle(x + 8, y + 7, x + 4, y + h, x + 12, y + h, UI.barWarn)
    }

    // MARK: - Pokedex

    /// Port of `renderGallery`. Upstream only redraws the grid when a page turns
    /// (`galleryDirty`) because repainting the panel is slow; here every frame is
    /// redrawn anyway, so that flag has no equivalent.
    private func renderGallery(_ ctx: GraphicsContext, now: UInt64) {
        ctx.fillRect(0, 0, TP.screen, TP.screen, UI.bgDay)
        ctx.fillCircle(TP.cx, TP.cy, 231, UI.bgDay)
        if galleryDetail != 0 {
            renderGalleryDetail(ctx, dex: galleryDetail, now: now)
        } else {
            renderGalleryGrid(ctx)
        }
    }

    /// Whether `dex` passes the active All/Raised/Caught filter. Port of
    /// `galleryDexVisible` from ShadowEnemyx/TamaPoke's fork -- see
    /// upstream-expanded/README.md.
    private func galleryDexVisible(_ dex: Int16) -> Bool {
        guard dex >= 1, dex <= 151 else { return false }
        switch galleryFilter {
        case 1:  return model.pet.isRegistered(dex)
        case 2:  return model.pet.isCaught(dex)
        default: return true
        }
    }

    private func galleryFilteredCount() -> Int {
        if galleryFilter == 0 { return 151 }
        var n = 0
        for dex in Int16(1)...151 where galleryDexVisible(dex) { n += 1 }
        return n
    }

    /// The `index`-th dex number that passes the active filter, 0 when past
    /// the end of the filtered list.
    private func galleryDexAt(_ index: Int) -> Int16 {
        var i = index
        for dex in Int16(1)...151 {
            guard galleryDexVisible(dex) else { continue }
            if i == 0 { return dex }
            i -= 1
        }
        return 0
    }

    private func galleryPageCount() -> Int {
        max(1, (galleryFilteredCount() + 15) / 16)
    }

    private func renderGalleryGrid(_ ctx: GraphicsContext) {
        let pet = model.pet
        // Same size-2-is-too-tall-for-a-12px-gap issue as the Personality
        // page (see renderCardPersonality) -- the R:/C: line drops to size 1.
        ctx.gfxTextCentered("POKEDEX", 22, 3, UI.ink)
        ctx.gfxTextCentered(pet.raisedCaughtLine, 56, 1, UI.ink)

        let filters = [pet.filterAllText, pet.raisedMarkText, pet.filterCaughtText]
        for i in 0..<3 {
            let fx = 74 + CGFloat(i) * 106
            let selected = i == galleryFilter
            ctx.fillRoundRect(fx, 74, 96, 18, 6, selected ? UI.ink : UI.white)
            ctx.drawRoundRect(fx, 74, 96, 18, 6, UI.ink)
            let label = filters[i]
            ctx.gfxText(label, fx + (96 - CGFloat(label.count) * 6) / 2, 80, 1,
                       selected ? UI.bgDay : UI.ink)
        }

        if galleryPage >= galleryPageCount() { galleryPage = 0 }
        for r in 0..<4 {
            for c in 0..<4 {
                let dex = galleryDexAt(galleryPage * 16 + r * 4 + c)
                if dex <= 0 { continue }
                let x = TP.galX + CGFloat(c) * TP.galCell
                let y = TP.galY + CGFloat(r) * TP.galCell
                let registered = pet.isRegistered(dex)
                let caught = pet.isCaught(dex)
                let known = registered || caught

                if let img = TPThumbs.shared.image(dex: dex, silhouette: !known),
                   let sz = TPThumbs.shared.size(dex: dex) {
                    drawThumb(ctx, img, size: sz, cellX: x, cellY: y, scale: 2)
                    if pet.isShinyRegistered(dex) {
                        ctx.gfxText("*", x + 62, y + 4, 2, UI.barWarn)
                    } else if caught && !registered {
                        ctx.gfxText("C", x + 60, y + 6, 1, UI.barWarn)
                    }
                } else {
                    // No atlas bundled: upstream falls back to the bare number.
                    ctx.gfxText("\(dex)", x + 24, y + 32, 2, UI.track)
                }
            }
        }

        let pages = galleryPageCount()
        let dotsX = TP.cx - CGFloat(pages - 1) * 7
        for i in 0..<pages {
            let cx = dotsX + CGFloat(i) * 14
            if i == galleryPage {
                ctx.fillCircle(cx, 436, 4, UI.ink)
            } else {
                ctx.strokeCircle(cx, 436, 3, UI.ink)
            }
        }
    }

    private func renderGalleryDetail(_ ctx: GraphicsContext, dex: Int16, now: UInt64) {
        let pet = model.pet
        let registered = pet.isRegistered(dex)
        let shiny = pet.isShinyRegistered(dex)
        let head = String(format: "N.%03d %@%@", dex, shiny ? "*" : "",
                          registered ? TPDexName(dex) : "???")
        // Upstream shrinks the title rather than letting a long name overflow.
        let size = head.count <= 13 ? 3 : 2
        ctx.gfxTextCentered(head, size == 3 ? 56 : 60, size,
                            registered ? TPDexAccent(dex) : UI.ink)

        // The full sprite when its TPK2 file is bundled: animated and in colour
        // once registered, a frozen silhouette when not.
        if let sprite = TPSprite.load(dex: dex, shiny: shiny),
           let a = sprite[.idle],
           let img = sprite.image(.idle, frame: TPSprite.frameIndex(
               a, elapsedMs: registered ? now : 0, loop: true)) {
            let s = sprite.scale(for: a, max: 6)
            let w = CGFloat(a.w * s), h = CGFloat(a.h * s)
            let rect = CGRect(x: TP.cx - w / 2,
                              y: 300 - CGFloat((a.base > 0 ? a.base : a.h) * s),
                              width: w, height: h)
            if registered {
                ctx.draw(Image(decorative: img, scale: 1).interpolation(.none), in: rect)
            } else {
                // Silhouette: stencil the sprite's shape in ink.
                ctx.drawSilhouette(img, in: rect, UI.ink)
            }
        } else if let img = TPThumbs.shared.image(dex: dex, silhouette: !registered),
                  let sz = TPThumbs.shared.size(dex: dex) {
            drawThumb(ctx, img, size: sz, cellX: TP.cx - TP.galCell, cellY: 135, scale: 4)
        }

        ctx.gfxTextCentered(pet.galleryBackText, 408, 2, UI.ink)
    }

    /// Upstream's `drawThumb`: centre the thumbnail inside a grid cell.
    private func drawThumb(_ ctx: GraphicsContext, _ img: CGImage, size: (w: Int, h: Int),
                           cellX: CGFloat, cellY: CGFloat, scale: Int) {
        let w = CGFloat(size.w * scale), h = CGFloat(size.h * scale)
        ctx.draw(Image(decorative: img, scale: 1).interpolation(.none),
                 in: CGRect(x: cellX + (TP.galCell - w) / 2,
                            y: cellY + (TP.galCell - h) / 2,
                            width: w, height: h))
    }

    private func renderStarterSelect(_ ctx: GraphicsContext) {
        ctx.fillRect(0, 0, TP.screen, TP.screen, UI.bgDay)
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

    /// Port of the firmware's `handleTouch` gesture split. Upstream measures in
    /// its own 466px space and so does this, which keeps the thresholds — 80px
    /// to swipe, 40px to still count as a tap — meaning the same thing on a
    /// phone as on the round panel.
    ///
    /// The duration limits upstream also applies (800ms to swipe, 1500ms to tap)
    /// are dropped: they exist to stop a resting finger on a capacitive panel
    /// from registering, which is not a failure mode here.
    private func onGesture(from: CGPoint, to: CGPoint) {
        let dx = to.x - from.x, dy = to.y - from.y
        if abs(dx) > 80, abs(dy) < 70 {
            onSwipe(dx > 0 ? 1 : -1)
        } else if abs(dy) > 80, abs(dx) < 70 {
            onSwipeV(dy > 0 ? 1 : -1)
        } else if abs(dx) < 40, abs(dy) < 40 {
            onTap(from)
        }
    }

    /// Horizontal swipe: pages the stat card, or opens and pages the Pokedex.
    private func onSwipe(_ dir: Int) {
        let pet = model.pet
        if pet.awaitingStarter { return }

        if screen == .card {           // left advances, matching upstream
            cardPage = min(max(cardPage + (dir > 0 ? -1 : 1), 0), cardPageCount - 1)
            return
        }

        if screen == .idle {
            guard pet.ceremony == TPCeremony.none, choice == .none else { return }
            screen = .gallery
            galleryPage = 0
            galleryDetail = 0
            galleryFilter = 0
            return
        }
        if galleryDetail != 0 {          // in detail: back to the grid
            galleryDetail = 0
            return
        }
        // Swiping left advances a page; backing off page 0 leaves the gallery.
        let next = galleryPage - dir
        if next < 0 {
            screen = .idle
            return
        }
        galleryPage = min(next, galleryPageCount() - 1)
    }

    /// Vertical swipe: up opens the stat card and closes it again, down opens
    /// settings — upstream's clock screen, minus the clock.
    private func onSwipeV(_ dir: Int) {
        let pet = model.pet
        if pet.awaitingStarter { return }
        if screen == .gallery {
            galleryDetail = 0
            screen = .idle
            return
        }
        if screen == .card {
            if dir < 0 { screen = .idle }   // up closes
            return
        }
        if screen == .settings {
            screen = .idle
            return
        }
        guard pet.ceremony == TPCeremony.none, choice == .none,
              model.millis >= confirmUntil, model.millis >= feedMenuUntil else { return }
        if dir > 0 {                        // down: settings
            screen = .settings
            return
        }
        guard !pet.isEgg else { return }    // up: the stat card
        screen = .card
        cardPage = 0
    }

    private func onTap(_ p: CGPoint) {
        switch screen {
        case .gallery:  galleryTap(p)
        case .card:     cardTap(p)
        case .sack:     sackTap(p)
        case .keyboard: keyboardTap(p)
        case .settings: settingsTap(p)
        case .game:     gameTap(p)
        case .idle:     onIdleTap(p)
        }
    }

    /// Port of upstream's card tap handler: the name area renames on page 0,
    /// the sort button/page arrows work the box on page 3, the train button
    /// opens the sack on page 4, and — this is the part that was missing —
    /// anywhere else just closes the card. Upstream's is a plain
    /// `else { cardOpen = false; }`, not a swipe requirement; without it the
    /// only way out was `onSwipeV`, which needs an 80px vertical drag and reads
    /// as "you have to swipe, tapping the hint text does nothing."
    private func cardTap(_ p: CGPoint) {
        if cardPage == 0, p.y < 84 {
            screen = .keyboard
            nameDraft = model.pet.nick
            return
        }
        if cardPage == 3 {
            let pet = model.pet
            if p.x >= 302, p.x <= 408, p.y >= 62, p.y <= 90 {
                pet.cycleBoxSort()
                boxPage = 0
                return
            }
            let pages = pet.boxPageCount(withRowsPerPage: 5)
            if p.x >= 76, p.x <= 170, p.y >= 348, p.y <= 386, boxPage > 0 {
                boxPage -= 1
                return
            }
            if p.x >= 296, p.x <= 390, p.y >= 348, p.y <= 386, boxPage + 1 < pages {
                boxPage += 1
                return
            }
        }
        if cardPage == 4, TP.trainBtn.contains(p) {
            let pet = model.pet
            guard !pet.isEgg, !pet.sleeping, pet.ceremony == TPCeremony.none else {
                screen = .idle
                return
            }
            screen = .sack
            model.startSack()
            return
        }
        screen = .idle
    }

    private func galleryTap(_ p: CGPoint) {
        if galleryDetail != 0 {          // any tap in detail returns to the grid
            galleryDetail = 0
            return
        }
        if p.y < 46 {                    // the header is the way out
            screen = .idle
            return
        }
        if p.y >= 68, p.y < TP.galY {     // All/Raised/Caught filter row
            let f = Int((p.x - 74) / 106)
            if f >= 0, f < 3, p.x >= 74 + CGFloat(f) * 106, p.x <= 170 + CGFloat(f) * 106 {
                galleryFilter = f
                galleryPage = 0
            }
            return
        }
        let c = Int((p.x - TP.galX) / TP.galCell)
        let r = Int((p.y - TP.galY) / TP.galCell)
        guard c >= 0, c <= 3, r >= 0, r <= 3 else { return }
        let dex = galleryDexAt(galleryPage * 16 + r * 4 + c)
        guard dex > 0 else { return }
        galleryDetail = dex
    }

    private func onIdleTap(_ p: CGPoint) {
        let pet = model.pet

        if pet.awaitingStarter {
            for i in 0..<3 {
                let ry = CGFloat(110 + i * 78)
                if p.x >= 70, p.x <= 396, p.y >= ry, p.y <= ry + 70 {
                    pet.chooseStarter(TPStarterDex(i))
                    model.playSfx(.tap)
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

        // The release confirmation swallows the tap and closes either way.
        if model.millis < confirmUntil {
            if TP.releaseYes.contains(p) { pet.release() }
            confirmUntil = 0
            return
        }

        if pet.ceremony != TPCeremony.none { return }  // no buttons during a ceremony

        if model.millis < feedMenuUntil {
            if p.y >= 288, p.y <= 352, p.x >= 101, p.x <= 365 {
                let item = Int((p.x - 101) / 66)
                if item == 3 { pet.feedCandy() } else { pet.feedBerry(UInt8(item)) }
                model.playSfx(.eat)
            }
            feedMenuUntil = 0
            return
        }

        if pet.isEgg {
            pet.eggTap()
            model.playSfx(.tap)
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
            model.playSfx(.tap)
            switch i {
            case 0: feedMenuUntil = model.millis + 6000
            case 1:
                // Upstream's play button opens the ball minigame, which pays out
                // through playResult; playWithPet is the console-command path.
                guard !pet.isEgg, !pet.sleeping, pet.ceremony == TPCeremony.none else { return }
                screen = .game
                model.startBallGame()
            case 2: pet.toggleLight()
            // Upstream washes the creature when the bath *finishes*, not here,
            // so the suds play over a still-dirty creature as they should.
            default: model.startBath()
            }
            return
        }

        // inPetZone(): tapping the creature pets it
        if p.x > 110, p.x < 356, p.y > 95, p.y < 310 {
            pet.caress()
            if !pet.sleeping { model.playSfx(.heart) }
        }
    }
}
