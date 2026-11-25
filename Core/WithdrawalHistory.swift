import Foundation
import Observation

/// Role-permission presentation for `subpackageMember/tixian` (`roleGuard.can('withdrawable')`).
public enum WithdrawalRoleGatePresentation: String, Equatable, Sendable {
    case allowed
    case denied
    case unverified

    public init(canWithdraw: Bool?) {
        switch canWithdraw {
        case true:
            self = .allowed
        case false:
            self = .denied
        case nil:
            self = .unverified
        }
    }

    public init(permissions: [String]?) {
        guard let permissions else {
            self = .unverified
            return
        }
        let normalized = Set(permissions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        self = normalized.contains("withdrawable") ? .allowed : .denied
    }

    public var isAllowed: Bool {
        self == .allowed
    }

    public var noticeText: String? {
        switch self {
        case .denied:
            return "当前身份暂不支持提现"
        case .allowed, .unverified:
            return nil
        }
    }
}

/// Theme style for `subpackageMember/tixianjilu` (`theme=merchant` vs member default).
public enum WithdrawalThemeStyle: String, Equatable, Sendable {
    case member
    case merchant

    public init(rawTheme: String?) {
        let normalized = rawTheme?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self = normalized == "merchant" ? .merchant : .member
    }

    public var badgeTitle: String {
        switch self {
        case .merchant:
            return "商家提现"
        case .member:
            return "个人提现"
        }
    }
}

/// Read-only withdrawal history in the mini-program's presentation contract
/// (components/cy/scene-member-withdraw-history). Unlike `WalletWithdrawalRecord`, one
/// unexpected row never fails the table: unknown status reads "status unconfirmed" and a
/// missing or non-numeric `receivedAmount` reads as an explicit dash, never an invented zero.
public struct WithdrawalHistoryRow: Decodable, Equatable {
    public enum Status: String, Equatable { case processing, succeeded, failed, unknown }
    public let id: Int?
    public let status: Status
    /// Server `receivedAmount` (actual amount credited); only a finite, non-negative JSON number.
    public let receivedAmount: Decimal?
    public let createTime: String?
    private enum CodingKeys: String, CodingKey { case id, status, receivedAmount, createTime }
    public init(id: Int?, status: Status, receivedAmount: Decimal?, createTime: String?) {
        self.id = id; self.status = status; self.receivedAmount = receivedAmount; self.createTime = createTime
    }
    public init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.init(id: nil, status: .unknown, receivedAmount: nil, createTime: nil); return
        }
        let id = (try? c.decodeIfPresent(Int.self, forKey: .id)) ?? nil
        let raw = (try? c.decodeIfPresent(Int.self, forKey: .status)) ?? nil
        let amount = (try? c.decodeIfPresent(Decimal.self, forKey: .receivedAmount)) ?? nil
        let time = (try? c.decodeIfPresent(String.self, forKey: .createTime)) ?? nil
        self.init(id: id, status: Self.status(raw), receivedAmount: amount.flatMap { $0.isNaN || $0 < 0 ? nil : $0 },
                  createTime: time.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 })
    }
    /// Source mapping: 0 processing, 1 succeeded, 2 failed and refunded; anything else is unconfirmed.
    public static func status(_ raw: Int?) -> Status {
        switch raw {
        case 0: return .processing
        case 1: return .succeeded
        case 2: return .failed
        default: return .unknown
        }
    }
    public var statusKey: String { "withdrawal.history.status." + status.rawValue }
    /// Two fixed decimals with a leading minus, matching the source; nil renders as a dash.
    public var amountText: String? {
        guard let receivedAmount else { return nil }
        var value = receivedAmount, rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false; formatter.minimumFractionDigits = 2; formatter.maximumFractionDigits = 2
        guard let text = formatter.string(from: NSDecimalNumber(decimal: rounded)) else { return nil }
        return "-" + text
    }
}

public struct WithdrawalHistoryPage: Equatable {
    /// MP `app.getPageSize()`.
    public static let pageSize = 10
    public let rows: [WithdrawalHistoryRow]
    /// Present only when the server returns a table; the current source returns a bare list.
    public let total: Int?
    public init(rows: [WithdrawalHistoryRow], total: Int?) { self.rows = rows; self.total = total }
    public var mayHaveMore: Bool { total.map { $0 > rows.count } ?? false }
    /// MP `getTotalPage(total, pageSize) > pageNum`. A missing total uses the row count.
    public func showsFurtherPage(pageNum: Int, pageSize: Int = WithdrawalHistoryPage.pageSize) -> Bool {
        let count = total ?? rows.count
        guard pageSize > 0, pageNum > 0, count >= 0 else { return false }
        let pages = count / pageSize + (count % pageSize > 0 ? 1 : 0)
        return pages > pageNum
    }
    /// `data` must be an array, `{rows}` or `{list}`; any other shape is a load failure, not empty.
    public static func decode(envelope bytes: Data) throws -> WithdrawalHistoryPage {
        let envelope = try JSONDecoder().decode(Envelope.self, from: bytes)
        return WithdrawalHistoryPage(rows: envelope.rows, total: envelope.total)
    }
    private struct Envelope: Decodable {
        let rows: [WithdrawalHistoryRow]
        let total: Int?
        enum CodingKeys: String, CodingKey { case data }
        enum TableKeys: String, CodingKey { case rows, list, total }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let list = try? c.decode([WithdrawalHistoryRow].self, forKey: .data) { rows = list; total = nil; return }
            let table = try c.nestedContainer(keyedBy: TableKeys.self, forKey: .data)
            if let list = try? table.decode([WithdrawalHistoryRow].self, forKey: .rows) { rows = list }
            else { rows = try table.decode([WithdrawalHistoryRow].self, forKey: .list) }
            let count = (try? table.decodeIfPresent(Int.self, forKey: .total)) ?? (try? table.decodeIfPresent(String.self, forKey: .total)).flatMap { Int($0) }
            total = count.flatMap { $0 >= 0 ? $0 : nil }
        }
    }
}

/// Session-scoped history screen state. Reads go through the existing `WalletCommerceReader`,
/// so the reviewed endpoint approval and stale-owner fences stay authoritative.
@available(macOS 14.0, *)
@MainActor @Observable public final class WithdrawalHistoryCoordinator {
    public enum Phase: Equatable { case idle, loading, ready, empty, login, denied, unavailable, failed }
    public private(set) var phase: Phase = .idle
    public private(set) var page: WithdrawalHistoryPage?
    public private(set) var pageNumber = 0
    public private(set) var loadMoreFailed = false
    private let reader: WalletCommerceReader
    private var generation = 0
    private var loadedScope: WalletCommerceScope?
    public init(reader: WalletCommerceReader) { self.reader = reader }
    /// Rows are visible only while they still belong to the reader's current owner.
    public var rows: [WithdrawalHistoryRow] { loadedScope != nil && loadedScope == reader.scope ? page?.rows ?? [] : [] }
    public var hasMore: Bool {
        guard loadedScope != nil, loadedScope == reader.scope, let loaded = page, pageNumber > 0 else { return false }
        return loaded.showsFurtherPage(pageNum: pageNumber)
    }
    public var canRetry: Bool { phase == .failed || phase == .login }
    public func cancel() { generation += 1; if phase == .loading { phase = .idle } }
    public func load() async {
        generation += 1; let ticket = generation
        let scope = reader.scope
        page = nil; loadedScope = nil; pageNumber = 0; loadMoreFailed = false
        guard reader.isConfigured else { phase = .unavailable; return }
        guard scope != nil else { phase = .login; return }
        phase = .loading
        do {
            let value = try await reader.read { try await $0.withdrawalHistory(pageNum: 1, token: $1) }
            guard ticket == generation, scope == reader.scope else { return }
            page = value; loadedScope = scope; pageNumber = 1
            phase = value.rows.isEmpty ? .empty : .ready
        } catch {
            guard ticket == generation else { return }
            if error is CancellationError { phase = .idle; return }
            phase = Self.phase(for: error)
        }
    }
    /// Next MP page. Rows already on screen stay. A failure sets `loadMoreFailed` and does not clear them.
    public func loadMore() async {
        guard hasMore, phase == .ready, let scope = reader.scope, loadedScope == scope else { return }
        let next = pageNumber + 1
        generation += 1; let ticket = generation
        loadMoreFailed = false
        do {
            let fetched = try await reader.read { try await $0.withdrawalHistory(pageNum: next, token: $1) }
            guard ticket == generation, scope == reader.scope else { return }
            let existing = page?.rows ?? []
            let accumulated = existing + fetched.rows
            let count = fetched.total ?? accumulated.count
            page = WithdrawalHistoryPage(rows: accumulated, total: count)
            pageNumber = next
            phase = accumulated.isEmpty ? .empty : .ready
        } catch {
            guard ticket == generation else { return }
            if error is CancellationError { return }
            loadMoreFailed = true
        }
    }
    public static func phase(for error: Error) -> Phase {
        switch error {
        case APIError.unauthorized, APIError.httpStatus(401), APIError.businessCode(401): return .login
        case APIError.httpStatus(403), APIError.businessCode(403): return .denied
        case APIError.notConfigured, WalletCommerceSafetyError.unavailable: return .unavailable
        case WalletCommerceSafetyError.staleSession: return .idle
        default: return .failed
        }
    }
}


/// One China-calendar day of withdrawal history rows (Revolut-style date-grouped list).
/// `dayKey` is `yyyy-MM-dd`; nil collects rows whose server time is missing or unparseable.
public struct WithdrawalHistoryDayGroup: Equatable {
    public let dayKey: String?
    public let rows: [WithdrawalHistoryRow]
    public init(dayKey: String?, rows: [WithdrawalHistoryRow]) {
        self.dayKey = dayKey; self.rows = rows
    }
}

/// Read-only presentation rules. Days follow `MoneyParityTime` (China calendar), the same
/// rule the mini-program uses; no amount is computed here and nothing is sent.
public enum WithdrawalHistoryGrouping {
    /// Groups keep first-seen order (server order is newest first); undated rows come last.
    public static func groups(_ rows: [WithdrawalHistoryRow]) -> [WithdrawalHistoryDayGroup] {
        var order: [String] = []
        var buckets: [String: [WithdrawalHistoryRow]] = [:]
        var undated: [WithdrawalHistoryRow] = []
        for row in rows {
            guard let key = dayKey(row.createTime) else { undated.append(row); continue }
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(row)
        }
        var result = order.map { WithdrawalHistoryDayGroup(dayKey: $0, rows: buckets[$0] ?? []) }
        if !undated.isEmpty { result.append(WithdrawalHistoryDayGroup(dayKey: nil, rows: undated)) }
        return result
    }

    public static func dayKey(_ raw: String?) -> String? {
        guard let ms = MoneyParityTime.timestamp(raw) else { return nil }
        return civilKey(daysSinceEpoch: MoneyParityTime.chinaDayIndex(ms))
    }

    private static func pad(_ value: Int64, _ width: Int) -> String {
        let text = String(value)
        return text.count >= width ? text : String(repeating: "0", count: width - text.count) + text
    }

    /// Howard Hinnant's civil-from-days; days are counted from 1970-01-01.
    static func civilKey(daysSinceEpoch days: Int64) -> String {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        let year = yoe + era * 400 + (month <= 2 ? 1 : 0)
        return pad(year, 4) + "-" + pad(month, 2) + "-" + pad(day, 2)
    }
}
