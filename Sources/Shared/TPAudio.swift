//
// Square-wave sound effects, translated from TamaPoke by Quique Tortosa,
// MIT licensed: https://github.com/socquique/TamaPoke (audio.cpp's note tables
// and `playTone`). See LICENSE.
//
// The firmware synthesises these on an ES8311 codec over I2S. There is no such
// chip here, so the same waveform is generated into a buffer and handed to
// AVAudioEngine — the note tables, amplitude, sample rate and anti-click ramps
// are upstream's, so the effects sound like the hardware's rather than like
// something new invented for the phone.
//

import AVFoundation

/// Upstream's `Sfx` enum, in the same order — the ids arrive as raw bytes from
/// the C++ side, so the order is part of the contract.
enum TPSfx: UInt8 {
    case tap = 0, eat, play, heart, hatch, evolve, medal, deny, bye, level
}

final class TPAudio {

    static let shared = TPAudio()

    /// One note: frequency in Hz (0 is a rest) and duration in ms.
    private struct Note {
        let f: Double
        let ms: Int
        init(_ f: Double, _ ms: Int) { self.f = f; self.ms = ms }
    }

    private static let effects: [[Note]] = [
        [Note(880, 35)],                                                    // tap
        [Note(660, 45), Note(0, 12), Note(660, 45)],                        // eat
        [Note(784, 45), Note(988, 60)],                                     // play
        [Note(1047, 55), Note(1319, 90)],                                   // heart
        [Note(523, 80), Note(659, 80), Note(784, 110), Note(1047, 170)],    // hatch
        [Note(523, 80), Note(659, 80), Note(784, 80),
         Note(1047, 90), Note(1319, 230)],                                  // evolve
        [Note(784, 70), Note(0, 25), Note(784, 70),
         Note(0, 25), Note(1047, 200)],                                     // medal
        [Note(300, 110), Note(200, 170)],                                   // deny
        [Note(784, 150), Note(659, 150), Note(523, 280)],                   // bye
        [Note(784, 70), Note(1047, 130)],                                   // level
    ]

    /// Upstream runs the codec at 16kHz; keeping it makes the square waves
    /// alias exactly the way they do on the hardware, which is most of the
    /// Game Boy character.
    private static let sampleRate: Double = 16000
    private static let amplitude: Float = 5000.0 / 32768.0   // upstream's 5000 in Q15

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    /// Rendered once on first use and reused: the effects are fixed waveforms.
    private var cache: [UInt8: AVAudioPCMBuffer] = [:]
    private var running = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Configures the session so effects duck politely and, crucially, do not
    /// stop whatever the player is already listening to.
    func start() {
        guard !running else { return }
        #if os(iOS) || os(watchOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            NSLog("iTamaPoke: audio session unavailable — \(error)")
            return
        }
        #endif
        do {
            try engine.start()
            player.play()
            running = true
        } catch {
            NSLog("iTamaPoke: audio engine failed to start — \(error)")
        }
    }

    func stop() {
        guard running else { return }
        player.stop()
        engine.stop()
        running = false
    }

    /// Queues one effect. Silently does nothing when audio could not start, so
    /// a device that refuses the session never breaks the game.
    func play(_ id: UInt8) {
        guard running, id < Self.effects.count else { return }
        let buffer = cache[id] ?? render(id)
        cache[id] = buffer
        guard let buffer else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    /// Port of `playTone`, run over a whole effect: a square wave per note, with
    /// a 64-sample attack and 96-sample decay so each note does not click.
    private func render(_ id: UInt8) -> AVAudioPCMBuffer? {
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
            // Half a period in samples; 0 means this note is a rest.
            let half = note.f > 0 ? Int(Self.sampleRate / (2 * note.f)) : 0
            var phase = 0
            var high = true

            for i in 0..<total {
                var s: Float = 0
                if half > 0 {
                    s = high ? Self.amplitude : -Self.amplitude
                    if i < 64 {
                        s *= Float(i) / 64                       // attack
                    } else if i > total - 96 {
                        s *= Float(total - i) / 96               // decay
                    }
                    phase += 1
                    if phase >= half {
                        phase = 0
                        high.toggle()
                    }
                }
                out[w] = s
                w += 1
            }
        }
        return buffer
    }
}
