import Foundation

// MARK: - Orient score screen presentation (pure, testable)
// Mirrors subpackageMember/orient-score + utils/orient-score-view.js (read side only).
// Nothing here performs a network write; appeal/dispute/settle/sync stay behind the
// existing OrientSessionCoordinator and are not offered by this read-only presentation.

public enum OrientScoreFormat {
    /// Formats hundredths as a fixed two-decimal string using integer math only (never Double).
    /// `signed` adds "+" for positive non-zero values, like the mini-program `centi(value, true)`.
    public static func centi(_ value: Int, signed: Bool = false) -> String {
        let magnitude = value.magnitude
        let whole = magnitude / 100
        let fraction = magnitude % 100
        let body = "\(whole)." + (fraction < 10 ? "0\(fraction)" : "\(fraction)")
        if value < 0 { return "-" + body }
        return signed && value != 0 ? "+" + body : body
    }
}

public struct OrientScoreDimensionRow: Equatable, Identifiable, Sendable {
    public let key: String
    public let label: String
    public let value: String
    public var id: String { key }
}

public struct OrientScoreTimelineRow: Equatable, Identifiable, Sendable {
    public let entryID: Int
    public let nodeID: Int?
    public let dimension: String
    public let delta: String
    public let running: String
    public let reason: String
    public let reversesEntryID: Int?
    public let appealPending: Bool
    public var id: Int { entryID }
    /// Spoken summary so VoiceOver does not have to read the table cell by cell.
    public var accessibilitySummary: String {
        W8Text.t("\(dimension) \(delta)，累计 \(running)", "\(dimension) \(delta), running total \(running)")
    }
}

public struct OrientScoreReviewRow: Equatable, Identifiable, Sendable {
    public let id: Int
    public let statusText: String
    public let reason: String
    public let note: String?
}

public struct OrientScoreSettlementSummary: Equatable, Sendable {
    public let settlementID: Int
    public let total: String
    public let points: Int
    public let xp: Int
}

public struct OrientScoreSummary: Equatable, Sendable {
    public let sessionID: Int
    public let phase: String
    public let total: String
    /// Plain-language statement of the total, used as the accessibility label of the headline number.
    public let totalAccessibility: String
    public let dimensions: [OrientScoreDimensionRow]
    public let timeline: [OrientScoreTimelineRow]
    public let settlement: OrientScoreSettlementSummary?
    public let appeals: [OrientScoreReviewRow]
    public let disputes: [OrientScoreReviewRow]
    /// Display text for `disputeWindowDeadline`. Nil when the score has no deadline.
    public let disputeDeadline: String?
    /// Same rule as the mini-program: status 1 or 2, a deadline, and no open dispute.
    public let canDispute: Bool
    public var settlementNotice: String {
        settlement == nil
            ? W8Text.t("本局尚未结算，暂不能确认积分或探索值到账。", "This round is not settled yet, so points and explore XP are not confirmed.")
            : W8Text.t("结算后冲正只影响展示分，不追发或追扣本局奖励。", "Corrections after settlement only change the displayed score; they do not grant or claw back this round's rewards.")
    }
}

public enum OrientScoreLoadState: Equatable, Sendable {
    case loading
    /// No session of the player's own to show.
    case empty
    /// Read failed; `retryable` drives whether a retry button is offered.
    case failed(message: String, retryable: Bool)
    case ready(OrientScoreSummary)

    public var isLoading: Bool { if case .loading = self { return true } else { return false } }
}

public enum OrientScorePresentation {
    public static func dimensionLabel(_ key: String) -> String {
        switch key {
        case "TASK": return W8Text.t("任务", "Tasks")
        case "PUZZLE": return W8Text.t("解谜", "Puzzles")
        case "BONUS": return W8Text.t("奖励", "Bonus")
        case "PENALTY": return W8Text.t("处罚", "Penalty")
        case "ADJUSTMENT": return W8Text.t("调整", "Adjustment")
        default: return key
        }
    }

    public static func phase(status: Int) -> String {
        switch status {
        case 3: return W8Text.t("已取消资格", "Disqualified")
        case 1, 2: return W8Text.t("对局已结束", "Round ended")
        default: return W8Text.t("对局进行中", "Round in progress")
        }
    }

    public static func reviewStatus(_ status: Int) -> String {
        switch status {
        case 0: return W8Text.t("待处理", "Pending")
        case 1: return W8Text.t("已采纳", "Accepted")
        case 2: return W8Text.t("已驳回", "Rejected")
        default: return W8Text.t("状态待确认", "Status unconfirmed")
        }
    }

    static let dimensionOrder = ["TASK", "PUZZLE", "BONUS", "PENALTY", "ADJUSTMENT"]

    public static func summary(from score: OrientSessionScore) -> OrientScoreSummary {
        let pendingEntries = Set(score.appealRecords.filter { $0.status == 0 }.compactMap(\.entryID))
        let dimensions = dimensionOrder.compactMap { key -> OrientScoreDimensionRow? in
            guard let value = score.byDimension[key] else { return nil }
            return OrientScoreDimensionRow(key: key, label: dimensionLabel(key), value: OrientScoreFormat.centi(value, signed: true))
        }
        let timeline = score.timeline.compactMap { timelineRow($0, pendingEntries: pendingEntries) }
        let total = OrientScoreFormat.centi(score.totalCenti)
        let settlement = score.settlement.map {
            OrientScoreSettlementSummary(settlementID: $0.settlementID, total: OrientScoreFormat.centi($0.totalCenti),
                                         points: $0.pointsAwarded, xp: $0.xpAwarded)
        }
        func reviews(_ rows: [OrientSessionScoreReviewRecord]) -> [OrientScoreReviewRow] {
            rows.map { OrientScoreReviewRow(id: $0.id, statusText: reviewStatus($0.status), reason: $0.reason,
                                            note: ($0.resolutionNote?.isEmpty ?? true) ? nil : $0.resolutionNote) }
        }
        return OrientScoreSummary(
            sessionID: score.sessionID, phase: phase(status: score.status), total: total,
            totalAccessibility: W8Text.t("本局总分 \(total) 分", "Round total \(total) points"),
            dimensions: dimensions, timeline: timeline, settlement: settlement,
            appeals: reviews(score.appealRecords), disputes: reviews(score.disputeRecords),
            disputeDeadline: score.disputeWindowDeadline, canDispute: score.canDispute)
    }

    /// A timeline entry without a positive entry id or numeric delta is dropped, matching the
    /// mini-program which refuses to render a malformed ledger row.
    static func timelineRow(_ json: OrientSessionJSON, pendingEntries: Set<Int>) -> OrientScoreTimelineRow? {
        guard case .object(let fields) = json,
              let entryID = fields["entryId"]?.exactInteger, entryID > 0,
              let delta = fields["deltaCenti"]?.exactInteger,
              let running = fields["runningCenti"]?.exactInteger else { return nil }
        func positive(_ key: String) -> Int? {
            guard let value = fields[key]?.exactInteger, value > 0 else { return nil }
            return value
        }
        var dimension = ""
        if case .string(let key)? = fields["dimension"] { dimension = dimensionLabel(key) }
        var reason = ""
        if case .string(let code)? = fields["reasonCode"] { reason = code }
        return OrientScoreTimelineRow(
            entryID: entryID, nodeID: positive("nodeId"), dimension: dimension,
            delta: OrientScoreFormat.centi(delta, signed: true), running: OrientScoreFormat.centi(running),
            reason: reason, reversesEntryID: positive("reversesEntryId"), appealPending: pendingEntries.contains(entryID))
    }

    /// Maps a thrown read error to user-facing copy. Raw HTTP codes and server text are never shown.
    public static func failure(for error: Error) -> OrientScoreLoadState {
        if let failure = error as? OrientSessionFailure, failure.isUnauthorized {
            return .failed(message: W8Text.t("请登录本人账号查看对局", "Sign in to your own account to view this round."), retryable: false)
        }
        return .failed(message: W8Text.t("计分暂时无法读取，请稍后重试。", "The score can't be loaded right now. Please try again."), retryable: true)
    }
}

// MARK: - Page binding for the existing score read
// `OrientSessionService.score` already reads `api/orient/scoring/session/{id}`.
// This type does not add a route and does not mark the page live. Appeal, dispute,
// sync, and settle stay off. A missing client capability stays hidden.
// UNKNOWN, null, a missing number, a numeric string, and a non-integral number
// display as an em dash and are never stored as 0. A JSON integer 0 score stays
// the existing centi zero ("0.00"). A JSON integer 0 for points or explore XP stays "0".

public struct OrientScorePage: Equatable, Sendable {
    public static let unknownDisplay = "—"
    /// Same path `OrientSessionService.score` already sends. Not a new route.
    public static let readPath = "api/orient/scoring/session/{}"

    public enum Phase: Equatable, Sendable {
        case loading
        case empty
        case error
        case unknown
        case ready(Facts)
    }

    public struct TimelineFact: Equatable, Sendable {
        public let entryID: Int
        public let deltaText: String
        public let runningText: String

        public init(entryID: Int, deltaText: String, runningText: String) {
            self.entryID = entryID
            self.deltaText = deltaText
            self.runningText = runningText
        }
    }

    public struct Facts: Equatable, Sendable {
        public enum Settlement: Equatable, Sendable {
            case absent
            case unknown
            case settled(total: String, points: String, xp: String)
        }

        public let sessionID: Int
        public let phaseText: String
        public let totalText: String
        public let dimensions: [OrientScoreDimensionRow]
        public let settlement: Settlement
        /// False when the ledger is missing, null, or not an array. An empty array is a known empty ledger.
        public let timelineKnown: Bool
        public let timeline: [TimelineFact]

        public init(sessionID: Int, phaseText: String, totalText: String, dimensions: [OrientScoreDimensionRow], settlement: Settlement, timelineKnown: Bool, timeline: [TimelineFact]) {
            self.sessionID = sessionID
            self.phaseText = phaseText
            self.totalText = totalText
            self.dimensions = dimensions
            self.settlement = settlement
            self.timelineKnown = timelineKnown
            self.timeline = timeline
        }
    }

    public let clientCapabilityPresent: Bool
    public let serverFactPresent: Bool
    public let phase: Phase?
    public var showsContent: Bool {
        switch phase {
        case .empty, .error, .unknown, .ready: return true
        case .loading, nil: return false
        }
    }
    public var showsMerchantChoice: Bool { false }
    public var appealEnabled: Bool { false }
    public var disputeEnabled: Bool { false }
    public var settleEnabled: Bool { false }
    public var syncEnabled: Bool { false }
    public var paymentEnabled: Bool { false }
    public var payoutEnabled: Bool { false }
    public var withdrawalEnabled: Bool { false }

    public init(clientCapabilityPresent: Bool, serverFactPresent: Bool, phase: Phase?) {
        self.clientCapabilityPresent = clientCapabilityPresent
        self.serverFactPresent = serverFactPresent
        let revealed = clientCapabilityPresent && serverFactPresent
        if revealed {
            switch phase {
            case .loading, nil: self.phase = .unknown
            case .empty, .error, .unknown, .ready: self.phase = phase
            }
        } else if clientCapabilityPresent, case .loading? = phase {
            self.phase = .loading
        } else {
            self.phase = nil
        }
    }

    /// A decoded score has only literal integers. Zero stays the existing centi zero.
    /// Null settlement stays absent, so points are not filled in as 0.
    public static func facts(from score: OrientSessionScore) -> Facts {
        let summary = OrientScorePresentation.summary(from: score)
        let settlement: Facts.Settlement
        if let row = summary.settlement {
            settlement = .settled(total: row.total, points: String(row.points), xp: String(row.xp))
        } else {
            settlement = .absent
        }
        return Facts(
            sessionID: summary.sessionID,
            phaseText: summary.phase,
            totalText: summary.total,
            dimensions: summary.dimensions,
            settlement: settlement,
            timelineKnown: true,
            timeline: summary.timeline.map {
                TimelineFact(entryID: $0.entryID, deltaText: $0.delta, runningText: $0.running)
            })
    }

    /// `value == nil` with no failure and no load stays hidden: the read has not produced a fact.
    /// `roundPresent == false` is the existing "no round of yours" empty state, not a zero score.
    public static func bind(clientCapabilityPresent: Bool, loading: Bool = false, failed: Bool = false, roundPresent: Bool = true, value: OrientSessionJSON? = nil) -> Self {
        guard clientCapabilityPresent else {
            return Self(clientCapabilityPresent: false, serverFactPresent: false, phase: nil)
        }
        if failed {
            return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .error)
        }
        if loading, value == nil {
            return Self(clientCapabilityPresent: true, serverFactPresent: false, phase: .loading)
        }
        guard let value else {
            if roundPresent {
                return Self(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
            }
            return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .empty)
        }
        if case .object(let fields) = value {
            if fields.isEmpty {
                return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .empty)
            }
            if let facts = makeFacts(fields) {
                return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .ready(facts))
            }
            return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .unknown)
        }
        return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .unknown)
    }

    /// Centi display. Only a JSON integer, or a finite number that is exactly an integer, is a score.
    /// A literal 0 stays "0.00". UNKNOWN, null, a missing value, a numeric string, and a fraction are an em dash.
    public static func scoreText(_ value: OrientSessionJSON?, signed: Bool = false) -> String {
        guard let exact = exactScore(value) else { return unknownDisplay }
        return OrientScoreFormat.centi(exact, signed: signed)
    }

    /// Points and explore XP. A literal 0 stays "0". A numeric string is an em dash, not 0.
    public static func countText(_ value: OrientSessionJSON?) -> String {
        guard let exact = exactScore(value) else { return unknownDisplay }
        return String(exact)
    }

    private static func exactScore(_ value: OrientSessionJSON?) -> Int? {
        guard let value else { return nil }
        switch value {
        case .integer(let number):
            return number
        case .number(let raw):
            guard raw.isFinite, let exact = Int(exactly: raw) else { return nil }
            return exact
        case .string, .bool, .null, .object, .array:
            return nil
        }
    }

    private static func makeFacts(_ fields: [String: OrientSessionJSON]) -> Facts? {
        guard case .integer(let sessionID) = fields["sessionId"], sessionID > 0 else { return nil }
        let phaseText: String
        if case .integer(let status) = fields["status"] {
            phaseText = OrientScorePresentation.phase(status: status)
        } else {
            phaseText = unknownDisplay
        }
        let dimensions = object(fields["byDimension"]) ?? [:]
        let rows = OrientScorePresentation.dimensionOrder.map { key in
            OrientScoreDimensionRow(
                key: key,
                label: OrientScorePresentation.dimensionLabel(key),
                value: scoreText(dimensions[key], signed: true))
        }
        let ledger = timelineFacts(fields["timeline"])
        return Facts(
            sessionID: sessionID,
            phaseText: phaseText,
            totalText: scoreText(fields["totalCenti"]),
            dimensions: rows,
            settlement: settlement(fields["settlement"]),
            timelineKnown: ledger.known,
            timeline: ledger.rows)
    }

    private static func settlement(_ value: OrientSessionJSON?) -> Facts.Settlement {
        switch value {
        case .none, .some(.null):
            return .absent
        case .some(.object(let body)):
            return .settled(total: scoreText(body["totalCenti"]), points: countText(body["pointsAwarded"]), xp: countText(body["xpAwarded"]))
        default:
            return .unknown
        }
    }

    private static func timelineFacts(_ value: OrientSessionJSON?) -> (known: Bool, rows: [TimelineFact]) {
        guard let value, case .array(let rows) = value else { return (false, []) }
        var facts: [TimelineFact] = []
        for row in rows {
            guard case .object(let item) = row,
                  case .integer(let entryID) = item["entryId"], entryID > 0 else { continue }
            facts.append(TimelineFact(
                entryID: entryID,
                deltaText: scoreText(item["deltaCenti"], signed: true),
                runningText: scoreText(item["runningCenti"])))
        }
        return (true, facts)
    }

    private static func object(_ value: OrientSessionJSON?) -> [String: OrientSessionJSON]? {
        guard let value, case .object(let fields) = value else { return nil }
        return fields
    }
}
