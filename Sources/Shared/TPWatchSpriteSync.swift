//
// Carries sprite files the user dropped into Documents/mons on the phone
// (see TPMonsSource) over to the independent watch app's own Documents/mons.
//
// The watch app is WKRunsIndependentlyOfCompanionApp and cannot read the
// phone's Files-app folder directly -- there is no shared container here, by
// design (see README "Sprites": "a watchOS app cannot read the phone app's
// resources"). WatchConnectivity's file transfer is the one channel that
// actually moves bytes from one to the other without both being signed into
// the same App Group, which free-account provisioning cannot set up anyway.
//
// Triggered automatically on every phone foreground (TamaPokeApp.swift), not
// tied to a settings button -- see syncToWatch() for why a no-op call (the
// common case, once everything already matches) costs next to nothing.
//

import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

#if os(iOS)

/// iPhone side: sends Documents/mons/*.bin to the paired watch.
final class TPWatchSpriteSync: NSObject, WCSessionDelegate {

    static let shared = TPWatchSpriteSync()

    /// name -> byte size already handed to WCSession, persisted so a relaunch
    /// does not requeue a full sprite set (potentially tens of MB) that the
    /// watch already has. Keyed by size rather than a hash: cheap to compute,
    /// and a sprite file a user replaces with a different one is virtually
    /// certain to change size.
    // v2: the v1 key was written at queue time rather than on confirmed
    // delivery (see syncToWatch()/didFinish below), so it can hold entries
    // for transfers that never actually arrived. Renaming rather than
    // clearing it in place, so anyone who already has "sent" entries under
    // the old, wrong semantics gets a clean retry instead of being stuck.
    private static let defaultsKey = "TPWatchSpriteSync.sent.v2"
    private var sent: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Self.defaultsKey) }
    }

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var isWatchReachableForTransfer: Bool {
        WCSession.isSupported() && WCSession.default.activationState == .activated
            && WCSession.default.isPaired && WCSession.default.isWatchAppInstalled
    }

    /// Queues every sprite in Documents/mons the watch doesn't already have.
    /// WCSession spools transfers itself (including across the app being
    /// backgrounded), so this returns immediately -- delivery is not
    /// synchronous. Safe to call on every foreground: an unchanged set costs
    /// nothing past a directory listing and some size comparisons.
    @discardableResult
    func syncToWatch() -> Int {
        guard isWatchReachableForTransfer else { return 0 }
        // Names already mid-transfer aren't requeued -- WCSession would just
        // queue a second copy on top of the one still in flight.
        let inFlight = Set(WCSession.default.outstandingFileTransfers.compactMap {
            $0.file.metadata?["name"] as? String
        })
        let sentAlready = sent
        var n = 0
        for url in TPMonsSource.documentsMonFiles {
            let name = url.lastPathComponent
            guard !inFlight.contains(name) else { continue }
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attrs?[.size] as? Int, sentAlready[name] != size else { continue }
            // Marked "sent" only in didFinish(fileTransfer:), on success --
            // marking it here (at queue time) is what silently broke this
            // the first time: a transfer that never actually completes still
            // got recorded as done, so every later launch skipped it forever
            // instead of retrying.
            WCSession.default.transferFile(url, metadata: ["name": name])
            n += 1
        }
        return n
    }

    // MARK: - WCSessionDelegate (iOS requires these three even though this
    // side only ever sends)

    /// `activate()` is asynchronous, so the very first `syncToWatch()` call
    /// (triggered by the app's first foreground, right after `.shared` is
    /// created and kicks activation off) can run before `activationState`
    /// reaches `.activated` -- it would silently see "not reachable" and skip
    /// everything. Retrying here once activation actually completes closes
    /// that race without the caller needing to know about it.
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        if state == .activated { syncToWatch() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    /// The only place `sent` is written -- see the comment in `syncToWatch()`
    /// on why marking it at queue time instead was the actual bug.
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        guard error == nil, let name = fileTransfer.file.metadata?["name"] as? String else { return }
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileTransfer.file.fileURL.path)
        guard let size = attrs?[.size] as? Int else { return }
        var sentNow = sent
        sentNow[name] = size
        sent = sentNow
    }
}

#elseif os(watchOS)

/// Watch side: receives files sent above and drops them into this app's own
/// Documents/mons, exactly where TPMonsSource already looks.
final class TPWatchSpriteSync: NSObject, WCSessionDelegate {

    static let shared = TPWatchSpriteSync()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let name = file.metadata?["name"] as? String,
              let dir = TPMonsSource.documentsMons
        else { return }
        let dest = dir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)   // a re-sent file replaces its old copy
        try? FileManager.default.copyItem(at: file.fileURL, to: dest)
    }
}

#endif
