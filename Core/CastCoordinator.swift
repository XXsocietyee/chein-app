import Foundation
import Observation

/// Cast state lifted out of `PlayExperienceCoordinator` (that file belongs to P2).
/// P2 calls `adopt` from the nodes read and `invalidate` with the play session.
/// An empty `castConfig` leaves `config` nil, which hides every cast surface.
@MainActor @Observable public final class CastCoordinator {
    public private(set) var config: CastConfig?
    public private(set) var profile: CastPlayerProfile?
    public private(set) var trust = CastTrust()
    /// True while the start-step answer is only on this device. The next readback wins.
    public private(set) var profileLocalOnly = false
    public private(set) var storyPicks: [String: Int] = [:]
    private let service: CastService
    private let currentSession: () -> PlayExperienceSession?
    private var bound: PlayExperienceSession?
    private var topicID: Int?
    private var runID: Int?
    private var picksRunID: Int?
    private var generation: UInt64 = 0

    public init(service: CastService, currentSession: @escaping () -> PlayExperienceSession?) {
        self.service = service
        self.currentSession = currentSession
    }

    public var context: CastStoryContext? {
        config.map { CastStoryContext(config: $0, profile: profile, picks: storyPicks) }
    }

    /// Apply a nodes, route-state or run-session payload. A run change drops local picks
    /// before the server trust replaces the display value.
    public func adopt(raw: PlayWireValue, topicID: Int?, runID: Int?) {
        let facts = CastRuntimeFacts(raw: raw)
        if picksRunID != runID {
            storyPicks = [:]
            picksRunID = runID
        }
        config = facts.config
        trust = facts.trust
        if let profile = facts.profile {
            self.profile = profile
            profileLocalOnly = false
        }
        self.topicID = topicID
        self.runID = runID
        bound = currentSession()
    }

    public func invalidate() {
        generation &+= 1
        config = nil
        profile = nil
        trust = CastTrust()
        profileLocalOnly = false
        storyPicks = [:]
        picksRunID = nil
        topicID = nil
        runID = nil
        bound = nil
    }

    /// The answer shows at once so the run is never blocked. The write runs only when
    /// `.castProfile` is enabled. A failure keeps the local answer and does not retry.
    public func saveProfile(name: String, identityKey: String?) async {
        guard let config, profile == nil else { return }
        let key = config.identity(identityKey)?.key
        let next = CastPlayerProfile(name: config.playerName ? name : nil, identityKey: key)
        profile = next
        profileLocalOnly = true
        guard service.enabled.contains(.castProfile), let runID, runID > 0,
              let session = bound, session == currentSession() else { return }
        let request = generation
        do {
            try await service.saveCastProfile(runID: runID, profile: next, token: session.token)
            guard generation == request, currentSession() == session else { return }
            profileLocalOnly = false
        } catch {
            guard generation == request, currentSession() == session else { return }
            if error as? PlayExperienceError == .unauthorized { invalidate() }
        }
    }

    /// Nil means no voice. The caller hides the control and shows no error.
    public func voiceURL(chapterID: Int, blockKey: String) async -> String? {
        guard config != nil, let topicID, topicID > 0, let session = bound, session == currentSession() else { return nil }
        return try? await service.castVoice(topicID: topicID, chapterID: chapterID, blockKey: blockKey, runID: runID, token: session.token)
    }

    /// The pick shows at once. Trust ticks move locally for display. The write runs only
    /// when `.castBranch` is enabled, and a duplicate adopts the run's original pick.
    public func pick(_ choice: ChapterStoryChoice, optionIndex: Int) async {
        guard let config, choice.options.indices.contains(optionIndex) else { return }
        let key = CastStoryContext.pickKey(chapterID: choice.chapterID, blockKey: choice.blockKey)
        guard storyPicks[key] == nil else { return }
        storyPicks[key] = optionIndex
        trust = trust.applying(choice.options[optionIndex].trust, config: config)
        guard service.enabled.contains(.castBranch), let runID, runID > 0,
              let session = bound, session == currentSession() else { return }
        let request = generation
        do {
            let recorded = try await service.recordCastBranch(runID: runID, chapterID: choice.chapterID,
                                                              blockKey: choice.blockKey, optionIndex: optionIndex, token: session.token)
            guard generation == request, currentSession() == session else { return }
            if let recorded, recorded != optionIndex, choice.options.indices.contains(recorded), storyPicks[key] == optionIndex {
                trust = trust.applying(choice.options[optionIndex].trust, config: config, sign: -1)
                    .applying(choice.options[recorded].trust, config: config)
                storyPicks[key] = recorded
            }
        } catch {
            guard generation == request, currentSession() == session else { return }
            if error as? PlayExperienceError == .unauthorized { invalidate() }
        }
    }
}
