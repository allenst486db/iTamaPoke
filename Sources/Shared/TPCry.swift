//
// A species' cry, previewable from the Pokedex detail view. Exactly like the
// sprites and dex entries, this is Nintendo / Game Freak's audio, so it is
// NOT committed to this repository -- it is read at runtime from
// `mons/psnd<dex>.m4a`, resolved through TPMonsSource: Documents/mons first
// (drop a file in via Files -> On My iPhone -> iTamaPoke), then the app
// bundle. With no such file for a species the play control simply does not
// appear; nothing else about the screen changes.
//
// See Scripts/fetch_cries.sh and README "Cries".
//

import AVFoundation

final class TPCryPlayer: NSObject, AVAudioPlayerDelegate {

    static let shared = TPCryPlayer()

    private override init() {}

    private var player: AVAudioPlayer?
    private var playingDex: Int16?

    private static func url(forDex dex: Int16) -> URL? {
        TPMonsSource.url(name: String(format: "psnd%03d", dex), ext: "m4a")
    }

    /// Whether a cry file is installed for this species -- gates whether the
    /// play control is drawn at all.
    func hasCry(dex: Int16) -> Bool {
        Self.url(forDex: dex) != nil
    }

    /// Starts playback, bound to the same sound-mode setting as every other
    /// effect in the app (OFF mutes cries too, per the user's own call --
    /// this is a preview of the creature, not narration that should survive
    /// muting). Reuses TPAudio's already-running engine/session rather than
    /// standing up a second one: `start()` is idempotent, so this is free
    /// once the SFX engine is already going.
    func play(dex: Int16) {
        guard TPAudio.shared.mode != .off, let url = Self.url(forDex: dex) else { return }
        TPAudio.shared.start()
        stop()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            player = p
            playingDex = dex
            p.play()
        } catch {
            player = nil
            playingDex = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingDex = nil
    }

    /// 0...1 while `dex`'s cry is the one playing, else nil -- nil also
    /// covers "nothing is playing" and "a different species is playing",
    /// both of which should draw the control at rest.
    func progress(forDex dex: Int16) -> Double? {
        guard let p = player, playingDex == dex, p.duration > 0 else { return nil }
        return min(1, p.currentTime / p.duration)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === self.player else { return }
        self.player = nil
        playingDex = nil
    }
}
