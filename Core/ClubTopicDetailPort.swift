import Foundation

/// club/topic-detail parity: six-state mapping, session-status override, verification metrics gate
/// and the primary-action plan. Pure logic so it can be tested without a view.
public enum ClubTopicDetailPort {
    public enum State: String, CaseIterable, Equatable {
        case reviewing, rejected, confirmed, preparing, running, selfrun, ended
        /// Whether the 核销 metrics card is allowed for this state (viewer capability still required).
        public var showsVerify: Bool { [.running, .selfrun, .ended].contains(self) }
        public var showsRejectReason: Bool { self == .rejected }
        /// Localization key suffix for the primary footer button ("club.topic.primary." + rawValue).
        public var primaryKey: String { "club.topic.primary." + rawValue }
        public var primaryDisabled: Bool { self == .reviewing }
    }

    /// Mini `resolveStateKey`: status 2 or a reject reason is rejected; 0 is reviewing; otherwise confirmed.
    public static func auditState(status: Int?, rejectReason: String?) -> State {
        if status == 2 || !(rejectReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .rejected }
        if status == 0 { return .reviewing }
        return .confirmed
    }

    /// Mini `resolveStateKey` on the info-to-user payload (CLB-topic-detail-04). Production sends the numeric
    /// `cms_topic.status` (0 待审核 / 1 通过 / 2 失败) plus lifecycle and the phase timestamps; the string
    /// `status` is only the synthetic fixture's shape and is still honoured as the MP does.
    public static func stateKey(_ raw: ClubGovernanceValue) -> State {
        func present(_ key: String) -> Bool {
            switch raw[key] {
            case .null: return false
            case .string(let v): return !v.isEmpty
            case .bool(let v): return v
            default: return true
            }
        }
        let numeric: Int? = { if case .integer(let v) = raw["status"] { return v }; return raw["status"].string.flatMap(Int.init) }()
        let word = raw["status"].string
        let reject = raw["rejectReason"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if numeric == 2 || !reject.isEmpty || word == "rejected" { return .rejected }
        if numeric == 0 || raw["lifecycle"].int == 7 || word == "reviewing" { return .reviewing }
        if present("endedAt") || word == "ended" { return .ended }
        if present("startedAt") || word == "running" { return raw["selfPublished"] == .bool(true) ? .selfrun : .running }
        if present("preparingAt") || word == "preparing" { return .preparing }
        return .confirmed
    }

    /// Mini `NOT_ON_SALE_TEXT` keys: lifecycle 1 招募中 / 2 定价中 / 7 立项待审 are not on sale yet.
    public static func notOnSaleKey(lifecycle: Int?) -> String? {
        guard let lifecycle, [1, 2, 7].contains(lifecycle) else { return nil }
        return "club.topic.notOnSale.\(lifecycle)"
    }

    /// Mini `SESSION_STATUS_KEYS`; unknown values return nil so the audit state is kept.
    public static func sessionState(_ status: String?) -> State? {
        switch (status ?? "").uppercased() {
        case "NOT_PREPARED", "DRAFT": return .confirmed
        case "PREPARING", "READY": return .preparing
        case "RUNNING": return .running
        case "FINISHED", "CANCELLED": return .ended
        default: return nil
        }
    }

    public struct Display: Equatable {
        public let state: State
        public let cancelled: Bool
        public init(state: State, cancelled: Bool) { self.state = state; self.cancelled = cancelled }
    }

    /// Reviewing/rejected always win; otherwise the session status decides, falling back to the audit state.
    public static func display(audit: State, sessionStatus: String?) -> Display {
        if audit == .reviewing || audit == .rejected { return .init(state: audit, cancelled: false) }
        let mapped = sessionState(sessionStatus) ?? audit
        return .init(state: mapped, cancelled: (sessionStatus ?? "").uppercased() == "CANCELLED")
    }

    /// 核销 card: state allows it, the session is not cancelled, and the server granted `canViewVerify`.
    public static func showsVerify(_ display: Display, canViewVerify: Bool?) -> Bool {
        display.state.showsVerify && !display.cancelled && canViewVerify == true
    }

    public struct Metric: Equatable { public let key: String; public let value: String }

    /// Missing counts render as an em dash, never as zero.
    public static func verifyMetrics(pending: Int?, verifiedByMe: Int?, headcount: Int?) -> [Metric] {
        func text(_ v: Int?) -> String { v.map { $0 >= 0 ? String($0) : "—" } ?? "—" }
        return [.init(key: "pending", value: text(pending)), .init(key: "verifiedByMe", value: text(verifiedByMe)),
                .init(key: "headcount", value: text(headcount))]
    }

    public enum Primary: Equatable {
        case none
        case action(State)               // director action / settlement report / edit-and-resubmit
        case chooseSession               // 去选一场
        case openSession                 // 去开场 (no sessions yet)
    }

    /// Mini `resolvePrimary` for the four director-driven states.
    public static func primary(state: State, directorActive: Bool, canDirect: Bool, canManageSessions: Bool,
                               hasClub: Bool, sessionCount: Int, singleSessionHasValidID: Bool) -> Primary {
        guard [.confirmed, .preparing, .running, .selfrun].contains(state) else { return .action(state) }
        if directorActive { return canDirect ? .action(state) : .none }
        if hasClub, canDirect, sessionCount == 1, singleSessionHasValidID { return .action(state) }
        if !hasClub || (!canManageSessions && !(canDirect && sessionCount > 0)) { return .none }
        return sessionCount >= 1 ? .chooseSession : .openSession
    }

    /// "3 章 · 5 站 · 玩法" — chapters, nodes, play mode, skipping missing/zero parts.
    public static func structureParts(chapters: Int?, nodes: Int?, playMode: String?) -> [String] {
        var parts: [String] = []
        if let c = chapters, c > 0 { parts.append("\(c) 章") }
        if let n = nodes, n > 0 { parts.append("\(n) 站") }
        if let p = playMode?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty { parts.append(p) }
        return parts
    }
}
