import Foundation

/// Presents the `/api/club/topic-setting/end` reply of mini-program `pages/club/topic-detail`
/// (`confirmEndTopic` + `endResultText`). Parsing is strict on purpose: anything the source treats
/// as 「结束结果尚未确认」 stays unconfirmed here and never reads as success.
public struct ClubTopicEndSummary: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        /// Every session cancelled and the server state is DONE.
        case done
        /// Server state PENDING with no failed sessions: keep the original request and read it back.
        case stillProcessing
        /// Some sessions could not be cancelled; the first failure reason is shown, the sheet stays open.
        case partialFailure(count: Int, firstReason: String)
        /// Missing or malformed fields, or a different cancellation epoch than the one sent.
        case unconfirmed
    }
    public let outcome: Outcome
    public let sessionTotal: Int
    public let cancelledSessions: Int
    public let refundedOrders: Int
    public let manualOrders: Int
    public let closedPendingOrders: Int

    public static func parse(_ value: ClubGovernanceValue, sentEpoch: Int) -> ClubTopicEndSummary {
        func count(_ key: String) -> Int? {
            if case .integer(let n) = value[key], n >= 0 { return n }
            return nil
        }
        let unconfirmed = ClubTopicEndSummary(outcome: .unconfirmed, sessionTotal: 0, cancelledSessions: 0, refundedOrders: 0, manualOrders: 0, closedPendingOrders: 0)
        // MP topic-detail/index.js:1156: the reply epoch may be a number or its decimal string.
        guard let epoch = value["cancellationEpoch"].int, epoch == sentEpoch,
              let failed = value["failedSessions"].array, failed.allSatisfy({ $0.string != nil }),
              let state = value["cancellationState"].string, state == "PENDING" || state == "DONE",
              let total = count("sessionTotal"), let cancelled = count("cancelledSessions"), let refunded = count("refundedOrders"),
              let manual = count("manualOrders"), let closed = count("closedPendingOrders") else { return unconfirmed }
        let outcome: Outcome
        if let first = failed.first?.string { outcome = .partialFailure(count: failed.count, firstReason: first) }
        else if state == "DONE" { outcome = .done }
        else { outcome = .stillProcessing }
        return ClubTopicEndSummary(outcome: outcome, sessionTotal: total, cancelledSessions: cancelled, refundedOrders: refunded, manualOrders: manual, closedPendingOrders: closed)
    }
    /// `endResultText`: manual orders must be stated, never swallowed.
    public func resultText(chinese: Bool) -> String {
        if manualOrders > 0 { return chinese ? "\(manualOrders) 笔需人工处理" : "\(manualOrders) order(s) need manual handling" }
        if refundedOrders > 0 { return chinese ? "已结束，退款 \(refundedOrders) 笔" : "Ended; \(refundedOrders) order(s) refunded" }
        return chinese ? "已结束，无可退订单" : "Ended; no orders to refund"
    }
    public func errorText(chinese: Bool) -> String? {
        switch outcome {
        case .done: return nil
        case .stillProcessing: return chinese ? "原结束请求仍在处理中，请按原请求查回" : "The original end request is still processing. Check it again."
        case .partialFailure(let count, let reason): return chinese ? "\(count) 场没能取消：\(reason)" : "\(count) session(s) could not be canceled: \(reason)"
        case .unconfirmed: return chinese ? "结束结果尚未确认，请保留原请求重试" : "The result is not confirmed yet. Keep the original request and retry."
        }
    }
    public var shouldCloseSheet: Bool { outcome == .done }
}
