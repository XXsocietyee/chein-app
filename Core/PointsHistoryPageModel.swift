import Foundation

/// Page-ready facts for `subpackageMember/points-history/index` over the existing points ledger read
/// (`WalletLedgerKind.points`, `api/user/points/list`, rows `WalletLedgerRow`). Presentation only:
/// it builds no request and opens no route. The server ignores a direction filter, so the 获得 / 使用
/// segment filters the loaded rows here. A missing number or time is an em dash; a literal 0 stays "0".
public enum PointsHistoryPageModel {
    public static let unknownMark = "\u{2014}"
    public static let loadingIdentifier = "wallet.points.loading"
    public static let emptyIdentifier = "wallet.points.empty"
    public static let errorIdentifier = "wallet.points.error"
    public static let unknownIdentifier = "wallet.points.unknown"
    public static let readyIdentifier = "wallet.points.ready"
    // Existing Localizable keys; no new string is registered here.
    public static let failedKey = "wallet.failed"
    public static let signInKey = "wallet.login"
    public static let unavailableKey = "wallet.unavailable"

    /// The segmented control of the source page.
    public enum Direction: String, CaseIterable, Equatable {
        case all, income, expense
    }

    public struct Row: Equatable, Identifiable {
        public let id: Int
        public let direction: WalletDirection
        /// `+12` / `−3`, or an em dash when the row carries no amount.
        public let changeText: String
        public let afterText: String
        public let reason: String?
        public let timeText: String
    }

    public struct Snapshot: Equatable {
        public let rows: [Row]
        public let totalText: String
        public let hasMore: Bool
        public let accessibilityIdentifier: String
    }

    public enum Phase: Equatable {
        case loading
        /// `key` is `WalletPointsLedgerEmptyState` copy: a filtered-empty ledger names the direction.
        case empty(key: String)
        case error(titleKey: String)
        case unknown
        case ready(Snapshot)
    }

    public static func countText(_ count: Int?) -> String {
        guard let count, count >= 0 else { return unknownMark }
        return String(count)
    }

    public static func errorKey(for error: Error) -> String {
        switch error {
        case APIError.unauthorized: return signInKey
        case APIError.notConfigured: return unavailableKey
        default: return failedKey
        }
    }

    /// `rows` nil means no page has been accepted. A failure wins. No rows yet is `.loading`
    /// while a request runs and `.unknown` otherwise, never an empty ledger. `total` nil is unknown;
    /// continuation uses the source rule (loaded < total, or a full page when no total exists).
    public static func load(direction: Direction, loading: Bool, failure: Error?,
                            rows: [WalletLedgerRow]?, total: Int?, pageSize: Int?) -> Phase {
        if let failure { return .error(titleKey: errorKey(for: failure)) }
        guard let rows else { return loading ? .loading : .unknown }
        let visible = rows.filter { matches($0, direction: direction) }
        if visible.isEmpty {
            let key = WalletPointsLedgerEmptyState.key(
                direction: rows.isEmpty ? Direction.all.rawValue : direction.rawValue,
                isIncomeLedger: false, isPointsLedger: true)
            return .empty(key: key)
        }
        return .ready(Snapshot(rows: visible.map(row), totalText: countText(total),
                               hasMore: hasMore(loadedCount: rows.count, total: total, pageSize: pageSize),
                               accessibilityIdentifier: readyIdentifier))
    }

    static func matches(_ row: WalletLedgerRow, direction: Direction) -> Bool {
        switch direction {
        case .all: return true
        case .income: return row.assetDirection == .income
        case .expense: return row.assetDirection == .expense
        }
    }

    static func hasMore(loadedCount: Int, total: Int?, pageSize: Int?) -> Bool {
        if let total { return loadedCount < total }
        guard let pageSize, pageSize > 0 else { return false }
        return loadedCount > 0 && loadedCount % pageSize == 0
    }

    static func row(_ value: WalletLedgerRow) -> Row {
        let reason = value.changeReason?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Row(id: value.id, direction: value.assetDirection,
                   changeText: value.signedText(points: true, income: false) ?? unknownMark,
                   afterText: value.afterPoints?.text ?? unknownMark,
                   reason: reason?.isEmpty == false ? reason : nil,
                   timeText: OrderLifecycleTime.display(value.createTime) ?? unknownMark)
    }
}
