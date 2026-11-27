import AVFoundation
import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// PLAY-r11-1: theme and station background music (MP `pages/play/index.js:42-43` volumes, `_startThemeBgm` :4119-4128,
/// `_syncStationBgm` :4175-4192, `_duckBgm` :4092-4098). One page-wide channel: the theme track loops at 0.25 and a station
/// track that differs (same file = same URL without the query) pauses it and loops at 0.35. Narration ducks both.
/// Follows `PlatformBGMPreference`; the player never reads or writes any game fact. Only author media on the run's
/// approved artwork hosts plays (MP `secureOwnMedia`: own media only).
@MainActor final class PlayBackgroundMusic {
    static let shared = PlayBackgroundMusic()
    private static let volume = (theme: Float(0.25), station: Float(0.35))
    private static let ducked = (theme: Float(0.1), station: Float(0.14))

    private var themeURL: URL?
    private var themePlayer: AVQueuePlayer?
    private var themeLooper: AVPlayerLooper?
    private var stationURL: URL?
    private var stationPlayer: AVQueuePlayer?
    private var stationLooper: AVPlayerLooper?
    private var duckSources = Set<String>()
    /// The play page that started the music; a released older page cannot stop a newer one.
    private var owner: UUID?

    func release(owner value: UUID) {
        guard owner == value else { return }
        owner = nil
        stopAll()
    }

    /// MP `secureOwnMedia`: author media upgrades to https; anything else is not played.
    nonisolated static func playableURL(_ raw: String?, approvedHosts: Set<String>) -> URL? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if text.lowercased().hasPrefix("http://") { text = "https://" + text.dropFirst("http://".count) }
        guard let url = URL(string: text), url.scheme?.lowercased() == "https", url.host?.isEmpty == false,
              url.user == nil, url.password == nil,
              let host = url.host?.lowercased(), approvedHosts.contains(host) else { return nil }
        return url
    }
    /// MP `sameFile`: compare without the signed query.
    nonisolated static func sameFile(_ a: URL?, _ b: URL?) -> Bool {
        guard let a, let b, var ca = URLComponents(url: a, resolvingAgainstBaseURL: false),
              var cb = URLComponents(url: b, resolvingAgainstBaseURL: false) else { return false }
        ca.query = nil; cb.query = nil; ca.fragment = nil; cb.fragment = nil
        return ca.url == cb.url
    }

    private var isDucked: Bool { !duckSources.isEmpty }

    private func makeLoop(_ url: URL, volume: Float) -> (AVQueuePlayer, AVPlayerLooper) {
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        let looper = AVPlayerLooper(player: player, templateItem: item)
        player.volume = volume
        return (player, looper)
    }

    /// Started once the run is open and the preference is on (MP starts on 开始游戏 / 撕卡包).
    func startTheme(rawURL: String?, enabled: Bool, approvedHosts: Set<String>, owner value: UUID) {
        owner = value
        guard enabled, let url = Self.playableURL(rawURL, approvedHosts: approvedHosts) else { stopAll(); return }
        if themePlayer != nil, Self.sameFile(themeURL, url) {
            if stationPlayer == nil { themePlayer?.play() }
            return
        }
        stopTheme()
        let (player, looper) = makeLoop(url, volume: isDucked ? Self.ducked.theme : Self.volume.theme)
        themeURL = url; themePlayer = player; themeLooper = looper
        if stationPlayer == nil { player.play() }
    }

    /// Station `playKit.backgroundMusic` (`{audioUrl, loop}`). The same file as the theme keeps the theme going.
    func syncStation(rawURL: String?, loop: Bool, enabled: Bool, approvedHosts: Set<String>) {
        guard enabled, let url = Self.playableURL(rawURL, approvedHosts: approvedHosts) else { stopStation(); return }
        if Self.sameFile(url, themeURL) { stopStation(); themePlayer?.play(); return }
        if stationPlayer != nil, Self.sameFile(stationURL, url) { return }
        stopStation()
        themePlayer?.pause()
        let volume = isDucked ? Self.ducked.station : Self.volume.station
        if loop {
            let (player, looper) = makeLoop(url, volume: volume)
            stationPlayer = player; stationLooper = looper
        } else {
            let player = AVQueuePlayer(items: [AVPlayerItem(url: url)])
            player.volume = volume
            stationPlayer = player
        }
        stationURL = url
        stationPlayer?.play()
    }

    func stopStation() {
        guard stationPlayer != nil else { return }
        stationPlayer?.pause(); stationLooper?.disableLooping()
        stationPlayer = nil; stationLooper = nil; stationURL = nil
        themePlayer?.play()
    }

    private func stopTheme() {
        themePlayer?.pause(); themeLooper?.disableLooping()
        themePlayer = nil; themeLooper = nil; themeURL = nil
    }

    func stopAll() {
        stationPlayer?.pause(); stationLooper?.disableLooping()
        stationPlayer = nil; stationLooper = nil; stationURL = nil
        stopTheme()
    }

    /// Counted by source so two alternating narrations do not lift the music early (MP `_duckBgm`).
    func duck(_ source: String, _ on: Bool) {
        if on { duckSources.insert(source) } else { duckSources.remove(source) }
        themePlayer?.volume = isDucked ? Self.ducked.theme : Self.volume.theme
        stationPlayer?.volume = isDucked ? Self.ducked.station : Self.volume.station
    }
}

/// Ties the music to the play page's lifetime (not to `onDisappear`, which also fires when a station is pushed).
@MainActor final class PlayBackgroundMusicLifetime: ObservableObject {
    let id = UUID()
    deinit {
        let id = id
        Task { @MainActor in PlayBackgroundMusic.shared.release(owner: id) }
    }
}
