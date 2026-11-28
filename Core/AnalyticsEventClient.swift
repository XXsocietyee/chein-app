import Foundation

/// One queued event, in the mini-program `normalizePayload` shape. No openid, device id, or free text.
public struct AnalyticsQueuedEvent: Codable, Equatable {
    public let eventName: String
    public let anonymousId: String
    public let actorScope: String
    public let sessionId: String
    public let source: String
    public let pagePath: String
    public let bizType: String
    public let bizId: Int?
    public let cityCode: String
    public let propertiesJson: String
    public let idempotencyKey: String
    public let occurredAt: String

    var wire: PlayWireValue {
        .object(["eventName": .string(eventName), "anonymousId": .string(anonymousId), "actorScope": .string(actorScope),
                 "sessionId": .string(sessionId), "source": .string(source), "pagePath": .string(pagePath),
                 "bizType": .string(bizType), "bizId": bizId.map { .int($0) } ?? .null, "cityCode": .string(cityCode),
                 "propertiesJson": .string(propertiesJson), "idempotencyKey": .string(idempotencyKey), "occurredAt": .string(occurredAt)])
    }
}

/// Where the queue lives. Per-account key, as `p3_analytics_queue_v1:<account>`.
public protocol AnalyticsQueueStoring: AnyObject {
    /// Nil is "unreadable", never an empty queue.
    func load(accountID: Int) -> [AnalyticsQueuedEvent]?
    func save(_ queue: [AnalyticsQueuedEvent], accountID: Int) -> Bool
}

public final class AnalyticsDefaultsQueueStore: AnalyticsQueueStoring {
    public static let prefix = "p3_analytics_queue_v1"
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load(accountID: Int) -> [AnalyticsQueuedEvent]? {
        guard let data = defaults.data(forKey: "\(Self.prefix):\(accountID)") else { return [] }
        return try? JSONDecoder().decode([AnalyticsQueuedEvent].self, from: data)
    }
    public func save(_ queue: [AnalyticsQueuedEvent], accountID: Int) -> Bool {
        guard let data = try? JSONEncoder().encode(queue) else { return false }
        defaults.set(data, forKey: "\(Self.prefix):\(accountID)")
        return defaults.data(forKey: "\(Self.prefix):\(accountID)") == data
    }
}

/// Port of `utils/analytics.js`: allow-listed events, a persisted queue of at most 100, batches of at most 50,
/// one batch in flight, and per-batch acknowledgement by exact `accepted` count. Built only when the player
/// grant admits `api/analytics/events/batch`; otherwise the app has no client and tracks nothing.
@MainActor public final class AnalyticsEventClient {
    public static let maxQueue = 100
    public static let maxBatch = 50
    public static let source = "ios_app"
    public static let allowedEvents: Set<String> = [
        "search_submit", "content_view", "content_like", "content_favorite", "content_share", "signup_submit",
        "payment_success", "topic_publish_success", "activity_publish_success", "template_reuse", "coupon_verify",
        "withdrawal_submit", "solo_ticket_purchase", "play_arrive_success", "play_arrive_fallback", "node_abandon",
        "drop_shown", "citymap_view", "citymap_share", "track_record_start", "track_record_finish", "track_to_topic",
        "xp_alloc_done", "become_leader_cta", "play_rec_swap", "play_rec_accept",
        "finish_route_recommendation_shown", "finish_route_recommendation_click",
        "roam_start", "roam_poi_found", "roam_finish", "roam_route_story_shown", "roam_poi_meaning_shown",
        "roam_footprint_hint_shown", "roam_footprint_hint_dismissed", "roam_discover_reward_click",
        "roam_exploreday_reco_shown", "roam_exploreday_reco_click", "roam_share_channel", "roam_share_complete",
        "roam_share_fail", "square_share_complete", "square_share_fail", "chapter_blocks_parse_failed",
        "npc_profile_loaded", "npc_bubble_impression", "npc_chat_open", "npc_chat_submit", "npc_chat_complete", "npc_chat_cancel",
        "finish_offer_shown", "finish_offer_click",
        "stage_enter", "hint_open", "stage_skip", "stage_issue_report", "material_view"
    ]

    private let accountID: Int
    private let store: any AnalyticsQueueStoring
    private let post: ([AnalyticsQueuedEvent]) async -> Bool
    /// False once the session that built this client is gone; late replies then touch nothing.
    private let isCurrent: () -> Bool
    private let now: () -> Date
    private let sessionID: String
    private var sequence = 0
    private var flushing = false

    public init(accountID: Int, store: any AnalyticsQueueStoring, isCurrent: @escaping () -> Bool,
                now: @escaping () -> Date = Date.init, post: @escaping ([AnalyticsQueuedEvent]) async -> Bool) {
        self.accountID = accountID; self.store = store; self.isCurrent = isCurrent; self.now = now; self.post = post
        sessionID = "s_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// `sanitizeProperties`: drop sensitive keys, nulls, long or contact-like strings, and credential/secret patterns.
    public static func sanitize(_ properties: [String: PlayWireValue]) -> [String: PlayWireValue] {
        let sensitive = "(phone|mobile|bank|card|identity|idcard|realname|name|email|address|location|latitude|longitude|openid|unionid|session|token|secret|password|passwd|authorization|bearer|cookie|credential|private_?key|api_?key|access_?key|passcode|otp|keyword|content|comment|message|reply|input|output|text|title|description)"
        var result: [String: PlayWireValue] = [:]
        for (key, value) in properties where key.range(of: sensitive, options: [.regularExpression, .caseInsensitive]) == nil {
            switch value {
            case .integer, .bool: result[key] = value
            case .number(let n) where n.isFinite: result[key] = value
            case .string(let s) where s.count <= 64:
                let mobile = s.range(of: "^1[3-9][0-9]{9}$", options: .regularExpression) != nil
                let email = s.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
                let longDigits = s.range(of: "^[0-9]{15,19}$", options: .regularExpression) != nil
                let bearer = s.range(of: "^(Bearer|Basic)\\s+", options: [.regularExpression, .caseInsensitive]) != nil
                if !mobile && !email && !longDigits && !bearer { result[key] = value }
            default: break
            }
        }
        return result
    }

    /// `track`: false when the event is not allow-listed, the queue is unreadable or full, or the key repeats.
    @discardableResult
    public func track(_ eventName: String, bizType: String = "", bizID: Int? = nil, pagePath: String,
                      properties: [String: PlayWireValue] = [:], idempotencyKey: String? = nil) -> Bool {
        guard Self.allowedEvents.contains(eventName), isCurrent(), var queue = store.load(accountID: accountID),
              queue.count < Self.maxQueue else { return false }
        sequence += 1
        let date = now()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let json = (try? encoder.encode(PlayWireValue.object(Self.sanitize(properties)))).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let event = AnalyticsQueuedEvent(eventName: eventName, anonymousId: "", actorScope: "member:\(accountID)", sessionId: sessionID,
            source: Self.source, pagePath: pagePath, bizType: bizType, bizId: bizID, cityCode: "", propertiesJson: json,
            idempotencyKey: idempotencyKey ?? "\(eventName)_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())",
            occurredAt: formatter.string(from: date))
        if queue.contains(where: { $0.eventName == event.eventName && $0.idempotencyKey == event.idempotencyKey }) {
            Task { await flush() }; return false
        }
        queue.append(event)
        guard store.save(queue, accountID: accountID) else { return false }
        Task { await flush() }
        return true
    }

    /// `flush`: drain in batches; each queued event is tried at most once per flush; an acknowledged batch leaves the queue.
    public func flush() async {
        guard !flushing, isCurrent() else { return }
        flushing = true
        defer { flushing = false }
        var attempted: [AnalyticsQueuedEvent] = []
        while isCurrent() {
            guard let latest = store.load(accountID: accountID) else { return }
            var tried = attempted
            let batch = Array(latest.filter { event in
                if let index = tried.firstIndex(of: event) { tried.remove(at: index); return false }
                return true
            }.prefix(Self.maxBatch))
            guard !batch.isEmpty else { return }
            attempted += batch
            let ok = await post(batch)
            guard isCurrent() else { return }
            if ok {
                guard let current = store.load(accountID: accountID) else { return }
                var sent = batch
                let remaining = current.filter { event in
                    if let index = sent.firstIndex(of: event) { sent.remove(at: index); return false }
                    return true
                }
                guard store.save(remaining, accountID: accountID) else { return }
            }
        }
    }
}

/// U08-02 finish-route card events (`finish-route-recommendation.js trackProperties`).
public struct FinishRouteAnalyticsSource: Equatable {
    public let impressionID: String
    public let sourceActivityID: String?
    public let sourceTopicID: String?
    public let sourceRunID: String?

    /// `impressionSource`: one id ties a click to its impression.
    public init(activityID: Int?, topicID: Int?, runID: Int?, now: Date = Date()) {
        _ = now
        impressionID = "frr-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        sourceActivityID = activityID.map(String.init); sourceTopicID = topicID.map(String.init); sourceRunID = runID.map(String.init)
    }

    public func properties(mode: Int?) -> [String: PlayWireValue] {
        let text: (String?) -> PlayWireValue = { $0.map(PlayWireValue.string) ?? .null }
        return ["mode": mode.map { .int($0) } ?? .null, "placement": .string("play_finish"), "impressionId": .string(impressionID),
                "sourceActivityId": text(sourceActivityID), "sourceTopicId": text(sourceTopicID), "sourceRunId": text(sourceRunID)]
    }
}
