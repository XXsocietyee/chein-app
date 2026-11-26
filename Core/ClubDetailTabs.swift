import Foundation
import CoreFoundation

/// Mini-program `pages/club/detail` view tabs: posts / events / overview are public,
/// manage is appended only for governors or a scoped access/me grant.
public enum ClubDetailTab: String, CaseIterable, Identifiable, Sendable {
    case posts, events, overview, manage
    public var id: String { rawValue }
    public static let publicTabs: [ClubDetailTab] = [.posts, .events, .overview]
}

/// Projection of `/api/club/access/me` that only decides manage-tab visibility.
/// `nil` means the access read is loading or failed; the legacy owner/admin flags
/// from `/api/club/detail` still govern the tab, matching `revokeClubAccess`.
public struct ClubDetailManageGrant: Equatable, Sendable {
    /// Permissions that each open a manage-tab tool in the mini-program.
    public static let managePermissions: Set<String> = [
        "club:write", "club:member:approve", "club:member:manage", "club:content:manage",
        "club:role:manage", "club:notify:send", "club:activity:manage", "club:event:operate",
        "club:event:checkin", "club:finance:read",
    ]
    public let clubID: Int
    public let allowsManage: Bool
    /// Granted permission codes (empty when the access read was inactive); drives per-entry gates.
    public let permissions: Set<String>
    public init(clubID: Int, permissions: Set<String>, hasEventScope: Bool) {
        self.clubID = clubID
        self.permissions = permissions
        allowsManage = hasEventScope || !permissions.isDisjoint(with: Self.managePermissions)
    }
    public init(_ permissions: ClubGovernancePermissions) {
        self.init(clubID: permissions.clubID, permissions: permissions.active ? permissions.permissions : [],
                  hasEventScope: permissions.active && !permissions.eventAccesses.isEmpty)
    }
}

public struct ClubDetailTabPolicy: Equatable, Sendable {
    public let clubID: Int
    public let isOwner: Bool
    public let isJoined: Bool
    public let viewerIsAdmin: Bool
    public let grant: ClubDetailManageGrant?

    public init(clubID: Int, isOwner: Bool, isJoined: Bool, viewerIsAdmin: Bool, grant: ClubDetailManageGrant? = nil) {
        self.clubID = clubID; self.isOwner = isOwner; self.isJoined = isJoined; self.viewerIsAdmin = viewerIsAdmin
        // A grant for another club never widens this club's tabs.
        self.grant = grant?.clubID == clubID ? grant : nil
    }

    public init(club: ClubRecord, grant: ClubDetailManageGrant? = nil) {
        self.init(clubID: club.id, isOwner: club.isOwner, isJoined: club.isJoined, viewerIsAdmin: club.viewerIsAdmin, grant: grant)
    }

    /// `canGovern`: owner or legacy role=1 administrator from the detail payload.
    public var canGovern: Bool { isOwner || viewerIsAdmin }
    public var canUseManageTab: Bool { canGovern || grant?.allowsManage == true }
    public var tabs: [ClubDetailTab] { canUseManageTab ? ClubDetailTab.publicTabs + [.manage] : ClubDetailTab.publicTabs }
    /// CLB-detail-13: the MP always opens on 概览 (owner ruling 2026-10-22, detail js:3414-3420).
    public var defaultTab: ClubDetailTab { .overview }

    /// Initial tab after the detail read. A `manage` deep-link intent is honored only once
    /// the server has confirmed the viewer may use it; otherwise the public default wins.
    public func initialTab(requested: ClubDetailTab?) -> ClubDetailTab {
        if let requested, tabs.contains(requested) { return requested }
        return defaultTab
    }

    /// Re-validates a selection after detail or access changes (role revoked, account switch).
    public func resolve(_ selection: ClubDetailTab?) -> ClubDetailTab {
        guard let selection, tabs.contains(selection) else { return defaultTab }
        return selection
    }

    /// `switchTab`: idempotent, and the manage tab cannot be opened by an event when gated.
    public func select(_ tab: ClubDetailTab, from current: ClubDetailTab) -> ClubDetailTab {
        tabs.contains(tab) ? tab : current
    }
}

/// CLB-detail-42: MP `pages/club/detail` header shows 主理人 and 城市 even when the server left them out; a missing
/// value reads 待补充 (catalog key below). The old dead overview-grid type had no App caller and is gone again.
/// Unknown counts stay on `ClubDetailPageModel.unknownMark` and are not rewritten here.
public enum ClubDetailHeaderFact {
    /// zh-Hans 待补充 / en "To be added".
    public static let pendingKey = "club.detail.factPending"
    /// The trimmed value, or nil when it is blank or the unknown mark (the header then shows `pendingKey`).
    public static func known(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty || text == ClubDetailPageModel.unknownMark ? nil : text
    }
}

/// Page projection for `pages/club/detail/index`. It reads a payload the existing
/// `POST api/club/detail` contract already returns, plus an optional `/api/club/access/me`
/// grant. It does not open a route, send a request, or mark a missing path live.
/// A missing catalog capability stays hidden. Money writes stay on their Release switches.
public enum ClubDetailPageState: Equatable, Sendable {
    case loading
    case empty
    case error(titleKey: String)
    case ready(ClubDetailPageContent)
}

public enum ClubDetailPageSection: Equatable, Sendable {
    case hidden
    case unavailable
    case loading
    case empty
    case error(titleKey: String)
    case ready
}

public struct ClubDetailPageFact: Equatable, Identifiable, Sendable {
    public let id: String
    public let labelKey: String
    public let value: String
    public var isUnknown: Bool { value == ClubDetailPageModel.unknownMark }
    public init(id: String, labelKey: String, value: String) {
        self.id = id
        self.labelKey = labelKey
        self.value = value
    }
}

public struct ClubDetailPageContent: Equatable, Sendable {
    public let id: Int
    public let name: String
    public let memberCountText: String
    public let levelText: String
    public let leaderText: String
    public let cityText: String
    public let typeText: String
    public let joinPolicyKey: String?
    public let facts: [ClubDetailPageFact]
    public let tabs: [ClubDetailTab]
    public let showsManageTab: Bool
    public let showsRoleManagement: Bool
    public let showsMemberManagement: Bool
    public let showsAppealEntry: Bool
    public let showsCooperationEntry: Bool
    public let showsChat: Bool
    public let showsChannels: Bool
    public let showsLeaderboard: Bool
    public let showsOwnerAI: Bool
    public let showsSettlementWithdraw: Bool
    public let posts: ClubDetailPageSection
    public let events: ClubDetailPageSection
    public let paymentEnabled: Bool
    public let payoutEnabled: Bool
    public let withdrawalEnabled: Bool
    public let virtualGoodsEnabled: Bool
}

public enum ClubDetailPageAccessibility {
    public static let loading = "club.detail.loading"
    public static let empty = "club.detail.empty"
    public static let error = "club.detail.error"
    public static let refresh = "club.detail.refresh"
    public static let retry = "club.detail.retry"
    public static let signIn = "club.detail.signIn"
    public static let name = "club.detail.name"
    public static let factsGrid = "club.detail.factsGrid"
    public static let memberCount = "club.detail.fact.memberCount"
    public static let level = "club.detail.fact.level"
    public static let leader = "club.detail.fact.leader"
    public static let city = "club.detail.fact.city"
}

public enum ClubDetailPageModel {
    /// Em dash (U+2014). Unknown numbers use this. A literal zero does not.
    public static let unknownMark = "\u{2014}"

    /// `failure` wins. A nil or blank payload is `.loading` or `.empty`. A decoded club is `.ready`.
    /// Counts and level are read from this payload, so an omitted number stays unknown instead of
    /// becoming the `0` stored on `ClubRecord`.
    public static func resolve(loading: Bool, payload: Data?, failure: Error?, signedIn: Bool,
                               grant: ClubDetailManageGrant? = nil, hasCommunity: Bool = false,
                               hasGovernance: Bool = false, eventsSummary: ClubDetailEventsSummary? = nil) -> ClubDetailPageState {
        if let failure { return .error(titleKey: titleKey(for: failure)) }
        guard let payload else { return loading ? .loading : .empty }
        let trimmed = payload.trimmingWhitespace()
        guard !trimmed.isEmpty else { return loading ? .loading : .empty }
        // A bare `null` body is empty, like an empty object; top-level fragments need `.fragmentsAllowed` to parse.
        guard let raw = try? JSONSerialization.jsonObject(with: trimmed, options: .fragmentsAllowed) else { return .error(titleKey: "club.loadFailed") }
        if raw is NSNull { return loading ? .loading : .empty }
        guard let object = raw as? [String: Any] else { return .error(titleKey: "club.loadFailed") }
        if object["id"] != nil { return project(object, signedIn: signedIn, grant: grant, hasCommunity: hasCommunity, hasGovernance: hasGovernance, eventsSummary: eventsSummary) }
        if object.isEmpty { return .empty }
        guard object["code"] != nil || object["data"] != nil else { return .error(titleKey: "club.loadFailed") }
        switch MeasuredInt.read(object["code"]) {
        case .malformed: return .error(titleKey: "club.loadFailed")
        case .absent:
            guard let data = object["data"] else { return .empty }
            return projectData(data, loading: loading, signedIn: signedIn, grant: grant, hasCommunity: hasCommunity, hasGovernance: hasGovernance, eventsSummary: eventsSummary)
        case .value(401): return .error(titleKey: "club.signInRequired")
        case .value(403): return .error(titleKey: "club.accessDenied")
        case .value(200):
            guard let data = object["data"] else { return .empty }
            return projectData(data, loading: loading, signedIn: signedIn, grant: grant, hasCommunity: hasCommunity, hasGovernance: hasGovernance, eventsSummary: eventsSummary)
        case .value(_): return .error(titleKey: "club.loadFailed")
        }
    }

    public static func titleKey(for error: Error) -> String {
        if let failure = error as? ClubReadFailure {
            if failure.isUnauthorized { return "club.signInRequired" }
            if failure.isForbidden { return "club.accessDenied" }
            if failure == .membershipRequired { return "club.membersUnavailable" }
            return "club.loadFailed"
        }
        if let api = error as? APIError {
            switch api {
            case .unauthorized: return "club.signInRequired"
            case .notConfigured: return "club.unavailable"
            default: return "club.loadFailed"
            }
        }
        return "club.loadFailed"
    }

    public static func countText(_ value: Int?) -> String {
        guard let value, value >= 0 else { return unknownMark }
        return String(value)
    }

    public static func levelText(_ value: Int?) -> String {
        guard let value, (1...5).contains(value) else { return unknownMark }
        return "L\(value)"
    }

    private static func projectData(_ data: Any, loading: Bool, signedIn: Bool, grant: ClubDetailManageGrant?,
                                    hasCommunity: Bool, hasGovernance: Bool, eventsSummary: ClubDetailEventsSummary?) -> ClubDetailPageState {
        if data is NSNull { return loading ? .loading : .empty }
        guard let object = data as? [String: Any] else { return .error(titleKey: "club.loadFailed") }
        if object.isEmpty { return .empty }
        return project(object, signedIn: signedIn, grant: grant, hasCommunity: hasCommunity, hasGovernance: hasGovernance, eventsSummary: eventsSummary)
    }

    private static func project(_ object: [String: Any], signedIn: Bool, grant: ClubDetailManageGrant?,
                                hasCommunity: Bool, hasGovernance: Bool, eventsSummary: ClubDetailEventsSummary?) -> ClubDetailPageState {
        switch MeasuredInt.read(object["id"]) {
        case .absent, .malformed: return .error(titleKey: "club.loadFailed")
        case .value(let id):
            guard id > 0 else { return .error(titleKey: "club.loadFailed") }
            let name = MeasuredString.read(object["name"])
            let leader = MeasuredString.read(object["leaderName"])
            let city = MeasuredString.read(object["city"])
            let address = MeasuredString.read(object["address"])
            let clubType = MeasuredString.read(object["clubType"])
            let clubTypes = MeasuredString.read(object["clubTypes"])
            let memberCount = MeasuredInt.read(object["memberCount"])
            let level = MeasuredInt.read(object["level"])
            let isOwner = MeasuredBool.read(object["isOwner"])
            let isJoined = MeasuredBool.read(object["isJoined"])
            let viewerIsAdmin = MeasuredBool.read(object["viewerIsAdmin"])
            let identityUnavailable = MeasuredBool.read(object["viewerIdentityUnavailable"])
            let joinPolicy = MeasuredInt.read(object["joinPolicy"])
            let joinPolicySupported = MeasuredBool.read(object["joinPolicySupported"])
            if [name, leader, city, address, clubType, clubTypes].contains(.malformed)
                || [memberCount, level, joinPolicy].contains(.malformed)
                || [isOwner, isJoined, viewerIsAdmin, identityUnavailable, joinPolicySupported].contains(.malformed) {
                return .error(titleKey: "club.loadFailed")
            }
            let knownIdentity = identityUnavailable != .value(true)
            let owner = knownIdentity && isOwner == .value(true)
            let joined = knownIdentity && isJoined == .value(true)
            let admin = knownIdentity && viewerIsAdmin == .value(true)
            let appliedGrant = (signedIn && knownIdentity) ? grant : nil
            let policy = ClubDetailTabPolicy(clubID: id, isOwner: signedIn && owner, isJoined: signedIn && joined, viewerIsAdmin: signedIn && admin, grant: appliedGrant)
            let entry = ClubDetailEntryGate(clubID: id, isOwner: owner, isJoined: joined, viewerIsAdmin: admin, signedIn: signedIn && knownIdentity, grant: appliedGrant)
            let memberCountText = countText(memberCount.nonNegative)
            let levelDisplay = levelText(level.level)
            let leaderText = leader.display
            // A blank string is present and unknown. Only an omitted city/type falls through.
            let cityText = city == .absent ? address.display : city.display
            let typeText = clubType == .absent ? clubTypes.display : clubType.display
            let facts = [
                ClubDetailPageFact(id: ClubDetailPageAccessibility.leader, labelKey: "club.leader", value: leaderText),
                ClubDetailPageFact(id: ClubDetailPageAccessibility.level, labelKey: "club.detail.levelFact", value: levelDisplay),
                ClubDetailPageFact(id: ClubDetailPageAccessibility.city, labelKey: "club.detail.cityFact", value: cityText),
                ClubDetailPageFact(id: ClubDetailPageAccessibility.memberCount, labelKey: "club.members", value: memberCountText),
            ]
            let member = signedIn && knownIdentity && (owner || joined)
            return .ready(ClubDetailPageContent(
                id: id,
                name: name.trimmed,
                memberCountText: memberCountText,
                levelText: levelDisplay,
                leaderText: leaderText,
                cityText: cityText,
                typeText: typeText,
                joinPolicyKey: joinPolicyKey(supported: joinPolicySupported, policy: joinPolicy),
                facts: facts,
                tabs: policy.tabs,
                showsManageTab: policy.canUseManageTab,
                showsRoleManagement: entry.showsRoleManagement,
                showsMemberManagement: entry.showsMemberManagement,
                showsAppealEntry: entry.showsAppealEntry,
                showsCooperationEntry: entry.showsCooperationEntry,
                showsChat: member && live("api/club/chat"),
                showsChannels: member && live("api/club/channels"),
                showsLeaderboard: member && live("api/club/leaderboard"),
                showsOwnerAI: signedIn && knownIdentity && owner && policy.canUseManageTab && live("api/ai/club/design"),
                showsSettlementWithdraw: ReleaseMoneyWriteSwitch.payoutEnabled,
                posts: hasCommunity ? .ready : .unavailable,
                events: eventsSection(hasGovernance: hasGovernance, summary: eventsSummary),
                paymentEnabled: ReleaseMoneyWriteSwitch.paymentEnabled,
                payoutEnabled: ReleaseMoneyWriteSwitch.payoutEnabled,
                withdrawalEnabled: ReleaseMoneyWriteSwitch.withdrawalEnabled,
                virtualGoodsEnabled: ReleaseMoneyWriteSwitch.virtualGoodsEnabled
            ))
        }
    }

    private static func eventsSection(hasGovernance: Bool, summary: ClubDetailEventsSummary?) -> ClubDetailPageSection {
        guard live("api/club/topics") else { return .hidden }
        guard hasGovernance else { return .unavailable }
        guard let summary else { return .loading }
        switch summary.state {
        case .loading: return .loading
        case .empty: return .empty
        case .failed(let key): return .error(titleKey: key)
        case .loaded: return .ready
        }
    }

    /// Live catalog routes only. A `.missing` path, including `api/club/channels`, stays false.
    private static func live(_ path: String) -> Bool {
        let key = path.hasPrefix("/") ? path : "/" + path
        return ChinaReviewedRouteCapability.mark(for: key) == .liveInProduction
            && ChinaReviewedRouteCapability.admitsChinaProductionCall(key)
    }

    private static func joinPolicyKey(supported: MeasuredBool, policy: MeasuredInt) -> String? {
        guard supported == .value(true) else { return nil }
        if case .value(1) = policy { return "club.detail.joinPolicy.review" }
        return "club.detail.joinPolicy.open"
    }
}

private enum MeasuredInt: Equatable {
    case absent, malformed
    case value(Int)
    static func read(_ value: Any?) -> MeasuredInt {
        if value == nil || value is NSNull { return .absent }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return .malformed }
        let double = number.doubleValue
        guard double.isFinite, double.rounded() == double, double >= Double(Int.min), double <= Double(Int.max) else { return .malformed }
        return .value(Int(double))
    }
    var nonNegative: Int? {
        if case .value(let value) = self, value >= 0 { return value }
        return nil
    }
    var level: Int? {
        if case .value(let value) = self, (1...5).contains(value) { return value }
        return nil
    }
}

private enum MeasuredString: Equatable {
    case absent, malformed
    case value(String)
    static func read(_ value: Any?) -> MeasuredString {
        if value == nil || value is NSNull { return .absent }
        guard let text = value as? String else { return .malformed }
        return .value(text)
    }
    var trimmed: String {
        guard case .value(let text) = self else { return "" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var display: String { trimmed.isEmpty ? ClubDetailPageModel.unknownMark : trimmed }
}

private enum MeasuredBool: Equatable {
    case absent, malformed
    case value(Bool)
    static func read(_ value: Any?) -> MeasuredBool {
        if value == nil || value is NSNull { return .absent }
        guard let flag = value as? Bool else { return .malformed }
        return .value(flag)
    }
}

private extension Data {
    func trimmingWhitespace() -> Data {
        var bytes = self
        let whitespace = Set(" \n\r\t".utf8)
        while let first = bytes.first, whitespace.contains(first) { bytes.removeFirst() }
        while let last = bytes.last, whitespace.contains(last) { bytes.removeLast() }
        return bytes
    }
}

#if DEBUG
/// Synthetic detail payloads for DEBUG builds. No host, token, or transport.
public enum ClubDetailPageFixtureData {
    public static let ready = #"{"id":81,"name":"Synthetic Club","memberCount":2,"level":3,"leaderName":"Fixture Host","city":"Hangzhou","clubType":"Outdoor","isOwner":false,"isJoined":true,"viewerIsAdmin":false,"joinPolicy":1,"joinPolicySupported":true}"#
    public static let unknownNumbers = #"{"id":81,"name":"Synthetic Club","memberCount":null,"level":null,"leaderName":null,"city":null}"#
    public static let literalZeroMembers = #"{"id":81,"name":"Synthetic Club","memberCount":0,"level":0}"#
    public static let emptyObject = "{}"
    public static let envelope = #"{"code":200,"data":{"id":81,"name":"Synthetic Club"}}"#
}
#endif
