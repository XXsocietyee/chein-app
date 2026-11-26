import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MP `pages/club/settlement/index` & `components/cy/fe-reference-settlement` (`CLB-G17`, `MC-G04`):
/// Read-only by default; `settle` and `dispute` money writes stay gated behind `allowsMoneyWrite` (TEST-only).
public struct FEReferenceSettlementItem: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let counterpartName: String?
    public let amountText: String
    public let statusText: String
    public let canSettle: Bool
    public let canDispute: Bool

    public init(
        id: Int,
        title: String,
        counterpartName: String? = nil,
        amountText: String,
        statusText: String,
        canSettle: Bool = false,
        canDispute: Bool = false
    ) {
        self.id = id
        self.title = title
        self.counterpartName = counterpartName
        self.amountText = amountText
        self.statusText = statusText
        self.canSettle = canSettle
        self.canDispute = canDispute
    }
}

public enum FEReferenceSettlementRole: String, Sendable {
    case payer
    case merchant
}

/// Settle and dispute stay off. List and export reads are not on this switch.
public enum FEReferenceSettlementMoneyWrite {
    /// CLB-r11-settlement-01 (MP components/cy/fe-reference-settlement/index.js:57-75): 标记已结清 is a payout-kind
    /// money write. Owner 11-26: money is on in Release, so it follows `ReleaseMoneyWriteSwitch` `.payout`.
    public static var enabled: Bool { ReleaseMoneyWriteSwitch.isEnabled(.payout) }
}

public enum FEReferenceSettlementCopy {
    public static let sectionTitle = "自由探索结算（参考）"
    public static let markSettled = "标记已结清"
    public static let dispute = "发起异议"
    public static let moneyGateNote = "结算打款操作仅在 TEST 环境开放"
    public static let emptyTitle = "暂无自由探索参考结算"
}

public struct ClubFEReferenceSettlementClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func list(role: FEReferenceSettlementRole, from: String? = nil, to: String? = nil, token: String) async throws -> [FEReferenceSettlementItem] {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        let path = role == .payer ? "api/fe/reference-settlement/payer" : "api/fe/reference-settlement/merchant"
        return try await MPGapHTTP.getJSON(
            configuration: configuration,
            transport: transport,
            path: path,
            queryItems: Self.query(from: from, to: to),
            token: token
        )
    }

    /// Money write: withheld unless the caller asked and the default-off flag is on.
    public func markSettled(ids: [Int], voucherNo: String? = nil, token: String, allowsMoneyWrite: Bool) async throws -> Bool {
        guard allowsMoneyWrite, FEReferenceSettlementMoneyWrite.enabled else { return false }
        let validIDs = ids.filter { $0 > 0 }
        guard !validIDs.isEmpty else { throw APIError.invalidRequest }
        var body: [String: Any] = ["ids": validIDs]
        if let voucherNo, !voucherNo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["voucherNo"] = voucherNo.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/fe/reference-settlement/settle",
            body: body,
            token: token
        )
        return true
    }

    /// Money write. Body is `{id, note}`. Sends nothing while the flag is off.
    public func dispute(id: Int, note: String, token: String, allowsMoneyWrite: Bool) async throws -> Bool {
        guard allowsMoneyWrite, FEReferenceSettlementMoneyWrite.enabled else { return false }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id > 0, !trimmed.isEmpty else { throw APIError.invalidRequest }
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/fe/reference-settlement/dispute",
            body: ["id": id, "note": trimmed],
            token: token
        )
        return true
    }

    static func query(from: String?, to: String?) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        let start = from?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let end = to?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !start.isEmpty { items.append(URLQueryItem(name: "from", value: start)) }
        if !end.isEmpty { items.append(URLQueryItem(name: "to", value: end)) }
        return items
    }
}
