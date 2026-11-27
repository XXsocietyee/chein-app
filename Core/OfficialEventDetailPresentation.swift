import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Source: pages/activity/official-detail (_decorate, _cta, _countdown, MISSION_TYPE_TEXT,
// CATEGORY_TEXT, parseContentCards). Display only: nothing here grants participation,
// navigation or a write, and timezone-less text dates are never reinterpreted.

/// Server text shown verbatim, a catalog key, or the source "活动任务 N" fallback.
public enum OfficialDetailText: Equatable {
    case verbatim(String), key(String), numberedTask(Int)
}
public enum OfficialDetailFactValue: Equatable {
    case verbatim(String), key(String), days(Int), hours(Int)
}
/// `hidden`: the MP fact has no sub line (only my-progress v2 and scope carry one).
public enum OfficialDetailFactSub: Equatable {
    case key(String), countdown(OfficialEventCountdown), hidden
}
public struct OfficialDetailFact: Equatable, Identifiable {
    public let id: String
    public let labelKey: String
    public let value: OfficialDetailFactValue
    public let sub: OfficialDetailFactSub
}
public enum OfficialDetailMissionAction: Equatable {
    case verified, verify, automatic, unsupported
    public var key: String {
        switch self {
        case .verified: return "official.task.verified"
        case .verify: return "official.detailParity.mission.verify"
        case .automatic: return "official.detailParity.mission.automatic"
        case .unsupported: return "official.detailParity.mission.unsupported"
        }
    }
}
public struct OfficialDetailMission: Equatable {
    public let index: Int
    public let title: OfficialDetailText
    public let description: OfficialDetailText
    public let supported: Bool
    public let action: OfficialDetailMissionAction
    public let binding: OfficialMissionBinding?
    public init(_ mission: OfficialMission, index: Int) {
        let meta = Self.meta(mission.type)
        let title = mission.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = (mission.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.index = index
        self.title = title.isEmpty ? .key(meta?.label ?? "official.detailParity.mission.unknown") : .verbatim(title)
        self.description = description.isEmpty
            ? .key(meta?.action ?? "official.detailParity.mission.unknownAction") : .verbatim(description)
        supported = meta?.supported == true
        if mission.complete == true { action = .verified }
        else if !supported { action = .unsupported }
        else { action = mission.canVerifyArrival == true ? .verify : .automatic }
        binding = mission.binding
    }
    /// Backend publish/verify support per missionType; unknown types are never supported.
    public static func isSupported(_ type: String?) -> Bool { meta(type)?.supported == true }
    private static func meta(_ type: String?) -> (label: String, action: String, supported: Bool)? {
        switch type {
        case "ROAM_POI_ARRIVAL":
            return ("activityR3.official.detail.mission.roamPoi", "official.detailParity.mission.unsupportedAction", false)
        case "EVENT_POINT_ARRIVAL":
            return ("activityR3.official.detail.mission.eventPoint", "activityR3.official.detail.mission.eventPointAction", true)
        case "THEME_VERIFIED_FINISH":
            return ("official.detailParity.mission.theme", "official.detailParity.mission.themeAction", true)
        case "ROAM_SESSION_AREA":
            return ("official.detailParity.mission.roamArea", "official.detailParity.mission.unsupportedAction", false)
        default: return nil
        }
    }
}
/// Source parseContentCards: v1 `contentJson.tasks`, strings or objects, never completed.
public struct OfficialDetailCard: Equatable {
    public let index: Int
    public let title: OfficialDetailText
    public let description: OfficialDetailText
    public static func cards(contentJSON: String?) -> [OfficialDetailCard] {
        guard let data = contentJSON?.data(using: .utf8),
              let content = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let tasks = content["tasks"] as? [Any] else { return [] }
        return tasks.enumerated().map { (index: Int, task: Any) -> OfficialDetailCard in
            if let text = task as? String {
                return OfficialDetailCard(index: index, title: .verbatim(text), description: .numberedTask(index + 1))
            }
            let map: [String: Any] = (task as? [String: Any]) ?? [:]
            func first(_ keys: [String]) -> String? {
                keys.compactMap { map[$0] as? String }.first(where: { !$0.isEmpty })
            }
            return OfficialDetailCard(
                index: index,
                title: first(["title", "name"]).map { OfficialDetailText.verbatim($0) } ?? .numberedTask(index + 1),
                description: first(["description", "shortDescription", "type"]).map { OfficialDetailText.verbatim($0) }
                    ?? .key("official.detailParity.card.defaultDescription"))
        }
    }
}
/// Source `_cta` text; the iOS label never navigates. Signup stays with OfficialParticipationActions.
public enum OfficialDetailCTA: Equatable {
    case offline, ended, settling, paused, participationInvalid, roamArrival, themeSync, unsupportedTasks, waitTasks, roamLight, explore
    case signedWaiting, signed, signup, registrationSoon, unavailable
    public var key: String {
        switch self {
        case .offline: return "activityR3.official.detail.cta.offline"
        case .ended: return "official.detailParity.cta.ended"
        case .settling: return "activityR3.official.detail.cta.settling"
        case .paused: return "official.detailParity.cta.paused"
        case .participationInvalid: return "activityR3.official.detail.participationInvalid"
        case .roamArrival: return "official.detailParity.cta.roamArrival"
        case .themeSync: return "official.detailParity.cta.themeSync"
        case .unsupportedTasks: return "official.detailParity.cta.unsupportedTasks"
        case .waitTasks: return "official.detailParity.cta.waitTasks"
        case .roamLight: return "official.detailParity.cta.roamLight"
        case .explore: return "official.detailParity.cta.explore"
        case .signedWaiting: return "official.detailParity.cta.signedWaiting"
        case .signed: return "official.detailParity.cta.signed"
        case .signup: return "official.detailParity.cta.signup"
        case .registrationSoon: return "official.detailParity.cta.registrationSoon"
        case .unavailable: return "official.detailParity.cta.unavailable"
        }
    }
    /// The source `type` is not wait/ended, so its page would act on a tap.
    public var isSourceAction: Bool {
        switch self {
        case .roamArrival, .themeSync, .roamLight, .explore, .signup: return true
        default: return false
        }
    }
}
/// Source detail load outcome: only an explicit missing event offers the list exit.
public enum OfficialDetailLoadFailure: Equatable {
    case unavailable, network, other
    public init(_ error: Error) {
        if let failure = error as? OfficialReadFailure, failure == .unavailable { self = .unavailable }
        else if error is URLError { self = .network }
        else { self = .other }
    }
}
public extension OfficialEvent {
    /// Source CATEGORY_TEXT; absent or unknown categories read as an official event.
    var categoryKey: String {
        switch category {
        case "city_light": return "official.detailParity.category.cityLight"
        case "custom": return "official.detailParity.category.custom"
        case "festival": return "official.detailParity.category.festival"
        case "brand": return "official.detailParity.category.brand"
        case "challenge": return "official.detailParity.category.challenge"
        case "hidden": return "official.detailParity.category.hidden"
        case "community": return "official.detailParity.category.community"
        case "merchant_hunt": return "official.detailParity.category.merchantHunt"
        default: return "official.detailParity.category.official"
        }
    }
    var detailCTA: OfficialDetailCTA {
        if status == 9 { return .offline }
        if let status, status >= 5 { return .ended }
        if status == 4 { return .settling }
        if paused { return .paused }
        if participationInvalid { return .participationInvalid }
        if signed == true {
            if status == 3 && isV2 {
                if missions.contains(where: { $0.canVerifyArrival == true }) { return .roamArrival }
                if missions.contains(where: { $0.type == "THEME_VERIFIED_FINISH" }) { return .themeSync }
                // Only backend-unpublishable types: say so rather than promising tasks.
                if !missions.isEmpty && missions.allSatisfy({ !OfficialDetailMission.isSupported($0.type) }) { return .unsupportedTasks }
                return .waitTasks
            }
            if status == 3 { return roamEnabled ? .roamLight : .explore }
            return status == 1 ? .signedWaiting : .signed
        }
        if status == 2 || status == 3 { return .signup }
        if status == 1 { return .registrationSoon }
        return .unavailable
    }
}
public extension OfficialCollectiveProgress {
    var detailPercentText: String { percent.map { "\($0)%" } ?? "--%" }
    var detailCountText: String {
        "\(current.map { String($0) } ?? "--") / \(threshold.map { String($0) } ?? "--")"
    }
}

public struct OfficialEventDetailPresentation: Equatable {
    public let categoryKey: String
    public let facts: [OfficialDetailFact]
    public let intro: String?
    /// The "详情信息" section appears only when both story and subtitle exist.
    public let storyDetail: String?
    public let cards: [OfficialDetailCard]
    public let missions: [OfficialDetailMission]
    public let eligibilityKey: String?
    public let pausedReason: String?
    public let cta: OfficialDetailCTA
    public let collectiveTipKey: String
    public init(event: OfficialEvent, now: Date, displayTimeZone: TimeZone = .current) {
        func present(_ value: String?) -> String? {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        categoryKey = event.categoryKey
        cards = event.isV2 ? [] : OfficialDetailCard.cards(contentJSON: event.contentJSON)
        missions = event.isV2 ? event.missions.enumerated().map { OfficialDetailMission($0.element, index: $0.offset) } : []
        intro = present(event.subtitle) ?? present(event.story)
        storyDetail = present(event.subtitle) == nil ? nil : present(event.story)
        eligibilityKey = event.isV2
            ? (event.participationInvalid ? "activityR3.official.detail.participationInvalid"
                : event.eligible == true ? "official.detailParity.eligible" : "official.detailParity.notEligible") : nil
        pausedReason = present(event.pausedReason)?.trimmingCharacters(in: .whitespacesAndNewlines)
        cta = event.detailCTA
        collectiveTipKey = event.hasCollectiveReward
            ? "official.detailParity.collective.tipConfigured" : "activityR3.official.detail.collective.tipAbsent"
        var facts = [OfficialDetailFact(id: "participants", labelKey: "official.detailParity.fact.participants",
                                        value: .verbatim(Self.countText(event.participants)),
                                        sub: .hidden)]
        if event.signed == true {
            facts.append(event.isV2
                ? OfficialDetailFact(id: "progress", labelKey: "official.detailParity.fact.progress",
                                     value: .verbatim("\(event.completedMissionCount)/\(event.missions.count)"),
                                     sub: .key("official.detailParity.fact.progressTasks"))
                : OfficialDetailFact(id: "progress", labelKey: "official.detailParity.fact.progress",
                                     value: .verbatim(Self.countText(event.myProgress)),
                                     sub: .hidden))
        }
        facts.append(OfficialDetailFact(id: "duration", labelKey: "official.detailParity.fact.duration",
                                        value: Self.duration(start: event.activityStart, end: event.activityEnd),
                                        sub: .hidden))
        facts.append(OfficialDetailFact(id: "dates", labelKey: "official.detailParity.fact.dates",
                                        value: Self.dateRange(start: event.activityStart, end: event.activityEnd, displayTimeZone: displayTimeZone),
                                        sub: .hidden))
        let countdown: OfficialDetailFactSub
        switch event.countdown(now: now) {
        case .startsIn(let span)?: countdown = .countdown(.startsIn(span))
        case .endsIn(let span)?: countdown = .countdown(.endsIn(span))
        default: countdown = .key(event.statusKey)
        }
        facts.append(OfficialDetailFact(id: "scope", labelKey: "official.detailParity.fact.scope",
                                        value: present(event.city).map { OfficialDetailFactValue.verbatim($0) } ?? .key("official.detailParity.fact.nationwide"),
                                        sub: countdown))
        let taskTotal = event.isV2 ? missions.count : cards.count
        if taskTotal > 0 {
            facts.append(OfficialDetailFact(id: "tasks", labelKey: "official.detailParity.fact.tasks",
                                            value: .verbatim(String(taskTotal)), sub: .hidden))
        }
        self.facts = facts
    }
    /// A missing count is an em dash. A literal zero stays "0".
    private static func countText(_ value: Int?) -> String { value.map(String.init) ?? "—" }
    /// Ceil days from 24 h, else ceil hours (at least one); numeric timestamps only.
    public static func duration(start: OfficialEventTime?, end: OfficialEventTime?) -> OfficialDetailFactValue {
        guard let from = start?.displayMilliseconds, let to = end?.displayMilliseconds else { return .key("official.notAnnounced") }
        let span = to - from
        guard span > 0, span < 1e15 else { return .key("official.notAnnounced") }
        if span >= 86_400_000 { return .days(max(1, Int((span / 86_400_000).rounded(.up)))) }
        return .hours(max(1, Int((span / 3_600_000).rounded(.up))))
    }
    /// Absolute server timestamps displayed on the phone's calendar. This never
    /// changes the server's event window, countdown, status or participation rules.
    /// Zone-free text remains unknown: it cannot establish an absolute instant.
    public static func dateRange(start: OfficialEventTime?, end: OfficialEventTime?, displayTimeZone: TimeZone = .current) -> OfficialDetailFactValue {
        switch (monthDay(start, displayTimeZone: displayTimeZone), monthDay(end, displayTimeZone: displayTimeZone)) {
        case let (from?, to?): return .verbatim(from + "\u{2013}" + to)
        case let (from?, nil): return .verbatim(from)
        case let (nil, to?): return .verbatim(to)
        case (nil, nil): return .key("official.notAnnounced")
        }
    }
    static func monthDay(_ time: OfficialEventTime?, displayTimeZone: TimeZone = .current) -> String? {
        guard let date = time?.displayDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = displayTimeZone
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return nil }
        return "\(month).\(day)"
    }
}

/// Read phases for pages/activity/official-detail. Display only.
/// The detail GET stays on OfficialSessionReader.detail. This value does not
/// register a route, mark a route live, or reveal share. No share route exists.
public enum OfficialEventDetailPagePhase: String, Equatable, Sendable {
    case loading
    case empty
    case error
    case unknown
    case ready
}

public struct OfficialEventDetailPageState: Equatable, Sendable {
    public static let unknownText = "—"
    public static let registersRoute = false
    public static let marksRouteLive = false
    public static let showsMerchantChoice = false
    public static let paymentEnabled = false
    public static let payoutEnabled = false
    public static let withdrawalEnabled = false
    public static let virtualGoodsEnabled = false
    public static let shareVisible = false
    public static let usesExistingDetailRead = true

    public let phase: OfficialEventDetailPagePhase
    public let participantsText: String
    public let progressText: String

    public init(phase: OfficialEventDetailPagePhase, participantsText: String, progressText: String) {
        self.phase = phase
        self.participantsText = participantsText
        self.progressText = progressText
    }

    /// Loading wins over a stale failure and shows neither an em dash nor 0.
    /// A missing count is an em dash. A literal zero stays "0".
    public static func project(loading: Bool, error: Error? = nil, event: OfficialEvent? = nil) -> OfficialEventDetailPageState {
        if loading {
            return OfficialEventDetailPageState(phase: .loading, participantsText: "", progressText: "")
        }
        if error != nil {
            return OfficialEventDetailPageState(phase: .error, participantsText: unknownText, progressText: unknownText)
        }
        guard let event, event.isCompleteRecord else {
            return OfficialEventDetailPageState(phase: .empty, participantsText: unknownText, progressText: unknownText)
        }
        let participants = count(event.participants)
        let progress = signedProgress(event)
        if event.statusKey == "official.status.unknown", event.participants == nil, progressUnmeasured(event) {
            let signedProgressText = event.signed == true ? unknownText : ""
            return OfficialEventDetailPageState(phase: .unknown, participantsText: unknownText, progressText: signedProgressText)
        }
        return OfficialEventDetailPageState(phase: .ready, participantsText: participants, progressText: progress)
    }

    private static func count(_ value: Int?) -> String {
        value.map(String.init) ?? unknownText
    }

    /// An omitted v2 mission list is unmeasured. A present list may include a literal zero.
    private static func signedProgress(_ event: OfficialEvent) -> String {
        guard event.signed == true else { return "" }
        if event.isV2 {
            guard !event.missions.isEmpty else { return unknownText }
            return "\(event.completedMissionCount)/\(event.missions.count)"
        }
        return count(event.myProgress)
    }

    private static func progressUnmeasured(_ event: OfficialEvent) -> Bool {
        guard event.signed == true else { return true }
        if event.isV2 { return event.missions.isEmpty }
        return event.myProgress == nil
    }
}
