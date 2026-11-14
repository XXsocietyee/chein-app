import Foundation

/// Port of `utils/npc-roam-gate.js`. Reserve, then charge only after the line was shown.
/// start/25/80/end once each; first-light POI at most twice and 90 s apart; any two lines 45 s apart (end exempt).
public struct G6RoamNPCGate: Equatable, Sendable {
    public static let quota: [String: Int] = [
        "roam_start": 1, "roam_poi_first_light": 2, "roam_milestone_25": 1, "roam_milestone_80": 1, "roam_end": 1
    ]
    public static let globalGapMs: Double = 45_000
    public static let poiGapMs: Double = 90_000
    public static let maxFails = 2

    public enum Refusal: String, Equatable, Sendable {
        case unknownEvent = "unknown_event", inFlight = "in_flight", failCapped = "fail_capped"
        case quota, globalGap = "global_gap", poiGap = "poi_gap"
    }

    private var shown: [String: Int] = [:]
    private var fails: [String: Int] = [:]
    private var pending: Set<String> = []
    private var lastShownAt = -Double.infinity
    private var lastPoiAt = -Double.infinity

    public init() {}

    public mutating func tryAcquire(_ eventType: String, now: Double) -> Refusal? {
        guard let limit = Self.quota[eventType] else { return .unknownEvent }
        if pending.contains(eventType) { return .inFlight }
        if fails[eventType, default: 0] >= Self.maxFails { return .failCapped }
        if shown[eventType, default: 0] >= limit { return .quota }
        if eventType != "roam_end", now - lastShownAt < Self.globalGapMs { return .globalGap }
        if eventType == "roam_poi_first_light", now - lastPoiAt < Self.poiGapMs { return .poiGap }
        pending.insert(eventType)
        return nil
    }

    public mutating func confirmShown(_ eventType: String, now: Double) {
        pending.remove(eventType)
        shown[eventType, default: 0] += 1
        lastShownAt = now
        if eventType == "roam_poi_first_light" { lastPoiAt = now }
    }

    public mutating func releaseUnshown(_ eventType: String) {
        pending.remove(eventType)
        fails[eventType, default: 0] += 1
    }
}

/// Port of `utils/roam-npc-coordinator.js`. The page only dispatches domain events.
/// The flag is read live on every call and never latched. Two failed profile reads silence the session.
@MainActor public final class G6RoamNPCCoordinator {
    public enum Event: Equatable, Sendable {
        case sessionStarted
        case sessionFinished
        case poiVisitRecorded(firstVisit: Bool, poiKey: String?)
        case uniqueTileCountChanged(Int)
    }

    public struct Ports {
        public var now: @MainActor () -> Double
        public var sleep: @MainActor (Double) async -> Void
        public var featureOn: @MainActor () -> Bool
        /// Profile id of `data.npcs[0]`, or nil when the read failed or had none.
        public var fetchProfile: @MainActor () async -> String?
        /// Reviewed line for (profileId, eventType), or nil.
        public var fetchLine: @MainActor (String, String) async -> String?
        /// Show (or hide with nil) the top bubble. False means the render failed.
        public var showBubble: @MainActor (String?) -> Bool
        public var showFinishLine: @MainActor (String) -> Void
        /// `analytics.js` names only. The page supplies the session id; the line text stays out.
        public var analytics: (@MainActor (String, Int) -> Void)?

        public init(now: @escaping @MainActor () -> Double, sleep: @escaping @MainActor (Double) async -> Void,
                    featureOn: @escaping @MainActor () -> Bool,
                    fetchProfile: @escaping @MainActor () async -> String?, fetchLine: @escaping @MainActor (String, String) async -> String?,
                    showBubble: @escaping @MainActor (String?) -> Bool, showFinishLine: @escaping @MainActor (String) -> Void,
                    analytics: (@MainActor (String, Int) -> Void)? = nil) {
            self.now = now; self.sleep = sleep; self.featureOn = featureOn; self.fetchProfile = fetchProfile
            self.fetchLine = fetchLine; self.showBubble = showBubble; self.showFinishLine = showFinishLine
            self.analytics = analytics
        }
    }

    public static let bubbleMs: Double = 6_000
    public static let profileRetryMs: Double = 5_000
    public static let maxQueue = 3

    private let ports: Ports
    private var gate = G6RoamNPCGate()
    private var disposed = false
    private var giveUp = false
    private var profileID: String?
    private var profileTried = 0
    private var pendingEvents: [Event] = []
    private var hideTask: Task<Void, Never>?
    private var seenPoi: Set<String> = []
    private var inFlight: [Task<Void, Never>] = []
    /// `roam-npc-coordinator.js` `sessionId`. Zero is not a business id.
    public private(set) var analyticsSessionID = 0

    public init(ports: Ports) { self.ports = ports }

    public func setAnalyticsSessionID(_ id: Int) { analyticsSessionID = id }

    public var isSilenced: Bool { giveUp }

    public func start() {
        if disposed || giveUp { return }
        if !ports.featureOn() { return }
        if profileID != nil || profileTried > 0 { return }
        loadProfile()
    }

    private func loadProfile() {
        profileTried += 1
        track(Task { [weak self] in
            guard let self else { return }
            let id = await self.ports.fetchProfile()
            if self.disposed { return }
            guard let id, !id.isEmpty else {
                if self.profileTried < 2 {
                    await self.ports.sleep(Self.profileRetryMs)
                    if self.disposed { return }
                    self.loadProfile()
                    return
                }
                self.giveUp = true
                self.pendingEvents = []
                return
            }
            self.profileID = id
            self.ports.analytics?("npc_profile_loaded", self.analyticsSessionID)
            let queued = self.pendingEvents
            self.pendingEvents = []
            queued.forEach { self.dispatch($0) }
        })
    }

    public func dispatch(_ event: Event) {
        if disposed || giveUp { return }
        if !ports.featureOn() { return }
        guard profileID != nil else {
            start()
            if pendingEvents.count < Self.maxQueue { pendingEvents.append(event) }
            return
        }
        switch event {
        case .poiVisitRecorded(let firstVisit, let poiKey):
            guard firstVisit, let poiKey, !poiKey.isEmpty, !seenPoi.contains(poiKey) else { return }
            seenPoi.insert(poiKey)
            fire("roam_poi_first_light", finish: false)
        case .uniqueTileCountChanged(let count):
            let target = count >= 80 ? "roam_milestone_80" : (count >= 25 ? "roam_milestone_25" : nil)
            guard let target else { return }
            fire(target, finish: false)
        case .sessionStarted:
            fire("roam_start", finish: false)
        case .sessionFinished:
            fire("roam_end", finish: true)
        }
    }

    private func fire(_ eventType: String, finish: Bool) {
        guard let profileID, gate.tryAcquire(eventType, now: ports.now()) == nil else { return }
        track(Task { [weak self] in
            guard let self else { return }
            let line = await self.ports.fetchLine(profileID, eventType)
            if self.disposed { self.gate.releaseUnshown(eventType); return }
            guard let line, !line.isEmpty else { self.gate.releaseUnshown(eventType); return }
            if finish {
                self.ports.showFinishLine(line)
                self.gate.confirmShown(eventType, now: self.ports.now())
                self.ports.analytics?("npc_bubble_impression", self.analyticsSessionID)
                return
            }
            guard self.ports.showBubble(line) else { self.gate.releaseUnshown(eventType); return }
            self.gate.confirmShown(eventType, now: self.ports.now())
            self.ports.analytics?("npc_bubble_impression", self.analyticsSessionID)
            self.hideTask?.cancel()
            self.hideTask = Task { [weak self] in
                guard let self else { return }
                await self.ports.sleep(Self.bubbleMs)
                guard !Task.isCancelled, !self.disposed else { return }
                _ = self.ports.showBubble(nil)
            }
        })
    }

    public func dispose() {
        if disposed { return }
        disposed = true
        hideTask?.cancel()
        hideTask = nil
        pendingEvents = []
    }

    /// Test hook: wait for every request this coordinator started.
    public func settle() async {
        while !inFlight.isEmpty {
            let tasks = inFlight
            inFlight = []
            for task in tasks { await task.value }
        }
    }

    private func track(_ task: Task<Void, Never>) { inFlight.append(task) }

    /// `data.npcs[0].profileId` for the roam layer.
    public static func profileID(in envelope: G6Envelope) -> String? {
        guard envelope.ok, let data = envelope.data as? [String: Any],
              let npcs = data["npcs"] as? [Any], let first = npcs.first as? [String: Any] else { return nil }
        return G6JSON.text(first["profileId"])
    }

    /// `data.line`, only when the server had a reviewed line.
    public static func line(in envelope: G6Envelope) -> String? {
        guard envelope.ok, let data = envelope.data as? [String: Any], let line = data["line"] as? String, !line.isEmpty else { return nil }
        return line
    }
}

/// Topic page "main characters": NPCs that already passed review on the merchant stops (`scope=node`).
public enum G6StoryCharacters {
    public struct Ask: Equatable, Sendable {
        public let nodeID: Int
        public let place: String
    }

    public struct Character: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let avatar: String?
        public let place: String?
    }

    /// At most four stops that list a registration merchant, in chapter order.
    public static func asks(_ chapters: [TopicChapter]) -> [Ask] {
        var asks: [Ask] = []
        for chapter in chapters {
            for node in chapter.nodes where node.id > 0 && !node.merchants.isEmpty && asks.count < 4 {
                asks.append(Ask(nodeID: node.id, place: node.name.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
        return asks
    }

    /// `data.npcs` rows paired with their stop name. Nil when the read failed or `npcs` is not an array.
    public static func rows(in envelope: G6Envelope, place: String) -> [(npc: [String: Any], place: String)]? {
        guard envelope.ok, let data = envelope.data as? [String: Any], let list = data["npcs"] as? [Any] else { return nil }
        return list.compactMap { $0 as? [String: Any] }.map { (npc: $0, place: place) }
    }

    /// `topic-motion.js` `buildChars`: dedupe by name, keep the first eight. Nameless rows are dropped.
    public static func build(_ rows: [(npc: [String: Any], place: String)]) -> [Character] {
        var seen: Set<String> = []
        var out: [Character] = []
        for row in rows {
            guard let name = G6JSON.text(row.npc["name"]), !seen.contains(name) else { continue }
            seen.insert(name)
            let key = "c-" + (G6JSON.text(row.npc["profileId"]) ?? name)
            let place = row.place.trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(Character(id: key, name: name, avatar: G6JSON.text(row.npc["avatar"]), place: place.isEmpty ? nil : place))
        }
        return Array(out.prefix(8))
    }
}

/// The shared chat shell (`cy-npc-chat`). Request id is a lowercase v4 UUID; replies are only reviewed full text.
public enum G6NPCChat {
    public static let maxMessageCodePoints = 300

    public enum State: String, Equatable, Sendable {
        case delivering = "DELIVERING", rateLimited = "RATE_LIMITED", blocked = "BLOCKED", checking = "CHECKING", failed = "FAILED"
        case notFound = "NOT_FOUND"
    }

    public struct Reply: Equatable, Sendable {
        public let state: State
        public let safeText: String?
    }

    public static func isRequestID(_ value: String) -> Bool { G6AIThemeDraft.isUUID(value) }

    /// `_onResponse` / `_onReadback`. A reply for another request id is treated as a network failure.
    public static func reply(_ envelope: G6Envelope, requestID: String) -> Reply {
        guard !envelope.netFail, let payload = envelope.data as? [String: Any],
              payload["requestId"] as? String == requestID else { return Reply(state: .failed, safeText: nil) }
        let text = (payload["safeText"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let outcome = payload["outcomeStatus"] as? String
        if envelope.ok, outcome == "SUCCEEDED", payload["safetyDecision"] as? String == "PASS" {
            return Reply(state: .delivering, safeText: text ?? "")
        }
        if envelope.ok, outcome == "NOT_FOUND" { return Reply(state: .notFound, safeText: text) }
        if !envelope.ok { return Reply(state: .failed, safeText: text) }
        switch payload["errorCode"] as? String {
        case "RATE_LIMITED": return Reply(state: .rateLimited, safeText: text)
        case "INPUT_BLOCK", "OUTPUT_BLOCK": return Reply(state: .blocked, safeText: text)
        case "REQUEST_IN_PROGRESS", "REQUEST_OUTCOME_UNKNOWN": return Reply(state: .checking, safeText: text)
        default: return Reply(state: outcome == "PROCESSING" ? .checking : .failed, safeText: text)
        }
    }
}
