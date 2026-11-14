import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// WP-01. Club owner personal receiver, merchant payout account, the owner's settlement club list, the
/// club settlement summary (personal view) and the club-direct merchant ledger.
/// Ports mini-program `pages/club/payout-receiver`, `pages/merchant/payout-account`, `pages/club/settlement`
/// and `components/cy/club-direct-ledger`. Every value shown is a server fact; nothing is inferred or zero-filled.
/// Bind, unbind and the payout-account read are payout routes: `PayoutReceiverTransport` sends none of them while
/// `ReleaseMoneyWriteSwitch.payoutEnabled` is false, and the China production host refuses them as well.
public enum PayoutReceiverRoute: String, CaseIterable, Sendable {
    case settlementMine = "api/club/settlement/mine"
    case settlementSummary = "api/club/settlement/summary"
    case receiverStatus = "api/club/personal-receiver/status"
    case receiverBind = "api/club/personal-receiver/bind"
    case receiverUnbind = "api/club/personal-receiver/unbind"
    case merchantPayoutAccount = "api/merchant/payout-account"
    case directLedgerClub = "api/club-direct-merchant/club"
    case directLedgerMerchant = "api/club-direct-merchant/merchant"

    public var method: String {
        switch self {
        case .receiverStatus, .directLedgerClub, .directLedgerMerchant: return "GET"
        default: return "POST"
        }
    }

    /// Payout-kind routes in `ReleaseMoneyWriteSwitch`. The receivable ledgers and settlement reads move no money.
    public var isPayout: Bool { self == .receiverBind || self == .receiverUnbind || self == .merchantPayoutAccount }

    /// Query keys a GET may carry. POST routes carry no query.
    var queryKeys: Set<String> {
        switch self {
        case .receiverStatus: return ["clubId"]
        case .directLedgerClub: return ["clubId", "topicId"]
        case .directLedgerMerchant: return ["topicId"]
        default: return []
        }
    }

    public init?(request: URLRequest) {
        guard let url = request.url, url.fragment == nil, url.user == nil, url.password == nil,
              let method = request.httpMethod else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let route = Self.allCases.first(where: { route in
            let want = route.rawValue.split(separator: "/").map(String.init)
            return parts.count >= want.count && Array(parts.suffix(want.count)) == want
        }), route.method == method else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if method == "POST" {
            guard items.isEmpty else { return nil }
        } else {
            guard request.httpBody == nil || request.httpBody?.isEmpty == true,
                  Set(items.map(\.name)).isSubset(of: route.queryKeys), Set(items.map(\.name)).count == items.count else { return nil }
        }
        self = route
    }
}

/// Forwards only the eight WP-01 routes. A payout route sends nothing while the payout switch is off.
public struct PayoutReceiverTransport: HTTPTransport {
    private let underlying: any HTTPTransport
    private let payoutEnabled: () -> Bool
    public init(underlying: any HTTPTransport, payoutEnabled: @escaping () -> Bool = { ReleaseMoneyWriteSwitch.payoutEnabled }) {
        self.underlying = underlying; self.payoutEnabled = payoutEnabled
    }
    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        guard let route = PayoutReceiverRoute(request: request) else { throw APIError.notConfigured }
        if route.isPayout, !payoutEnabled() { throw APIError.notConfigured }
        try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request)
        return try await underlying.send(request)
    }
}

/// A failed read or write. `code` is a recognized server machine code; `message` is a human server sentence
/// (the mini-program shows Chinese business text as is and never shows an upper-case code).
public enum PayoutReceiverIssue: Error, Equatable {
    case closed
    case unauthorized
    case network
    case malformed
    case rejected(code: String?, message: String?)

    /// Codes with their own copy in the `PayoutReceiver` table (mini-program `ERROR_TEXT`).
    public static let knownCodes: Set<String> = [
        "PERSONAL_RECEIVER_IDENTITY_MISMATCH", "PERSONAL_RECEIVER_IDENTITY_IMMUTABLE",
        "PERSONAL_RECEIVER_PROVIDER_NOT_CONFIRMED", "PERSONAL_RECEIVER_APPID_MISMATCH",
        "CLUB_OWNER_REQUIRED", "CLUB_REQUIRED", "WECHAT_FRESH_CODE_EXCHANGE_FAILED",
        "WECHAT_MINI_IDENTITY_REQUIRED", "MEMBER_UNAVAILABLE"
    ]

    /// `payoutReceiver.error.<CODE>` for a known code, nil otherwise.
    public var codeKey: String? {
        if case .rejected(let code?, _) = self, Self.knownCodes.contains(code) { return "payoutReceiver.error." + code }
        return nil
    }

    /// A server sentence that is not a machine code. Upper-case codes are never shown.
    public var serverSentence: String? {
        guard case .rejected(_, let message?) = self else { return nil }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.range(of: "^[A-Z0-9_]+$", options: .regularExpression) == nil,
              trimmed != "操作成功" else { return nil }
        return trimmed
    }
}

// MARK: - Shapes

/// `/api/club/personal-receiver/status` shaped like mini-program `view-model.js shapeStatus`.
public struct ClubPayoutReceiverStatus: Equatable, Sendable {
    public enum PageState: String, Equatable, Sendable { case unbound, bound, paused }
    public let pageState: PageState
    /// Mini-program 「平台开通后开始」 when payout is not yet enabled by the platform.
    public let payoutPending: Bool
    /// Pause reason key; only `PERSONAL_BINDING_REQUIRED` is known, every other reason uses the same copy.
    public let paused: Bool
    public let canUnbind: Bool

    public var stateKey: String { "payoutReceiver.state." + pageState.rawValue }
    public var tone: String { pageState == .bound ? "success" : (pageState == .paused ? "warning" : "neutral") }
    /// Bind is offered when unbound; 「重新绑定」 when paused.
    public var bindKey: String? {
        switch pageState {
        case .unbound: return "payoutReceiver.bind"
        case .paused: return "payoutReceiver.rebind"
        case .bound: return nil
        }
    }

    public init?(data: Any?) {
        guard let object = data as? [String: Any], object["available"] as? Bool == true,
              let state = object["receiverState"] as? String, ["UNBOUND", "CONSENTED", "VERIFIED"].contains(state) else { return nil }
        let bound = state != "UNBOUND"
        paused = object["paused"] as? Bool == true
        payoutPending = object["payoutEnabled"] as? Bool != true
        pageState = !bound ? .unbound : (paused ? .paused : .bound)
        canUnbind = bound && object["canUnbind"] as? Bool == true
    }
}

/// `/api/merchant/payout-account` shaped like mini-program `payout-account/view-model.js shapeAccount`.
public struct MerchantPayoutAccount: Equatable, Sendable {
    public enum PageState: Equatable, Sendable { case unavailable, none, ready }
    public static let states = ["NONE", "DRAFT", "CHECKING", "ACCOUNT_NEED_VERIFY", "AUDITING", "REJECTED", "NEED_SIGN", "FINISH", "FROZEN", "CANCELED"]
    public let pageState: PageState
    public let state: String?
    public let stateDescription: String?
    public let signURL: URL?
    public let maskedSubMerchantID: String?
    public let checkedAt: Date?

    public var stateKey: String? { state.map { "payoutAccount.state." + $0 } }
    public var tone: String {
        switch state {
        case "FINISH": return "success"
        case "REJECTED", "FROZEN": return "danger"
        case "NEED_SIGN", "ACCOUNT_NEED_VERIFY": return "warning"
        default: return "neutral"
        }
    }
    /// 「复制签约链接」 or 「复制验证链接」.
    public var copyKey: String? {
        guard signURL != nil else { return nil }
        return state == "NEED_SIGN" ? "payoutAccount.copySign" : "payoutAccount.copyVerify"
    }

    public init?(data: Any?) {
        guard let object = data as? [String: Any] else { return nil }
        guard object["available"] as? Bool == true else {
            pageState = .unavailable; state = nil; stateDescription = nil; signURL = nil; maskedSubMerchantID = nil; checkedAt = nil
            return
        }
        guard let raw = object["state"] as? String, Self.states.contains(raw) else { return nil }
        if raw == "NONE" {
            pageState = .none; state = raw; stateDescription = nil; signURL = nil; maskedSubMerchantID = nil; checkedAt = nil
            return
        }
        pageState = .ready
        state = raw
        let description = (object["stateDesc"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        stateDescription = raw != "FINISH" && description?.isEmpty == false ? description : nil
        if let link = object["signUrl"] as? String, link.hasPrefix("https://"), raw == "NEED_SIGN" || raw == "ACCOUNT_NEED_VERIFY" {
            signURL = URL(string: link)
        } else { signURL = nil }
        let masked = object["subMchidMasked"] as? String
        maskedSubMerchantID = (raw == "FINISH" || raw == "FROZEN") && masked?.isEmpty == false ? masked : nil
        checkedAt = Self.date(object["checkedAt"])
    }

    static func date(_ value: Any?) -> Date? {
        if let number = value as? Double { return Date(timeIntervalSince1970: number > 1e12 ? number / 1000 : number) }
        if let number = value as? Int { return Date(timeIntervalSince1970: Double(number) > 1e12 ? Double(number) / 1000 : Double(number)) }
        guard let text = value as? String, !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return ISO8601DateFormatter().date(from: text)
    }
}

/// One row of `/api/club/settlement/mine`.
public struct PayoutSettlementClub: Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String
}

/// `/api/club/settlement/summary`, the full mini-program `normalizeSummary` (topics and F-16 sessions). Fail-closed.
public struct ClubSettlementSummaryView: Equatable, Sendable {
    public struct Topic: Equatable, Identifiable, Sendable {
        public let id: Int
        public let topicID: Int
        public let name: String
        /// nil when the server marked the amount unverified (「待核验」).
        public let amountText: String?
        public let originalAmountText: String
        public let executedAdjustmentText: String
        public let netAmountText: String
        public let arrivedText: String
        public let paidText: String
        public let status: String
        public var chipKey: String {
            if status == "void" { return "clubSettlement.chip.void" }
            if status == "pending" { return "clubSettlement.chip.pending" }
            return amountText == nil ? "clubSettlement.chip.unverified" : "clubSettlement.chip.settled"
        }
        /// The meta line under the chip only when the chip cannot say it all.
        public var showsPaidText: Bool { status == "void" || amountText == nil }
    }
    public struct Session: Equatable, Identifiable, Sendable {
        public var id: Int { activityID }
        public let activityID: Int
        public let name: String
        public let dateText: String
        public let netText: String
        public let payeeText: String
        public let grossText: String?
        public let feeText: String?
        public let feeRateText: String?
        public let merchantFeeText: String?
    }
    public let settledAmountText: String?
    public let unverifiedSettledCount: Int
    public let topics: [Topic]
    public let sessions: [Session]
    public let isOwner: Bool
    public let personal: Bool
    public var isEmpty: Bool { topics.isEmpty && sessions.isEmpty }

    public init?(data: Any?) {
        guard let object = data as? [String: Any], let unverified = object["unverifiedSettledCount"] as? Int, unverified >= 0 else { return nil }
        let settledText = Self.text(object["settledAmountText"])
        switch object["settledAmountStatus"] as? String {
        case "verified": guard settledText != nil, unverified == 0 else { return nil }
        case "unverified": guard object["settledAmountText"] is NSNull || object["settledAmountText"] == nil, unverified > 0 else { return nil }
        default: return nil
        }
        guard let rawTopics = object["topics"] as? [[String: Any]] else { return nil }
        var seen = Set<Int>(), missing = 0, topics: [Topic] = []
        for row in rawTopics {
            guard let id = Self.positive(row["id"]), let topicID = Self.positive(row["topicId"]), !seen.contains(id),
                  let name = Self.text(row["name"]), let arrived = Self.text(row["arrivedText"]), let paid = Self.text(row["paidText"]),
                  let original = Self.text(row["originalAmountText"]), let adjustment = Self.text(row["executedAdjustmentText"]),
                  let net = Self.text(row["netAmountText"]), let status = row["status"] as? String,
                  ["settled", "pending", "void"].contains(status) else { return nil }
            let amount: String?
            switch row["amountStatus"] as? String {
            case "unverified":
                guard status == "settled", Self.text(row["amountText"]) == nil else { return nil }
                missing += 1; amount = nil
            case "verified":
                guard let text = Self.text(row["amountText"]) else { return nil }
                amount = text
            default: return nil
            }
            seen.insert(id)
            topics.append(Topic(id: id, topicID: topicID, name: name, amountText: amount, originalAmountText: original,
                                executedAdjustmentText: adjustment, netAmountText: net, arrivedText: arrived, paidText: paid, status: status))
        }
        guard missing == unverified else { return nil }
        let personal = object["personal"] as? Bool == true
        guard let rawSessions = object["sessions"] as? [[String: Any]] else { return nil }
        var sessions: [Session] = []
        for row in rawSessions {
            guard let activityID = Self.positive(row["activityId"]), let name = Self.text(row["name"]),
                  let date = Self.text(row["dateText"]), let net = Self.text(row["netText"]), let payee = Self.text(row["payeeText"]) else { return nil }
            if personal {
                sessions.append(Session(activityID: activityID, name: name, dateText: date, netText: net, payeeText: payee,
                                        grossText: nil, feeText: nil, feeRateText: nil, merchantFeeText: nil))
                continue
            }
            guard let gross = Self.text(row["grossText"]), let fee = Self.text(row["feeText"]) else { return nil }
            let rate = row["feeRateText"]
            guard rate == nil || rate is NSNull || Self.text(rate) != nil else { return nil }
            let merchantFee = row["merchantFeeText"]
            guard merchantFee == nil || merchantFee is NSNull || Self.text(merchantFee) != nil else { return nil }
            sessions.append(Session(activityID: activityID, name: name, dateText: date, netText: net, payeeText: payee,
                                    grossText: gross, feeText: fee, feeRateText: Self.text(rate), merchantFeeText: Self.text(merchantFee)))
        }
        settledAmountText = unverified == 0 ? settledText : nil
        unverifiedSettledCount = unverified
        self.topics = topics
        self.sessions = sessions
        isOwner = object["isOwner"] as? Bool == true
        self.personal = personal
    }

    static func text(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return text
    }
    static func positive(_ value: Any?) -> Int? {
        if let number = value as? Int, number > 0 { return number }
        if let text = value as? String, let number = Int(text), number > 0 { return number }
        return nil
    }
}

/// `components/cy/club-direct-ledger/view-model.js ledgerView`. Amounts are cents built from `perHeadFeeSnapshot`.
public struct ClubDirectLedger: Equatable, Sendable {
    public enum Scope: Equatable, Sendable {
        case club(clubID: Int, topicID: Int?)
        case merchant(topicID: Int?)
    }
    public struct Row: Equatable, Identifiable, Sendable {
        public let id: Int
        public let redemptionID: Int
        public let amountCents: Int
        public let status: String
        public let claimNumber: String?
        public let timeText: String
        public let voucher: String?
        public var statusKey: String { "directLedger.status." + status }
    }
    public static let statuses: Set<String> = ["OPEN", "SETTLED", "VOID", "REFUND_DUE", "REFUNDED"]
    public let rows: [Row]
    public let activeCount: Int
    public let openCents: Int
    public let settledCents: Int
    public let refundDueCents: Int

    public static func amountText(_ cents: Int) -> String {
        let sign = cents < 0 ? "-" : ""
        let value = abs(cents)
        return "\(sign)¥\(value / 100).\(String(format: "%02d", value % 100))"
    }

    public init?(data: Any?, scope: Scope) {
        guard let list = data as? [Any] else { return nil }
        let filterTopic: Int?
        switch scope {
        case .club(let clubID, let topicID):
            guard clubID > 0, topicID.map({ $0 > 0 }) ?? true else { return nil }
            filterTopic = topicID
        case .merchant(let topicID):
            guard topicID.map({ $0 > 0 }) ?? true else { return nil }
            filterTopic = topicID
        }
        var seen = Set<Int>(), rows: [Row] = [], active = 0
        var open = 0, settled = 0, refund = 0
        for item in list {
            guard let row = item as? [String: Any], let id = ClubSettlementSummaryView.positive(row["id"]), !seen.contains(id),
                  let redemption = ClubSettlementSummaryView.positive(row["redemptionId"]),
                  let topic = ClubSettlementSummaryView.positive(row["topicId"]),
                  let payerClub = ClubSettlementSummaryView.positive(row["payerClubId"]),
                  ClubSettlementSummaryView.positive(row["merchantMemberId"]) != nil,
                  let status = row["status"] as? String, Self.statuses.contains(status),
                  let cents = Self.cents(row["perHeadFeeSnapshot"]) else { return nil }
            if let filterTopic, topic != filterTopic { return nil }
            if case .club(let clubID, _) = scope, payerClub != clubID { return nil }
            seen.insert(id)
            if status == "OPEN" || status == "SETTLED" { active += 1 }
            var overflow = false
            switch status {
            case "OPEN": (open, overflow) = open.addingReportingOverflow(cents)
            case "SETTLED": (settled, overflow) = settled.addingReportingOverflow(cents)
            case "REFUND_DUE": (refund, overflow) = refund.addingReportingOverflow(cents)
            default: break
            }
            guard !overflow else { return nil }
            let voucher: String?
            switch status {
            case "SETTLED", "REFUND_DUE": voucher = ClubSettlementSummaryView.text(row["payVoucherNo"])
            case "REFUNDED": voucher = ClubSettlementSummaryView.text(row["refundVoucherNo"])
            default: voucher = nil
            }
            let time = (row["createTime"] as? String).map { String($0.prefix(16)).replacingOccurrences(of: "T", with: " ") } ?? ""
            rows.append(Row(id: id, redemptionID: redemption, amountCents: cents, status: status,
                            claimNumber: Self.claimNumber(row["claimId"]), timeText: time, voucher: voucher))
        }
        self.rows = rows
        activeCount = active
        openCents = open; settledCents = settled; refundDueCents = refund
    }

    static func cents(_ value: Any?) -> Int? {
        let raw: String
        if let text = value as? String { raw = text }
        else if let number = value as? NSNumber { raw = number.stringValue }
        else { return nil }
        guard raw.range(of: "^\\d+(\\.\\d{1,2})?$", options: .regularExpression) != nil else { return nil }
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard let whole = Int(parts[0]) else { return nil }
        let fraction = parts.count > 1 ? String(parts[1]).padding(toLength: 2, withPad: "0", startingAt: 0) : "00"
        guard let minor = Int(fraction) else { return nil }
        let (scaled, o1) = whole.multipliedReportingOverflow(by: 100)
        let (total, o2) = scaled.addingReportingOverflow(minor)
        return o1 || o2 ? nil : total
    }

    /// Internal record number, only for support. Keeps Java Long precision as a string.
    static func claimNumber(_ value: Any?) -> String? {
        if let number = value as? Int { return number > 0 ? String(number) : nil }
        guard let text = value as? String, text.range(of: "^\\d+$", options: .regularExpression) != nil else { return nil }
        let digits = text.drop(while: { $0 == "0" })
        guard !digits.isEmpty, digits.count < 19 || (digits.count == 19 && digits <= "9223372036854775807") else { return nil }
        return text
    }
}

// MARK: - Service

public struct PayoutReceiverService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration; self.transport = transport
    }

    /// `POST /api/club/settlement/mine` with `{}`. Each row needs a positive clubId and a name, or the read fails.
    public func settlementClubs(token: String) async throws -> [PayoutSettlementClub] {
        let data = try await send(.settlementMine, body: [:], token: token)
        guard let rows = data as? [[String: Any]] else { throw PayoutReceiverIssue.malformed }
        return try rows.map { row in
            guard let id = ClubSettlementSummaryView.positive(row["clubId"]), let name = ClubSettlementSummaryView.text(row["name"]) else {
                throw PayoutReceiverIssue.malformed
            }
            return PayoutSettlementClub(id: id, name: name)
        }
    }

    /// `POST /api/club/settlement/summary` with `{clubId, personal}`.
    public func settlementSummary(clubID: Int, personal: Bool, token: String) async throws -> ClubSettlementSummaryView {
        guard clubID > 0 else { throw PayoutReceiverIssue.rejected(code: "CLUB_REQUIRED", message: nil) }
        let data = try await send(.settlementSummary, body: ["clubId": clubID, "personal": personal], token: token)
        guard let summary = ClubSettlementSummaryView(data: data) else { throw PayoutReceiverIssue.malformed }
        return summary
    }

    /// `GET /api/club/personal-receiver/status?clubId=`.
    public func receiverStatus(clubID: Int, token: String) async throws -> ClubPayoutReceiverStatus {
        guard clubID > 0 else { throw PayoutReceiverIssue.rejected(code: "CLUB_REQUIRED", message: nil) }
        let data = try await send(.receiverStatus, query: ["clubId": String(clubID)], token: token)
        guard let status = ClubPayoutReceiverStatus(data: data) else { throw PayoutReceiverIssue.malformed }
        return status
    }

    /// `POST /api/club/personal-receiver/bind` with `{clubId, jsCode, consent: true}`. The code is a one-time WeChat code.
    public func bind(clubID: Int, jsCode: String, token: String) async throws {
        let code = jsCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clubID > 0 else { throw PayoutReceiverIssue.rejected(code: "CLUB_REQUIRED", message: nil) }
        guard !code.isEmpty else { throw PayoutReceiverIssue.rejected(code: "WECHAT_FRESH_CODE_EXCHANGE_FAILED", message: nil) }
        _ = try await send(.receiverBind, body: ["clubId": clubID, "jsCode": code, "consent": true], token: token)
    }

    /// `POST /api/club/personal-receiver/unbind` with `{clubId}`.
    public func unbind(clubID: Int, token: String) async throws {
        guard clubID > 0 else { throw PayoutReceiverIssue.rejected(code: "CLUB_REQUIRED", message: nil) }
        _ = try await send(.receiverUnbind, body: ["clubId": clubID], token: token)
    }

    /// `POST /api/merchant/payout-account` with no body (the merchant id comes from the signed-in identity).
    public func merchantPayoutAccount(token: String) async throws -> MerchantPayoutAccount {
        let data = try await send(.merchantPayoutAccount, body: nil, token: token)
        guard let account = MerchantPayoutAccount(data: data) else { throw PayoutReceiverIssue.malformed }
        return account
    }

    /// `GET /api/club-direct-merchant/club?clubId=[&topicId=]` or `/merchant[?topicId=]`.
    public func directLedger(_ scope: ClubDirectLedger.Scope, token: String) async throws -> ClubDirectLedger {
        let route: PayoutReceiverRoute
        var query: [String: String] = [:]
        switch scope {
        case .club(let clubID, let topicID):
            route = .directLedgerClub; query["clubId"] = String(clubID); if let topicID { query["topicId"] = String(topicID) }
        case .merchant(let topicID):
            route = .directLedgerMerchant; if let topicID { query["topicId"] = String(topicID) }
        }
        let data = try await send(route, query: query, token: token)
        guard let ledger = ClubDirectLedger(data: data, scope: scope) else { throw PayoutReceiverIssue.malformed }
        return ledger
    }

    // MARK: wire

    func request(_ route: PayoutReceiverRoute, query: [String: String] = [:], body: [String: Any]?, token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw PayoutReceiverIssue.unauthorized }
        var url = configuration.baseURL.appendingPathComponent(route.rawValue)
        if !query.isEmpty, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            parts.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) }
            url = parts.url ?? url
        }
        var request = URLRequest(url: url)
        request.httpMethod = route.method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        if route.method == "POST", let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        }
        return request
    }

    private func send(_ route: PayoutReceiverRoute, query: [String: String] = [:], body: [String: Any]? = nil, token: String) async throws -> Any? {
        let request = try request(route, query: query, body: body, token: token)
        let data: Data, status: Int
        do { (data, status) = try await transport.send(request) }
        catch let error as APIError where error == .notConfigured { throw PayoutReceiverIssue.closed }
        catch is CancellationError { throw CancellationError() }
        catch { throw PayoutReceiverIssue.network }
        return try Self.payload(data, status: status)
    }

    static func payload(_ data: Data, status: Int) throws -> Any? {
        guard status != 401, status != 403 else { throw PayoutReceiverIssue.unauthorized }
        guard (200..<300).contains(status) else { throw PayoutReceiverIssue.network }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw PayoutReceiverIssue.malformed }
        let code = (object["code"] as? Int) ?? (object["code"] as? String).flatMap(Int.init)
        if code == 401 { throw PayoutReceiverIssue.unauthorized }
        guard code == 200 else {
            let message = object["msg"] as? String
            let machine = message.flatMap { $0.range(of: "^[A-Z0-9_]+$", options: .regularExpression) != nil ? $0 : nil }
            throw PayoutReceiverIssue.rejected(code: machine, message: machine == nil ? message : nil)
        }
        return object["data"]
    }
}

// MARK: - WP-05 payment readiness

/// `POST /api/registration/payment-readiness` (mini-program `baoming.checkPaymentReadiness`). A read: no money moves.
public struct RegistrationPaymentReadiness: Equatable, Sendable {
    public let ready: Bool
    /// Server sentence (「支付服务可用」/「支付服务暂不可用」), shown as is.
    public let message: String?
    public static let path = "api/registration/payment-readiness"

    public static func request(configuration: APIConfiguration, token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.unauthorized }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = Data("{}".utf8)
        return request
    }

    /// Anything but `code 200` with `data.ready == true` is not ready (mini-program `settle(false, …)`).
    public static func decode(_ data: Data, status: Int) -> RegistrationPaymentReadiness {
        guard (200..<300).contains(status), let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .init(ready: false, message: nil)
        }
        let code = (object["code"] as? Int) ?? (object["code"] as? String).flatMap(Int.init)
        guard code == 200, let payload = object["data"] as? [String: Any] else {
            return .init(ready: false, message: (object["msg"] as? String).flatMap { $0.isEmpty ? nil : $0 })
        }
        return .init(ready: payload["ready"] as? Bool == true, message: (payload["message"] as? String).flatMap { $0.isEmpty ? nil : $0 })
    }

    public static func read(configuration: APIConfiguration, transport: any HTTPTransport, token: String) async throws -> RegistrationPaymentReadiness {
        let request = try request(configuration: configuration, token: token)
        let (data, status) = try await transport.send(request)
        if status == 401 || status == 403 { throw APIError.unauthorized }
        return decode(data, status: status)
    }
}
