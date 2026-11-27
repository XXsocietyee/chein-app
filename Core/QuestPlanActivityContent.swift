import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif
#if canImport(ActivityKit) && canImport(AppIntents) && os(iOS)
import AppIntents
#endif

/// Components r1 R-island ("Dynamic Island as a shared space between friends"): the shared invite / plan Live Activity.
/// Compiled into the app and the `QuestifyLiveActivity` extension (`tools/generate_project.py` shares this file).
/// The expanded presentation is a small plan card — a headline question, a taped-note line, one or two stickers and the
/// actions 加入 / 稍后 ("Tuck": the card folds back to the compact pill and stays there). One activity per plan.
///
/// Every member sees the same card: the server starts it with ActivityKit push-to-start and updates it with per-activity
/// pushes (`QuestPlanActivityTokenRegistration`), and the app starts a local copy when push is unavailable.
/// Display values only. `planKey` is the server's opaque plan key (`team:<id>`, `offer:<uuid>`, `club-event:<id>`), used to
/// pair an activity's push token with its plan and to stop a local copy duplicating a pushed one; `targetID` is the public
/// team / club id the 加入 link opens. Neither is an account, token or coordinate.
public enum QuestPlanKind: String, Codable, Hashable, Sendable {
    /// Someone invited me to their team (`FRIEND_OFFER`, MP 加入队伍).
    case teamInvite
    /// A friend asked me to come along (MP referral "朋友邀请你一起玩").
    case friendInvite
    /// A club event starts today / soon (MP 距开始 / 即将开始).
    case clubEvent
    /// Live team status during a run ("Lena reached stop 3").
    case teamStatus
}

/// ActivityKit `ContentState` of the plan card. All but `headline` are optional so a server push may send less.
public struct QuestPlanContent: Codable, Hashable, Sendable {
    /// The question on the card: "一起漫游？" / "Walk tonight?". Already localized by whoever wrote it.
    public var headline: String
    /// The taped-note line under the headline (team name, inviter, "Lena 到达第 3 站").
    public var note: String?
    /// One or two stickers: SF Symbol names or a single emoji each. Anything else is dropped (`QuestPlanSticker`).
    public var stickers: [String]?
    /// Start of the plan, counted down with `Text(timerInterval:countsDown: true)` while ahead.
    public var startsAt: Date?
    /// Team progress for `.teamStatus`: members done out of the team size.
    public var done: Int?
    public var total: Int?
    /// 稍后 / Tuck: the card folded back to the compact pill. The plan stays live (no alert, no expanded card).
    public var tucked: Bool?
    /// The viewer already joined; the card shows 已加入 instead of the actions.
    public var joined: Bool?
    public init(headline: String, note: String? = nil, stickers: [String]? = nil, startsAt: Date? = nil,
                done: Int? = nil, total: Int? = nil, tucked: Bool? = nil, joined: Bool? = nil) {
        self.headline = headline; self.note = note; self.stickers = stickers; self.startsAt = startsAt
        self.done = done; self.total = total; self.tucked = tucked; self.joined = joined
    }

    /// `now...startsAt` while the start is ahead; nil once it has begun.
    public func startInterval(now: Date) -> ClosedRange<Date>? {
        guard let startsAt, startsAt > now else { return nil }
        return now...startsAt
    }
    public var isTucked: Bool { tucked == true }
    /// 加入 / 稍后 show until the viewer joined or tucked the card.
    public var showsActions: Bool { joined != true && tucked != true }
    /// At most two usable stickers.
    public var visibleStickers: [QuestPlanSticker] { (stickers ?? []).compactMap(QuestPlanSticker.init).prefix(2).map { $0 } }
}

/// A sticker is an SF Symbol name (`figure.walk`, `moon.stars.fill`) or one emoji grapheme. Anything longer is refused so a
/// pushed payload cannot turn the sticker slot into text.
public enum QuestPlanSticker: Hashable, Sendable {
    case symbol(String), emoji(String)
    public init?(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 40 else { return nil }
        if value.count == 1, value.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0.properties.isEmoji && $0.value > 0xFF }) {
            self = .emoji(value)
        } else if value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == ".") }), value.first?.isLetter == true {
            self = .symbol(value)
        } else {
            return nil
        }
    }
}

/// Where 加入 lands. Fixed `chein://` pages the app already routes (`MiniProgramPageLink`); only a public id is added.
public enum QuestPlanLinks {
    /// MP `pages/team/detail/index?teamId=` (查看队伍 / 加入方式 live there).
    public static func team(_ id: Int?) -> URL {
        guard let id, id > 0, let url = URL(string: "chein://mp/pages/team/detail/index?teamId=\(id)") else { return QuestWidgetLinks.roam }
        return url
    }
    public static func join(kind: QuestPlanKind, targetID: Int?) -> URL? {
        switch kind {
        case .teamInvite: return team(targetID)
        case .friendInvite: return QuestWidgetLinks.roam
        case .clubEvent: return QuestWidgetBoard.club(targetID)
        // Status is followed, not joined: a tap opens the app where the run already is.
        case .teamStatus: return nil
        }
    }
}

/// `POST /api/live-activity/token` body (backend contract in `docs/release/receipts/comp-r1-island-steps.md`).
/// `scope = PUSH_TO_START` registers the device's push-to-start token for `attributesType`; `scope = ACTIVITY` registers one
/// running activity's update token for `planKey` (`activityId` is ActivityKit's local id, for the server's dedupe only);
/// `scope = ENDED` withdraws that activity's token. Tokens are APNs hex strings and are only ever sent to our API.
public struct QuestPlanActivityTokenRequest: Codable, Equatable, Sendable {
    public enum Scope: String, Codable, Sendable { case pushToStart = "PUSH_TO_START", activity = "ACTIVITY", ended = "ENDED" }
    public static let attributesTypeName = "QuestPlanActivityAttributes"
    public let scope: Scope
    public let token: String?
    public let attributesType: String
    public let planKey: String?
    public let activityId: String?
    public let environment: String
    public let bundleId: String
    public let locale: String
    public init(scope: Scope, token: Data?, planKey: String?, activityId: String?, environment: String, bundleId: String, locale: String) {
        self.scope = scope
        self.token = token.map(Self.hex)
        self.attributesType = Self.attributesTypeName
        self.planKey = planKey; self.activityId = activityId
        self.environment = environment; self.bundleId = bundleId; self.locale = locale
    }
    public static func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }
    /// A well-formed request: a token for the two register scopes, a plan key for the per-activity ones.
    public var isValid: Bool {
        switch scope {
        case .pushToStart: return token?.isEmpty == false && planKey == nil
        case .activity: return token?.isEmpty == false && planKey?.isEmpty == false
        case .ended: return planKey?.isEmpty == false
        }
    }
}

#if canImport(ActivityKit) && os(iOS)
/// Static attributes. The server's push-to-start payload names this type (`attributes-type: QuestPlanActivityAttributes`)
/// and sends these four fields as `attributes`.
public struct QuestPlanActivityAttributes: ActivityAttributes {
    public typealias ContentState = QuestPlanContent
    public let kind: QuestPlanKind
    public let planKey: String
    /// Team, club or activity name shown as the card's eyebrow.
    public let title: String?
    public let targetID: Int?
    public init(kind: QuestPlanKind, planKey: String, title: String?, targetID: Int?) {
        self.kind = kind; self.planKey = planKey; self.title = title; self.targetID = targetID
    }
}
#endif

/// Tuck handler: the app installs `tuck` so it can also stop re-presenting the plan. Without it (widget process) the intent
/// folds the activity itself.
@MainActor public enum QuestPlanActionRouter {
    public static var tuck: ((String) async -> Bool)?
}

#if canImport(ActivityKit) && canImport(AppIntents) && os(iOS)
/// 稍后 / Tuck. A `LiveActivityIntent`, so it runs in the app's process without bringing it forward: the card's
/// `tucked` flag is set, the expanded card folds back and the compact pill keeps the plan.
public struct QuestPlanTuckIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "plan.intent.tuck"
    public static var description = IntentDescription("plan.intent.tuck.description")
    public static var isDiscoverable: Bool = false
    @Parameter(title: "plan.intent.planKey") public var planKey: String

    public init() {}
    public init(planKey: String) { self.planKey = planKey }

    @MainActor public func perform() async throws -> some IntentResult {
        if let tuck = QuestPlanActionRouter.tuck, await tuck(planKey) { return .result() }
        for activity in Activity<QuestPlanActivityAttributes>.activities where activity.attributes.planKey == planKey {
            var state = activity.content.state
            guard state.tucked != true else { continue }
            state.tucked = true
            await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
        }
        return .result()
    }
}
#endif
