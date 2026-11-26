import AVFoundation
import MapKit
import UIKit

/// Internal seams keep lifecycle regressions independent of networking and the device audio session.
protocol NativePlatformAudioDownloading: AnyObject {
    func start(_ url: URL, completion: @escaping @Sendable (Data?) -> Void)
    func cancel()
}
@MainActor protocol NativePlatformAudioPlaying: AnyObject {
    var delegate: (any AVAudioPlayerDelegate)? { get set }
    func prepareToPlay() -> Bool
    func play() -> Bool
    func pause()
    func stop()
}
extension AVAudioPlayer: NativePlatformAudioPlaying {}
/// P-083 / P-084: position, length and speed for the story player. AVAudioPlayer has them; test stubs need not.
@MainActor protocol NativePlatformAudioTimed: AnyObject {
    var currentTime: TimeInterval { get set }
    var duration: TimeInterval { get }
    var rate: Float { get set }
    var enableRate: Bool { get set }
}
extension AVAudioPlayer: NativePlatformAudioTimed {}

@MainActor struct NativePlatformAudioDependencies {
    let notifications: NotificationCenter
    let makeDownload: (PlatformMediaPolicy) -> any NativePlatformAudioDownloading
    let makePlayer: (Data) throws -> any NativePlatformAudioPlaying
    let activateSession: () throws -> Void
    let deactivateSession: () -> Void
    let hasPlaybackConfiguration: () -> Bool
    let enqueue: @Sendable (@escaping @MainActor @Sendable () -> Void) -> Void

    static var live: Self {
        .init(notifications: .default,
              makeDownload: { ApprovedAudioDownload(policy: $0) },
              makePlayer: { try AVAudioPlayer(data: $0) },
              activateSession: {
                  let session = AVAudioSession.sharedInstance()
                  try session.setCategory(.playback, mode: .spokenAudio)
                  try session.setActive(true)
              },
              deactivateSession: {
                  try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
              },
              hasPlaybackConfiguration: {
                  let session = AVAudioSession.sharedInstance()
                  return session.category == .playback && session.mode == .spokenAudio
              },
              enqueue: { operation in Task { @MainActor in operation() } })
    }
}

/// Bounded, ephemeral HTTPS download. Redirects remain inside the reviewed origin allowlist;
/// no cookies, credentials, cache, or automatic retries. HLS is intentionally unsupported.
private final class ApprovedAudioDownload: NSObject, NativePlatformAudioDownloading, URLSessionDataDelegate, @unchecked Sendable {
    private let policy: PlatformMediaPolicy
    private let limit = 20 * 1024 * 1024
    private var bytes = Data()
    private var session: URLSession?
    private var completion: (@Sendable (Data?) -> Void)?
    init(policy: PlatformMediaPolicy) { self.policy = policy }
    func start(_ url: URL, completion: @escaping @Sendable (Data?) -> Void) {
        guard policy.allows(url) else { completion(nil); return }
        self.completion = completion
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20; configuration.timeoutIntervalForResource = 60
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session; session.dataTask(with: url).resume()
    }
    func cancel() { session?.invalidateAndCancel() }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.map { policy.allows($0) } == true ? request : nil)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode),
              response.url.map({ policy.allows($0) }) == true,
              response.expectedContentLength <= Int64(limit) else { completionHandler(.cancel); return }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard bytes.count + data.count <= limit else { dataTask.cancel(); return }; bytes.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let callback = completion; completion = nil
        callback?(error == nil && !bytes.isEmpty ? bytes : nil); session.finishTasksAndInvalidate()
    }
}

/// Authored only: callers must explicitly inject this after runtime and consent approval.
/// Playback-only category, never requests microphone access. P-083: with `continuesInBackground` (story narration,
/// `storyNarration()`), leaving the app keeps the spoken audio going (Info.plist `audio` background mode); every
/// other signal (calls, unplugged headphones, media reset) still stops or pauses exactly as before.
@MainActor final class NativePlatformAudioDriver: NSObject, PlatformAudioDriving, AVAudioPlayerDelegate {
    private let dependencies: NativePlatformAudioDependencies
    private var player: (any NativePlatformAudioPlaying)?
    private var download: (any NativePlatformAudioDownloading)?
    private var generation = 0
    private var sessionActive = false
    private var event: (@MainActor (PlatformAudioEvent) -> Void)?
    private let lifecycle: NativeAudioLifecycleObservation
    var lifecycleRegistrations: Int { lifecycle.registrations }
    /// OWN-OPT-042.a: whether the loaded player is audible, and the pending call/alarm resume.
    private var audible = false
    private var interruption = PlatformAudioInterruptionResume()
    // Device measurement only: request-to-playing latency, never the source URL.
    private var startInterval: NativePerformanceInterval?
    /// P-083: false keeps the original rule (backgrounding stops and releases).
    var continuesInBackground = false
    /// P-084: the listener's speed; kept across clips of the same driver.
    private var preferredRate: Float = 1
    private var timed: (any NativePlatformAudioTimed)? { player as? any NativePlatformAudioTimed }
    override convenience init() { self.init(dependencies: .live) }
    /// Story narration driver: keeps playing in the background, with Now Playing and remote commands.
    static func storyNarration() -> NativePlatformAudioDriver {
        let driver = NativePlatformAudioDriver()
        driver.continuesInBackground = true
        return driver
    }
    init(dependencies: NativePlatformAudioDependencies) {
        self.dependencies = dependencies
        lifecycle = .init(notifications: dependencies.notifications, enqueue: dependencies.enqueue)
        super.init()
    }
    private func observeLifecycle() {
        lifecycle.observe { [weak self] signal in
            guard let self, self.event != nil else { return }
            if signal == .enteredBackground && self.continuesInBackground { return }
            // setCategory during this driver's own start also emits a route change;
            // an incompatible category takeover remains a stop-worthy event.
            let decision = self.interruption.decide(signal, playing: self.player == nil ? nil : self.audible,
                                                    ownsConfiguration: self.dependencies.hasPlaybackConfiguration())
            switch decision {
            case .ignore: return
            case .stop: self.finish(.interrupted)
            case .pauseForInterruption: self.player?.pause(); self.audible = false; self.event?(.pausedForInterruption)
            case .resume:
                guard self.player?.play() == true else { self.finish(.failed); return }
                self.audible = true; self.event?(.playing)
            }
        }
    }
    func start(source: PlatformMediaSource, policy: PlatformMediaPolicy, event: @escaping @MainActor (PlatformAudioEvent) -> Void) {
        stop(); self.event = event
        startInterval = NativePerformanceSignposts.shared.begin(.audioStartToPlaying)
        guard policy.allows(source.url) else { finish(.failed); return }
        let token = generation
        observeLifecycle()
        let download = dependencies.makeDownload(policy); self.download = download
        let enqueue = dependencies.enqueue
        download.start(source.url) { [weak self] data in
            enqueue { [weak self] in
                guard let self, token == self.generation else { return }
                guard let data else { self.finish(.failed); return }
                do {
                    try self.dependencies.activateSession(); self.sessionActive = true
                    let player = try self.dependencies.makePlayer(data)
                    self.player = player; player.delegate = self
                    if let timed = player as? any NativePlatformAudioTimed { timed.enableRate = true; timed.rate = self.preferredRate }
                    guard player.prepareToPlay(), player.play() else { self.finish(.failed); return }
                    self.audible = true
                    PlatformAudioTransportRegistry.active = self
                    self.startInterval?.end(); self.startInterval = nil
                    self.event?(.playing)
                } catch { self.finish(.failed) }
            }
        }
    }
    func pause() { interruption.userActed(); player?.pause(); audible = false }
    func resume() {
        guard event != nil else { return }
        interruption.userActed()
        guard player?.play() == true else { finish(.failed); return }
        audible = true
        event?(.playing)
    }
    func stop() {
        generation += 1
        startInterval?.end(); startInterval = nil
        lifecycle.invalidate()
        download?.cancel(); download = nil
        player?.stop(); player?.delegate = nil; player = nil; event = nil; audible = false; interruption.userActed()
        if PlatformAudioTransportRegistry.active === self { PlatformAudioTransportRegistry.active = nil }
        let usedSession = sessionActive; sessionActive = false
        if usedSession { dependencies.deactivateSession() }
    }
    private func finish(_ result: PlatformAudioEvent) {
        let callback = event
        stop() // Release before delivering a terminal result, including a reentrant explicit retry.
        callback?(result)
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self, weak player] in
            guard let self, let player, self.player === player else { return }; self.finish(flag ? .ended : .failed)
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self, weak player] in
            guard let self, let player, self.player === player else { return }; self.finish(.failed)
        }
    }
}
/// P-084: the story player's scrubber, ±15 s and speed menu read and drive the loaded clip through this seam.
extension NativePlatformAudioDriver: PlatformAudioTransporting {
    var elapsed: TimeInterval { timed?.currentTime ?? 0 }
    var duration: TimeInterval { max(0, timed?.duration ?? 0) }
    var playbackRate: Float { preferredRate }
    func seek(to time: TimeInterval) {
        guard let timed else { return }
        timed.currentTime = min(max(0, time), max(0, timed.duration))
    }
    func setPlaybackRate(_ rate: Float) {
        preferredRate = min(max(rate, 0.5), 2)
        timed?.rate = preferredRate
    }
}
@MainActor struct NativePlatformMapOpener: PlatformMapOpening {
    func open(_ destination: PlatformMapDestination) async -> Bool {
        guard destination.hasCoordinates, let latitude = destination.latitude, let longitude = destination.longitude else { return false }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
        item.name = destination.name
        // Selected destination only; no location manager, live origin, routing, or permission prompt.
        return item.openInMaps(launchOptions: nil)
    }
}
@MainActor struct NativePlatformAddressCopier: PlatformAddressCopying {
    func copy(_ text: String) throws { LocalPasteboard.copy(text) }
}
