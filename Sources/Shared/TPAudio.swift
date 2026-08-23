//
// Chip-tune sound effects, translated from TamaPoke by Quique Tortosa,
// MIT licensed: https://github.com/socquique/TamaPoke, with the effect
// tables and the four-waveform synth (square/triangle/soft/noise, slides,
// per-note volume, four-level sound mode) from the ShadowEnemyx/TamaPoke
// ("Expanded") fork's audio.cpp -- see upstream-expanded/README.md. See LICENSE.
//
// The firmware synthesises these on an ES8311 codec over I2S. There is no such
// chip here, so the same waveforms are generated into a buffer and handed to
// AVAudioEngine — the note tables, amplitudes, sample rate and anti-click ramps
// are the fork's, so the effects sound like the hardware's rather than like
// something new invented for the phone.
//

import AVFoundation

/// The fork's `Sfx` enum, in the same order — the ids arrive as raw bytes from
/// the C++ side, so the order is part of the contract.
enum TPSfx: UInt8, CaseIterable {
    case tap = 0, eat, play, heart, hatch, evolve, medal, deny, bye, level
    case battleWin, battleLoss, catchOK, catchFail, dailyGoal, eventSparkle
    case rest, counter, menu, gameStart, ballBounce, ballMiss, memoStep
    case memoPad0, memoPad1, memoPad2, memoPad3
    case attackQuick, attackHeavy, enemyHit, effective, weakHit
    case minigameOK, minigameBad, lowHP
    case expeditionStart, expeditionFound, expeditionClaim, itemUse
}

/// The fork's `SoundMode`: OFF mutes everything, and each effect declares the
/// quietest mode it still plays at (`minMode` below) — LOW keeps only the
/// important events, FULL plays every click.
enum TPSoundMode: Int {
    case off = 0, low, med, full
}

final class TPAudio {

    static let shared = TPAudio()

    private enum Wave { case square, tri, soft, noise }

    /// One note: frequency in Hz (0 is a rest unless noise), duration in ms,
    /// a linear slide applied across the note, volume 0-100ish, waveform.
    private struct Note {
        let f: Double
        let ms: Int
        let slide: Double
        let vol: Double
        let wave: Wave
    }

    // The fork's note-table macros, kept so the tables below read like its own.
    private static func SQ(_ f: Double, _ ms: Int, _ v: Double) -> Note { Note(f: f, ms: ms, slide: 0, vol: v, wave: .square) }
    private static func TRI(_ f: Double, _ ms: Int, _ v: Double) -> Note { Note(f: f, ms: ms, slide: 0, vol: v, wave: .tri) }
    private static func SOFT(_ f: Double, _ ms: Int, _ v: Double) -> Note { Note(f: f, ms: ms, slide: 0, vol: v, wave: .soft) }
    private static func NS(_ ms: Int, _ v: Double) -> Note { Note(f: 0, ms: ms, slide: 0, vol: v, wave: .noise) }
    private static func SL(_ f: Double, _ ms: Int, _ to: Double, _ v: Double, _ w: Wave) -> Note { Note(f: f, ms: ms, slide: to - f, vol: v, wave: w) }
    private static func SIL(_ ms: Int) -> Note { Note(f: 0, ms: ms, slide: 0, vol: 0, wave: .square) }

    /// The fork's `SFX[]` table, one entry per `TPSfx` case in order.
    private static let effects: [[Note]] = [
        [SQ(1175, 52, 88)],                                                     // tap
        [SOFT(523, 42, 64), SIL(12), SOFT(659, 50, 70)],                        // eat
        [SL(760, 65, 1080, 92, .tri), SQ(1397, 55, 86)],                        // play
        [SOFT(1047, 70, 56), SIL(18), SOFT(1319, 105, 68)],                     // heart
        [TRI(523, 70, 60), TRI(659, 70, 64), TRI(784, 95, 68),
         SL(880, 190, 1320, 72, .tri)],                                         // hatch
        [SL(392, 100, 560, 58, .tri), SL(523, 100, 740, 62, .tri),
         SL(659, 110, 960, 66, .tri), SL(880, 210, 1480, 76, .soft)],           // evolve
        [TRI(784, 60, 66), SIL(22), TRI(1047, 68, 72), SIL(20),
         SL(1175, 210, 1568, 78, .tri)],                                        // medal
        [SL(330, 120, 230, 70, .square), SL(220, 150, 160, 64, .square)],       // deny
        [SOFT(784, 130, 58), SOFT(659, 140, 55), SL(523, 260, 392, 54, .soft)], // bye
        [TRI(784, 65, 64), TRI(1047, 80, 70), SOFT(1319, 130, 70)],             // level
        [TRI(659, 58, 66), TRI(784, 58, 68), TRI(988, 80, 72),
         SL(1175, 170, 1568, 76, .tri)],                                        // battleWin
        [SL(392, 140, 330, 66, .soft), SL(330, 140, 247, 62, .soft),
         SOFT(196, 220, 56)],                                                   // battleLoss
        [TRI(784, 55, 68), TRI(988, 65, 72), SL(1175, 180, 1568, 78, .tri)],    // catchOK
        [NS(55, 50), SL(523, 80, 392, 64, .square), SIL(16),
         SL(392, 180, 247, 62, .soft)],                                         // catchFail
        [TRI(1175, 50, 68), SIL(22), TRI(1568, 70, 74), SOFT(1760, 95, 68)],    // dailyGoal
        [NS(35, 36), TRI(1568, 42, 56), TRI(1976, 62, 60), SIL(18),
         TRI(1760, 56, 54)],                                                    // eventSparkle
        [SL(523, 125, 392, 48, .soft), SOFT(330, 170, 42)],                     // rest
        [SL(784, 75, 1175, 62, .tri), SIL(16), SQ(1568, 70, 74), NS(40, 42)],   // counter
        [TRI(988, 56, 84), SQ(1319, 62, 90)],                                   // menu
        [TRI(659, 58, 72), TRI(880, 64, 78), SQ(1175, 74, 82)],                 // gameStart
        [SL(820, 42, 520, 72, .square)],                                        // ballBounce
        [NS(55, 56), SL(360, 110, 210, 68, .soft)],                             // ballMiss
        [SQ(1047, 54, 68)],                                                     // memoStep
        [SOFT(349, 82, 76)],                                                    // memoPad0
        [TRI(523, 82, 76)],                                                     // memoPad1
        [TRI(784, 82, 76)],                                                     // memoPad2
        [SQ(1047, 82, 76)],                                                     // memoPad3
        [SL(980, 42, 1320, 90, .tri), SQ(1760, 38, 82)],                        // attackQuick
        [NS(36, 46), SL(330, 74, 700, 92, .square), SQ(880, 52, 86)],           // attackHeavy
        [SL(300, 70, 190, 82, .square), NS(38, 44)],                            // enemyHit
        [TRI(988, 48, 82), TRI(1319, 54, 90), SQ(1760, 64, 86)],                // effective
        [SOFT(420, 70, 58), SOFT(360, 90, 50)],                                 // weakHit
        [SL(1047, 46, 1568, 88, .tri), TRI(1760, 42, 78)],                      // minigameOK
        [NS(42, 52), SL(300, 95, 180, 70, .soft)],                              // minigameBad
        [SQ(740, 70, 74), SIL(38), SQ(740, 70, 74)],                            // lowHP
        [TRI(523, 52, 64), TRI(659, 62, 70), SL(784, 115, 1047, 72, .tri)],     // expeditionStart
        [TRI(784, 55, 70), TRI(1047, 58, 76), TRI(1319, 65, 78),
         SOFT(1568, 130, 72)],                                                  // expeditionFound
        [SOFT(988, 55, 66), TRI(1319, 70, 74), SL(1568, 115, 1976, 76, .tri)],  // expeditionClaim
        [SOFT(659, 48, 62), SL(784, 95, 1175, 70, .tri)],                       // itemUse
    ]

    /// The fork's `SFX_MIN_MODE[]`: the quietest sound mode each effect still
    /// plays at. `.low` marks the important events that survive even "poco".
    private static let minMode: [TPSoundMode] = [
        .full, .med, .full, .med, .low,   // tap, eat, play, heart, hatch
        .low, .low, .low, .low, .low,     // evolve, medal, deny, bye, level
        .low, .low, .low, .low, .low,     // battleWin/Loss, catchOK/Fail, dailyGoal
        .med, .med, .med, .full, .med,    // eventSparkle, rest, counter, menu, gameStart
        .full, .full, .full,              // ballBounce, ballMiss, memoStep
        .full, .full, .full, .full,       // memoPad0-3
        .full, .full, .full, .med, .full, // attackQuick/Heavy, enemyHit, effective, weakHit
        .med, .med, .low,                 // minigameOK/Bad, lowHP
        .med, .low, .med, .med,           // expeditionStart/Found/Claim, itemUse
    ]

    /// The fork's `modeGainPct` — FULL is deliberately over 100%.
    private static func gainPct(_ mode: TPSoundMode) -> Double {
        switch mode {
        case .low: return 58
        case .med: return 82
        case .full: return 118
        case .off: return 0
        }
    }

    /// Upstream runs the codec at 16kHz; keeping it makes the waveforms alias
    /// exactly the way they do on the hardware, which is most of the character.
    private static let sampleRate: Double = 16000
    /// The fork's base amplitude (9200 in Q15), scaled per note by vol/100 and
    /// per mode by gainPct/100 at render time.
    private static let baseAmp: Float = 9200.0 / 32768.0

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    /// Rendered per (effect, mode) on first use and reused: fixed waveforms.
    private var cache: [UInt16: AVAudioPCMBuffer] = [:]
    private var running = false
    /// watchOS activates the session asynchronously; these hold the gap so the
    /// effect that triggered `start()` is not swallowed while we wait.
    private var activating = false
    private var pending: UInt8?
    /// The active sound mode, set by GameModel; gates and scales every effect.
    var mode: TPSoundMode = .full

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Configures the session so effects duck politely and, crucially, do not
    /// stop whatever the player is already listening to.
    func start() {
        guard !running, !activating else { return }
        #if os(watchOS)
        // `.playback` was tried here first to get the effects out of the
        // speaker at all, but that category is defined to ignore the mute
        // switch -- appropriate for a music app, wrong for game SFX. `.ambient`
        // is the one that honors mute, same as the iOS branch below; the
        // speaker stayed silent before because activation wasn't being
        // awaited (see below), not because of the category.
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient,
                                                            mode: .default,
                                                            options: [.mixWithOthers])
        } catch {
            NSLog("iTamaPoke: audio session unavailable — \(error)")
            return
        }
        activating = true
        AVAudioSession.sharedInstance().activate(options: []) { [weak self] ok, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.activating = false
                guard ok else {
                    NSLog("iTamaPoke: audio session refused activation — \(String(describing: error))")
                    self.pending = nil
                    return
                }
                self.startEngine()
            }
        }
        #else
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            NSLog("iTamaPoke: audio session unavailable — \(error)")
            return
        }
        #endif
        startEngine()
        #endif
    }

    private func startEngine() {
        guard !running else { return }
        do {
            try engine.start()
            player.play()
            running = true
        } catch {
            NSLog("iTamaPoke: audio engine failed to start — \(error)")
            pending = nil
            return
        }
        if let id = pending {
            pending = nil
            play(id)
        }
    }

    func stop() {
        pending = nil
        guard running else { return }
        player.stop()
        engine.stop()
        running = false
        #if os(watchOS)
        // Hand the route back, or the watch keeps the app marked as the active
        // audio client and stays out of its normal silent behaviour.
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }

    /// Queues one effect, honouring the sound mode the fork's audioTask honours:
    /// nothing in OFF, and each effect's own `minMode` above that. Silently does
    /// nothing when audio could not start, so a device that refuses the session
    /// never breaks the game.
    func play(_ id: UInt8) {
        guard id < Self.effects.count, mode != .off,
              mode.rawValue >= Self.minMode[Int(id)].rawValue else { return }
        // Held rather than dropped only while watchOS is mid-activation; with no
        // session coming this stays nil and the effect is discarded as before.
        guard running else {
            if activating { pending = id }
            return
        }
        let key = UInt16(id) << 2 | UInt16(mode.rawValue)
        let buffer = cache[key] ?? render(id, mode: mode)
        cache[key] = buffer
        guard let buffer else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    /// The fork's LFSR noise source (`nextNoise`), stepped per sample.
    private var noiseState: UInt16 = 0xACE1
    private func nextNoise() -> Float {
        noiseState = (noiseState >> 1) ^ ((noiseState & 1) != 0 ? 0xB400 : 0)
        return (noiseState & 1) != 0 ? 1 : -1
    }

    /// Port of the fork's `playTone` run over a whole effect: waveform per
    /// note, linear frequency slide, a 64-sample attack and 96-sample decay so
    /// notes do not click, and the mode's gain baked into the amplitude.
    private func render(_ id: UInt8, mode: TPSoundMode) -> AVAudioPCMBuffer? {
        let notes = Self.effects[Int(id)]
        let frames = notes.reduce(0) { $0 + Int(Self.sampleRate) * $1.ms / 1000 }
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(frames))
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(frames)
        guard let out = buffer.floatChannelData?[0] else { return nil }

        var w = 0
        for note in notes {
            let total = Int(Self.sampleRate) * note.ms / 1000
            let amp = Self.baseAmp * Float(note.vol) / 100 * Float(Self.gainPct(mode)) / 100
            var phase = 0

            for i in 0..<total {
                var s: Float = 0
                if note.wave == .noise || note.f > 0 {
                    // The slide moves the frequency linearly across the note,
                    // clamped to 20Hz like the fork's playTone.
                    var curF = note.f
                    if note.slide != 0, total > 1 {
                        curF = max(20, note.f + note.slide * Double(i) / Double(total))
                    }
                    let period = max(2, curF > 0 ? Int(Self.sampleRate / curF) : 2)
                    s = oscSample(note.wave, phase: phase, period: period, amp: amp)
                    if i < 64 {
                        s *= Float(i) / 64                       // attack
                    } else if i > total - 96 {
                        s *= Float(total - i) / 96               // decay
                    }
                    phase += 1
                }
                out[w] = s
                w += 1
            }
        }
        return buffer
    }

    /// The fork's `oscSample`: one sample of the chosen waveform.
    private func oscSample(_ wave: Wave, phase: Int, period: Int, amp: Float) -> Float {
        if wave == .noise { return nextNoise() * amp }
        guard period > 1 else { return 0 }
        let p = phase % period
        switch wave {
        case .tri:
            let half = period / 2
            if p < half {
                return -amp + (2 * amp * Float(p)) / Float(half)
            }
            return amp - (2 * amp * Float(p - half)) / Float(period - half)
        case .soft:
            // A symmetric triangle at 3/4 amplitude — the fork's mellower voice.
            let half = period / 2
            let q = p < half ? p : period - p
            return ((2 * amp * Float(q)) / Float(half) - amp) * 0.75
        default:
            return p < period / 2 ? amp : -amp
        }
    }
}
