import Foundation

/// Page-ready facts for `subpackageMember/orderinfo/orderinfo` over the existing order detail read
/// (`OrderLifecycleCoordinator.detail`, `OrderLifecycleDetail`). Presentation only: it builds no
/// request, dispatches no cancel, refund or payment, and keeps every money write switch off.
/// A missing amount or time is an em dash, never 0; a literal 0 amount stays "0". No currency is inferred.
public enum OrderInfoPageModel {
    public static let unknownMark = "\u{2014}"
    public static let loadingIdentifier = "orderLifecycle.loading"
    public static let errorIdentifier = "orderLifecycle.issue"
    public static let unknownIdentifier = "orderLifecycle.unknown"
    public static let readyIdentifier = "orderLifecycle.summary"

    /// This page model never enables a payment or refund action. Actions stay with the
    /// coordinator's own review and dispatch gates.
    public static var paymentEnabled: Bool { ReleaseMoneyWriteSwitch.paymentEnabled }
    public static var payoutEnabled: Bool { ReleaseMoneyWriteSwitch.payoutEnabled }

    public struct TimelineEntry: Equatable, Identifiable {
        public let id: String
        public let labelKey: String
        /// Only a completed step shows a time; a completed step with no server time is an em dash.
        public let timeText: String?
        public let done: Bool
    }

    public struct Snapshot: Equatable {
        public let orderID: Int
        public let state: OrderLifecycleState
        /// Local explanation key. Server prose stays separate and is shown verbatim.
        public let explanationKey: String
        public let serverReason: String?
        public let title: String?
        public let ticketName: String?
        public let registrationNumber: String?
        public let payableAmountText: String
        public let refundAmountText: String?
        public let createTimeText: String
        public let timeline: [TimelineEntry]
        public let accessibilityIdentifier: String
    }

    public enum Phase: Equatable {
        case loading
        case error(OrderLifecycleCoordinatorIssue)
        case unknown
        case ready(Snapshot)
    }

    public static func moneyText(_ amount: Decimal?) -> String {
        guard let amount, !amount.isNaN else { return unknownMark }
        return NSDecimalNumber(decimal: amount).stringValue
    }

    public static func timeText(_ raw: String?) -> String {
        OrderLifecycleTime.display(raw) ?? unknownMark
    }

    /// A coordinator issue wins. Signed out and unconfigured readers are their own issue, never an
    /// empty order. A detail for a different order id is not shown. No detail is `.loading` while
    /// a read runs and `.unknown` otherwise.
    public static func phase(orderID: Int, signedIn: Bool, configured: Bool, loading: Bool,
                             issue: OrderLifecycleCoordinatorIssue?, detail: OrderLifecycleDetail?,
                             now: Date = Date()) -> Phase {
        guard signedIn else { return .error(.login) }
        if let issue { return .error(issue) }
        guard configured else { return .error(.notConfigured) }
        if let detail, detail.id == orderID, orderID > 0 { return .ready(snapshot(detail, now: now)) }
        return loading ? .loading : .unknown
    }

    @MainActor public static func phase(orderID: Int, coordinator: OrderLifecycleCoordinator,
                                        configured: Bool = true, now: Date = Date()) -> Phase {
        phase(orderID: orderID, signedIn: coordinator.accountID != nil, configured: configured,
              loading: coordinator.isLoading, issue: coordinator.issue, detail: coordinator.detail, now: now)
    }

    static func snapshot(_ detail: OrderLifecycleDetail, now: Date) -> Snapshot {
        let summary = detail.summary(now: now)
        let entries = detail.timeline(now: now).map { row in
            TimelineEntry(id: row.id, labelKey: row.labelKey,
                          timeText: row.done ? (row.time ?? unknownMark) : nil, done: row.done)
        }
        let registrationNumber = detail.registrationNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Snapshot(
            orderID: detail.id,
            state: summary.state,
            explanationKey: summary.explanationKey,
            serverReason: summary.serverReason,
            title: nonBlank(detail.title),
            ticketName: nonBlank(detail.ticketName),
            registrationNumber: registrationNumber?.isEmpty == false ? registrationNumber : nil,
            payableAmountText: moneyText(detail.payableAmount),
            refundAmountText: detail.refundApplication.map { moneyText($0.amount) },
            createTimeText: timeText(detail.createTime),
            timeline: entries,
            accessibilityIdentifier: readyIdentifier
        )
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
