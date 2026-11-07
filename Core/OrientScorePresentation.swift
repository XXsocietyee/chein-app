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
            appeals: reviews(score.appealRecords), disputes: reviews(score.disputeRecords))
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
