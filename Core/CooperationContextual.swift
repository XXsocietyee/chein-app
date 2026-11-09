import Foundation

public struct CoopFlowTargetCandidate: Equatable, Identifiable {
    public let kind: CoopFlowTargetKind
    public let recipient: CoopFlowIdentity
    public let name: String
    /// Source `pages/coop/invite` row meta: clubs show member count and city, merchants their activity types or address.
    public let memberCount: Int?
    public let city: String?
    public let merchantMeta: String?
    public var id: String { "\(kind.rawValue):\(recipient.id)" }
    public init?(kind: CoopFlowTargetKind, row: CoopFlowJSON) {
        // Current merchant directory exposes BOTH row id and memberId. Invitations address
        // the owner-member; club invitations address club.id. No fallback across domains.
        guard let id = row[kind == .merchant ? "memberId" : "id"].integer,
              let recipient = try? CoopFlowIdentity(kind == .merchant ? .member : .club, id),
              let name = row["name"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        self.kind = kind; self.recipient = recipient; self.name = name
        func text(_ key: String) -> String? { row[key].text.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 } }
        memberCount = kind == .club ? row["memberCount"].integer.flatMap { $0 >= 0 ? $0 : nil } : nil
        city = kind == .club ? text("city") : nil
        merchantMeta = kind == .merchant ? text("suitActivityTypes") ?? text("address") : nil
    }
}
public struct CoopFlowOwnedTopic: Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let startDate: String?
    public let address: String?
    public let inviteWindowOpen: Bool?
    public init?(row: CoopFlowJSON) {
        guard let id = row["id"].integer, id > 0, let name = row["name"].text, !name.isEmpty else { return nil }
        self.id = id; self.name = name; startDate = row["startDate"].text; address = row["addressName"].text
        inviteWindowOpen = row["inviteWindowOpen"].flag
    }
}
/// This projection is a member ID only. Club identities must first be resolved by an
/// authoritative owner-member contract; neither club.id nor a missing fromType is one.
public struct CoopPeerMember: Equatable {
    public let memberID: Int
    public init?(direction: CooperationDirection, fromType: String?, fromID: Int?, toType: String?, toID: Int?) {
        let raw: Int?
        switch direction {
        case .sent: guard toType == "merchant" else { return nil }; raw = toID
        case .received: guard ["merchant", "talent"].contains(fromType ?? "") else { return nil }; raw = fromID
        }
        guard let raw, raw > 0 else { return nil }; memberID = raw
    }
}

/// Readiness for `pages/coop/invite/index`. It classifies the reads `CoopFlowRead` already
/// names (`api/topic/list`, `api/merchant/clubs`, `api/club/merchants`). It does not send
/// `api/coop/invite`, does not open a share sheet, and does not mark a route live.
/// Unknown counts display as an em dash. A literal zero stays zero. A missing capability stays hidden.
public enum CoopInviteIndexReadiness {
    public static let unknownDisplay = "\u{2014}"
    public static let invitePath = "/api/coop/invite"
    /// Keys this page's read contract does not carry. They stay hidden.
    public static let missingKeys = ["toId", "originApplyId", "merchantName", "share", "coopInvited", "originalRequest", "countdown"]

    public enum Phase: String, Equatable {
        case loading
        case empty
        case error
        case unknown
        case ready
    }

    /// A counted fact. Missing, blank, non-integral, and non-canonical values stay unknown.
    /// A JSON number 0 and a canonical integer string "0" stay 0.
    public struct Count: Equatable {
        public let value: Int?
        public var isUnknown: Bool { value == nil }
        public var display: String { value.map(String.init) ?? CoopInviteIndexReadiness.unknownDisplay }

        public static let unknown = Count(value: nil)

        public static func known(_ value: Int) -> Count {
            guard value >= 0 else { return .unknown }
            return Count(value: value)
        }

        public init(json: CoopFlowJSON?) {
            switch json {
            case .number(let number)?:
                self.value = Self.integral(number)
            case .string(let raw)?:
                self.value = Self.canonicalInteger(raw)
            default:
                self.value = nil
            }
        }

        private init(value: Int?) { self.value = value }

        private static func canonicalInteger(_ raw: String) -> Int? {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text != "—", text != "-", text.uppercased() != "UNKNOWN" else { return nil }
            guard let value = Int(text), value >= 0, String(value) == text else { return nil }
            return value
        }

        private static func integral(_ number: Decimal) -> Int? {
            guard number >= 0 else { return nil }
            var source = number
            var rounded = Decimal()
            NSDecimalRound(&rounded, &source, 0, .plain)
            guard rounded == number else { return nil }
            let asNumber = NSDecimalNumber(decimal: rounded)
            guard asNumber.compare(NSDecimalNumber(value: Int.max)) != .orderedDescending else { return nil }
            return asNumber.intValue
        }
    }

    public enum Window: Equatable {
        case open, closed, unknown
        public var canInvite: Bool { self == .open }

        public static func read(_ value: CoopFlowJSON) -> Window {
            switch value {
            case .bool(true): return .open
            case .bool(false): return .closed
            default: return .unknown
            }
        }
    }

    public struct Topic: Equatable, Identifiable {
        public let id: Int
        public let name: String
        public let startDate: String?
        public let address: String?
        public let window: Window
    }

    public struct Target: Equatable, Identifiable {
        public let id: String
        public let kind: CoopFlowTargetKind
        public let name: String
        /// Clubs only. Merchants have no member count on this contract, so the count stays hidden.
        public let memberCount: Count?
        public let city: String?
        public let merchantMeta: String?
        public var showsMemberCount: Bool { kind == .club && memberCount != nil }
        public var memberCountText: String? { showsMemberCount ? memberCount?.display : nil }
    }

    public struct Directory<Row: Equatable>: Equatable {
        public let phase: Phase
        public let rows: [Row]
        public let messageKey: String?
        /// Ready and empty are known sizes. Loading, error, and unknown are an em dash, never 0.
        public var count: Count {
            switch phase {
            case .ready, .empty: return .known(rows.count)
            case .loading, .error, .unknown: return .unknown
            }
        }
    }

    public struct Snapshot: Equatable {
        public let topics: Directory<Topic>
        public let targets: Directory<Target>
        public let selected: Count
        public var phase: Phase {
            let listed = Self.dominant(topics.phase, targets.phase)
            return selected.isUnknown ? Self.dominant(.unknown, listed) : listed
        }
        public var showsInviteSend: Bool { false }
        public var showsShare: Bool { false }
        public var showsLockedTarget: Bool { false }
        public var showsMerchantChoice: Bool { false }
        public var paymentEnabled: Bool { ReleaseMoneyWriteSwitch.paymentEnabled }
        public var payoutEnabled: Bool { ReleaseMoneyWriteSwitch.payoutEnabled }
        public var withdrawalEnabled: Bool { ReleaseMoneyWriteSwitch.withdrawalEnabled }
        public var virtualGoodsEnabled: Bool { ReleaseMoneyWriteSwitch.virtualGoodsEnabled }

        private static func dominant(_ lhs: Phase, _ rhs: Phase) -> Phase {
            let rank: [Phase: Int] = [.unknown: 0, .loading: 1, .error: 2, .empty: 3, .ready: 4]
            return (rank[lhs] ?? 0) <= (rank[rhs] ?? 0) ? lhs : rhs
        }
    }

    public static var inviteSendOffered: Bool { false }
    public static var shareOffered: Bool { false }
    public static var inviteRouteMarkedLive: Bool {
        ChinaReviewedRouteCapability.mark(for: invitePath) == .liveInProduction
    }

    public static func showsLockedTarget(toId: Int?, originApplyId: Int?) -> Bool { false }

    public static func supportingReads(kind: CoopFlowTargetKind, scope: String?, page: Int) -> [CoopFlowRead] {
        [.ownedTopics(kind: kind, scope: scope, page: page), kind == .merchant ? .merchants(name: nil) : .clubs(name: nil)]
    }

    public static func supportingReadIsLive(_ read: CoopFlowRead) -> Bool {
        let path = "/" + read.path
        return ChinaReviewedRouteCapability.mark(for: path) == .liveInProduction
            && ChinaReviewedRouteCapability.admitsChinaProductionCall(path)
    }

    public static func topics(loading: Bool, payload: CoopFlowJSON?, failed: Bool) -> Directory<Topic> {
        classify(loading: loading, failed: failed, payload: payload, body: topicBody)
    }

    public static func targets(kind: CoopFlowTargetKind, loading: Bool, payload: CoopFlowJSON?, failed: Bool) -> Directory<Target> {
        classify(loading: loading, failed: failed, payload: payload) { targetBody(kind, $0) }
    }

    public static func snapshot(topics: Directory<Topic>, targets: Directory<Target>, selected: Count) -> Snapshot {
        Snapshot(topics: topics, targets: targets, selected: selected)
    }

    /// True when the existing review could be opened. This value does not send and does not reveal a locked target.
    public static func canContinue(topic: Topic?, selected: Set<String>, targets: [Target]) -> Bool {
        guard let topic, topic.window.canInvite, !selected.isEmpty else { return false }
        return selected.isSubset(of: Set(targets.map(\.id)))
    }

    private enum Body<Row> {
        case rows([Row])
        case unknown
        case malformed
    }

    private static func classify<Row>(loading: Bool, failed: Bool, payload: CoopFlowJSON?, body: (CoopFlowJSON) -> Body<Row>) -> Directory<Row> {
        if loading { return Directory(phase: .loading, rows: [], messageKey: nil) }
        if failed { return Directory(phase: .error, rows: [], messageKey: "coopflow.read.failed") }
        guard let payload else { return Directory(phase: .unknown, rows: [], messageKey: nil) }
        if case .null = payload { return Directory(phase: .unknown, rows: [], messageKey: nil) }
        switch body(payload) {
        case .unknown:
            return Directory(phase: .unknown, rows: [], messageKey: nil)
        case .malformed:
            return Directory(phase: .error, rows: [], messageKey: "coopflow.read.failed")
        case .rows(let rows) where rows.isEmpty:
            return Directory(phase: .empty, rows: [], messageKey: "context.picker.empty")
        case .rows(let rows):
            return Directory(phase: .ready, rows: rows, messageKey: nil)
        }
    }

    private static func isUnknownToken(_ value: CoopFlowJSON) -> Bool {
        guard let text = value.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return text.uppercased() == "UNKNOWN"
    }

    private static func topicBody(_ payload: CoopFlowJSON) -> Body<Topic> {
        if isUnknownToken(payload) { return .unknown }
        guard case .object = payload else { return .malformed }
        let rowsValue = payload["rows"]
        if isUnknownToken(rowsValue) { return .unknown }
        guard let raw = rowsValue.rows else { return .malformed }
        var parsed: [Topic] = []
        var seen = Set<Int>()
        for row in raw {
            guard let topic = topic(row), seen.insert(topic.id).inserted else { return .malformed }
            parsed.append(topic)
        }
        return .rows(parsed)
    }

    private static func targetBody(_ kind: CoopFlowTargetKind, _ payload: CoopFlowJSON) -> Body<Target> {
        if isUnknownToken(payload) { return .unknown }
        guard let raw = payload.rows else { return .malformed }
        var parsed: [Target] = []
        var seen = Set<String>()
        for row in raw {
            guard let target = target(kind, row), seen.insert(target.id).inserted else { return .malformed }
            parsed.append(target)
        }
        return .rows(parsed)
    }

    private static func topic(_ row: CoopFlowJSON) -> Topic? {
        guard let owned = CoopFlowOwnedTopic(row: row) else { return nil }
        return Topic(id: owned.id, name: owned.name, startDate: owned.startDate, address: owned.address, window: Window.read(row["inviteWindowOpen"]))
    }

    private static func target(_ kind: CoopFlowTargetKind, _ row: CoopFlowJSON) -> Target? {
        guard let candidate = CoopFlowTargetCandidate(kind: kind, row: row) else { return nil }
        let count: Count? = kind == .club ? Count(json: row["memberCount"]) : nil
        return Target(id: candidate.id, kind: kind, name: candidate.name, memberCount: count, city: candidate.city, merchantMeta: candidate.merchantMeta)
    }
}
