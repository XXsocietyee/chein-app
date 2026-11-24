import Foundation

public enum InvoiceLaunchIssue: Error, Equatable {
    case invalid, malformed, disabled, staleSession, unauthorized, unavailable
    case rejected(String), outcomeUnknown, pendingConflict, storageUnavailable
    case originalReadUnavailable
    /// Original-request read answered `INVOICE_NOT_FOUND`. Not a rollback and not a transport failure.
    case notFound
}

/// Legacy routes plus separately approved original-receipt routes verified at c6eac3.
/// Amount, tax and eligibility stay server-owned. New delete/cancel receipts are not enabled.
public enum InvoiceLaunchRoute: String, CaseIterable {
    case titles, saveTitle = "titles/save", deleteTitle = "titles/delete"
    case eligibleOrders = "orders/eligible", apply, list, detail, cancel
    case originalRequest = "request", saveTitleRequest = "titles/save-request", titleRequest = "titles/request"
    public var needsOriginalReceipts: Bool { [.originalRequest, .saveTitleRequest, .titleRequest].contains(self) }
    public var path: String { "api/invoice/" + rawValue }
    public var isMutation: Bool { [.saveTitle, .saveTitleRequest, .deleteTitle, .apply, .cancel].contains(self) }
}

/// Memory-only session snapshot. Namespace must be the existing reviewed regional
/// storage namespace. A new epoch is required for every logout/login transition.
public struct InvoiceLaunchSession: Equatable {
    public let baseURL: URL
    public let namespace: String
    public let accountID: Int64
    public let role: String
    public let epoch: UInt64
    let token: String
    public init(baseURL: URL, namespace: String, accountID: Int64, role: String,
                epoch: UInt64, token: String) throws {
        _ = try APIConfiguration(baseURL: baseURL)
        guard accountID > 0, !namespace.isEmpty, !role.isEmpty,
              AuthRequestBuilder.isValidToken(token) else { throw InvoiceLaunchIssue.invalid }
        self.baseURL = baseURL; self.namespace = namespace; self.accountID = accountID
        self.role = role; self.epoch = epoch; self.token = token
    }
    // Stable across process restart/token rotation. Contains no credential or PII.
    var ownerKey: String {
        [baseURL.absoluteString, namespace, String(accountID)]
            .map { "\($0.utf8.count):\($0)" }.joined(separator: ":")
    }
}

public struct InvoiceLaunchTitleDraft: Encodable, Equatable {
    public let id: Int64?
    public let titleType: String
    public let titleName: String
    public let taxNo: String?
    public let isDefault: Bool
    public init(id: Int64? = nil, titleType: String, titleName: String,
                taxNo: String? = nil, isDefault: Bool = false) throws {
        guard id.map({ $0 > 0 }) != false else { throw InvoiceLaunchIssue.invalid }
        self.id = id; self.titleType = titleType; self.titleName = titleName
        self.taxNo = taxNo; self.isDefault = isDefault
        // Validation/normalization of title and tax number belongs to the server.
        // Never hydrate taxNo from the masked title projection.
    }
}
public struct InvoiceLaunchTitle: Decodable, Equatable {
    public let id: Int64
    public let titleType: String
    public let titleName: String
    public let taxNoMasked: String?
    public let isDefault: Bool
    private enum CodingKeys: String, CodingKey { case id, titleType, titleName, taxNoMasked, isDefault }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try InvoiceLaunchWire.id(c, .id)
        titleType = try c.decode(String.self, forKey: .titleType)
        titleName = try c.decode(String.self, forKey: .titleName)
        taxNoMasked = try c.decodeIfPresent(String.self, forKey: .taxNoMasked)
        isDefault = try c.decode(Bool.self, forKey: .isDefault)
    }
    func validate() throws {
        guard id > 0, ["PERSONAL", "COMPANY"].contains(titleType), !titleName.isEmpty,
              InvoiceLaunchWire.masked(taxNoMasked) else { throw InvoiceLaunchIssue.malformed }
    }
}
public struct InvoiceLaunchOrder: Decodable, Equatable {
    public let orderId: Int64
    public let issuerId: Int64?
    public let issuerName: String?
    public let orderSource: String?
    public let amount: Decimal
    public let orderTitle: String?
    public let ticketName: String?
    public let paymentTime: InvoiceLaunchTime?
    private enum CodingKeys: String, CodingKey { case orderId, issuerId, issuerName, orderSource, amount, orderTitle, ticketName, paymentTime }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        orderId = try InvoiceLaunchWire.id(c, .orderId)
        issuerId = try c.decodeIfPresent(InvoiceLaunchWire.ExactID.self, forKey: .issuerId)?.value
        issuerName = try c.decodeIfPresent(String.self, forKey: .issuerName)
        orderSource = try c.decodeIfPresent(String.self, forKey: .orderSource)
        amount = try c.decode(Decimal.self, forKey: .amount)
        orderTitle = try c.decodeIfPresent(String.self, forKey: .orderTitle)
        ticketName = try c.decodeIfPresent(String.self, forKey: .ticketName)
        paymentTime = try c.decodeIfPresent(InvoiceLaunchTime.self, forKey: .paymentTime)
    }
    func validate() throws {
        guard orderId > 0, orderSource == nil || orderSource == "registration",
              issuerId.map({ $0 > 0 }) != false, !amount.isNaN else { throw InvoiceLaunchIssue.malformed }
    }
}
public enum InvoiceLaunchStatus: String, Decodable {
    case submitted = "SUBMITTED", issued = "ISSUED", rejected = "REJECTED", cancelled = "CANCELLED"
    /// Back-office processing states the server also returns (UserInvoiceProcessingService). Without
    /// them one such row would fail decoding of the whole list/detail.
    case claimed = "CLAIMED", processing = "PROCESSING", issueUnknown = "ISSUE_UNKNOWN", paused = "PAUSED"

    /// Source subpackageMember/invoice/base.js PLAYER_STATUS: the player sees one "issuing" state for
    /// SUBMITTED/CLAIMED/PROCESSING/ISSUE_UNKNOWN, plus paused, issued, rejected and cancelled.
    public enum PlayerState: String, Equatable { case issuing, paused, issued, rejected, cancelled }
    public var playerState: PlayerState {
        switch self {
        case .submitted, .claimed, .processing, .issueUnknown: return .issuing
        case .paused: return .paused
        case .issued: return .issued
        case .rejected: return .rejected
        case .cancelled: return .cancelled
        }
    }
    /// Filter-chip key. Source invoice/index.js IN_TAB: the 处理中 tab shows issuing AND paused rows.
    public var filterKey: String {
        switch playerState {
        case .issuing, .paused: return "SUBMITTED"
        case .issued: return "ISSUED"
        case .rejected: return "REJECTED"
        case .cancelled: return "CANCELLED"
        }
    }
    /// Key in the InvoiceLaunchUI string table for the status label in lists.
    public var labelKey: String { playerState == .paused ? "PAUSED" : filterKey }
    /// Key for the detail status notice.
    public var noticeKey: String { "notice." + playerState.rawValue }
}
/// Preserve the Jackson Date representation for display; never infer a deadline.
public enum InvoiceLaunchTime: Decodable, Equatable {
    case text(String), epochMilliseconds(Int64)
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let milliseconds = try? value.decode(Int64.self) { self = .epochMilliseconds(milliseconds) }
        else { self = .text(try value.decode(String.self)) }
    }
}
public struct InvoiceLaunchApplication: Decodable, Equatable {
    /// Persisted application title identity; absent on older servers, never inferred from its name.
    public let titleId: Int64?
    public let id: Int64
    public let requestId: String?
    public let applicationNo: String
    public let status: InvoiceLaunchStatus
    public let titleType: String
    public let titleName: String
    public let taxNoMasked: String?
    public let totalAmount: Decimal
    public let orderCount: Int
    public let provider: String?
    public let invoiceNo: String?
    public let rejectReason: String?
    public let issuedAt: InvoiceLaunchTime?
    public let createTime: InvoiceLaunchTime?
    public let orders: [InvoiceLaunchOrder]
    public let replayed: Bool?
    /// The frozen projection contains no file locator. ISSUED and invoiceNo are
    /// application facts, never proof that a downloadable invoice exists.
    public var documentStatus: InvoiceFileStatus { .unknown }
    private enum CodingKeys: String, CodingKey { case id, titleId, requestId, applicationNo, status, titleType, titleName, taxNoMasked, totalAmount, orderCount, provider, invoiceNo, rejectReason, issuedAt, createTime, orders, replayed }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try InvoiceLaunchWire.id(c, .id)
        titleId = try c.decodeIfPresent(InvoiceLaunchWire.ExactID.self, forKey: .titleId)?.value
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId)
        applicationNo = try c.decode(String.self, forKey: .applicationNo)
        status = try c.decode(InvoiceLaunchStatus.self, forKey: .status)
        titleType = try c.decode(String.self, forKey: .titleType)
        titleName = try c.decode(String.self, forKey: .titleName)
        taxNoMasked = try c.decodeIfPresent(String.self, forKey: .taxNoMasked)
        totalAmount = try c.decode(Decimal.self, forKey: .totalAmount)
        orderCount = try c.decode(Int.self, forKey: .orderCount)
        provider = try c.decodeIfPresent(String.self, forKey: .provider)
        invoiceNo = try c.decodeIfPresent(String.self, forKey: .invoiceNo)
        rejectReason = try c.decodeIfPresent(String.self, forKey: .rejectReason)
        issuedAt = try c.decodeIfPresent(InvoiceLaunchTime.self, forKey: .issuedAt)
        createTime = try c.decodeIfPresent(InvoiceLaunchTime.self, forKey: .createTime)
        orders = try c.decode([InvoiceLaunchOrder].self, forKey: .orders)
        replayed = try c.decodeIfPresent(Bool.self, forKey: .replayed)
    }
    func validate(summary: Bool = false) throws {
        guard id > 0, requestId.map(InvoiceLaunchWire.requestID) != false, !applicationNo.isEmpty, ["PERSONAL", "COMPANY"].contains(titleType),
              !titleName.isEmpty, InvoiceLaunchWire.masked(taxNoMasked), !totalAmount.isNaN,
              orderCount > 0, (summary && orders.isEmpty || orders.count == orderCount),
              Set(orders.map(\.orderId)).count == orders.count else { throw InvoiceLaunchIssue.malformed }
        try orders.forEach { try $0.validate() }
    }
    func matches(_ command: InvoiceLaunchApply) -> Bool {
        (titleId == nil || titleId == command.titleId) && Set(orders.map(\.orderId)) == Set(command.orderIds) && orders.count == command.orderIds.count
    }
}

/// Atomic return value for the normal invoice entry. A pending operation is
/// supplied alongside the lists so the host cannot mistake browsing for recovery.
public struct InvoiceLaunchOverview: Equatable {
    public let titles: [InvoiceLaunchTitle]
    public let eligibleOrders: [InvoiceLaunchOrder]
    public let applications: [InvoiceLaunchApplication]
    public let pending: InvoiceLaunchPending?
}

/// The original request identity and exact body survive restart. No calculated total,
/// memberId, tax rate or inferred eligibility can be put on this request.
public struct InvoiceLaunchApply: Codable, Equatable {
    public let requestId: String
    public let titleId: Int64
    public let orderIds: [Int64]
    public init(requestId: String = UUID().uuidString, titleId: Int64, orderIds: [Int64]) throws {
        self.requestId = requestId; self.titleId = titleId; self.orderIds = orderIds
        try validate()
    }
    func validate() throws {
        guard InvoiceLaunchWire.requestID(requestId), titleId > 0, !orderIds.isEmpty,
              orderIds.allSatisfy({ $0 > 0 }), Set(orderIds).count == orderIds.count else { throw InvoiceLaunchIssue.invalid }
    }
}

public struct InvoiceLaunchTitleReceipt: Decodable, Equatable {
    public let requestId: String
    public let titleId: Int64
    public let status: String
    private enum CodingKeys: String, CodingKey { case requestId, titleId, status }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try c.decode(String.self, forKey: .requestId)
        titleId = try InvoiceLaunchWire.id(c, .titleId)
        status = try c.decode(String.self, forKey: .status)
    }
    func validate(request: String, target: Int64? = nil) throws {
        guard requestId == request, InvoiceLaunchWire.requestID(requestId), status == "SAVED",
              target == nil || target == titleId else { throw InvoiceLaunchIssue.malformed }
    }
}

enum InvoiceLaunchWire {
    struct ExactID: Decodable {
        let value: Int64
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let text = try? c.decode(String.self) {
                guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }),
                      let parsed = Int64(text), parsed > 0, String(parsed) == text else { throw InvoiceLaunchIssue.malformed }
                value = parsed
            } else {
                let parsed = try c.decode(Int64.self)
                guard parsed > 0 else { throw InvoiceLaunchIssue.malformed }
                value = parsed
            }
        }
    }
    static func id<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) throws -> Int64 {
        try c.decode(ExactID.self, forKey: key).value
    }

    static func requestID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 64 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }
    static func masked(_ value: String?) -> Bool {
        guard let value, !value.isEmpty else { return true }
        return value.range(of: "^(?:[0-9A-Z]{2}\\*{6}[0-9A-Z]{4}|\\*{6})$", options: .regularExpression) != nil
    }
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}

/// Separately accepted #725 routes. Never included in or substituted for the legacy route list.
public enum InvoiceLaunchCommandRoute: String {
    case deleteTitle = "titles/delete-request", cancel = "cancel-request", receipt = "commands/request"
    public var path: String { "api/invoice/" + rawValue }
    public var isMutation: Bool { self != .receipt }
}
public struct InvoiceLaunchCommandReceipt: Decodable, Equatable {
    public enum Operation: String, Decodable { case deleteTitle = "DELETE_TITLE", cancel = "CANCEL_APPLICATION" }
    public let requestId: String
    public let operation: Operation
    public let targetId: Int64
    public let outcome: String
    private enum CodingKeys: String, CodingKey { case requestId, operation, targetId, outcome }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try c.decode(String.self, forKey: .requestId)
        operation = try c.decode(Operation.self, forKey: .operation)
        let raw = try c.decode(String.self, forKey: .targetId)
        guard let id = Int64(raw), id > 0, String(id) == raw else { throw InvoiceLaunchIssue.malformed }
        targetId = id; outcome = try c.decode(String.self, forKey: .outcome)
    }
    func validate(request: String, operation expected: Operation, target: Int64) throws {
        guard InvoiceLaunchWire.requestID(requestId), requestId == request, operation == expected,
              targetId == target, outcome == (expected == .deleteTitle ? "DELETED" : "CANCELLED") else {
            throw InvoiceLaunchIssue.malformed
        }
    }
}

/// Read-only page model for `subpackageMember/invoice-apply/index`.
/// It uses the existing overview (`api/invoice/titles`, `api/invoice/orders/eligible`, `api/invoice/list`).
/// It does not register a route, mark one live, submit an application, or take payment.
/// Unknown amounts are an em dash. A literal 0 stays 0. A missing read stays hidden.
public struct InvoiceLaunchApplyCapability: Equatable {
    public let readsGranted: Bool
    public let applyGranted: Bool
    public init(readsGranted: Bool, applyGranted: Bool) {
        self.readsGranted = readsGranted
        self.applyGranted = readsGranted && applyGranted
    }
    /// The host's existing switches. This does not turn either switch on.
    public init(readsEnabled: Bool, mutationsEnabled: Bool) {
        self.init(readsGranted: readsEnabled, applyGranted: mutationsEnabled)
    }
    public static let absent = Self(readsGranted: false, applyGranted: false)
}

/// A server amount. Unknown is never stored as 0.
public enum InvoiceLaunchApplyAmount: Equatable {
    case known(Decimal)
    case unknown
    public static let unknownDisplay = "—"
    /// The server literal, including 0. Unknown is nil.
    public var literal: Decimal? {
        if case .known(let value) = self { return value }
        return nil
    }
    /// Unknown, null, a numeric string, and a non-number are an em dash, never 0.
    public var displayText: String {
        switch self {
        case .unknown: return Self.unknownDisplay
        case .known(let value): return Self.plain(value)
        }
    }
    public static func from(_ value: Decimal) -> Self {
        value.isNaN ? .unknown : .known(value)
    }
    /// JSON number, including 0. Absent, text (including "0"), and a non-number stay unknown.
    public static func parse(_ input: Input) -> Self {
        switch input {
        case .absent, .text, .notANumber: return .unknown
        case .number(let value): return from(value)
        }
    }
    public enum Input: Equatable {
        case absent
        case text(String)
        case number(Decimal)
        case notANumber
    }
    private static func plain(_ value: Decimal) -> String {
        if value.isNaN { return unknownDisplay }
        if value == 0 { return "0" }
        let text = NSDecimalNumber(decimal: value).description
        if text.isEmpty || text == "NaN" { return unknownDisplay }
        return text
    }
}

public struct InvoiceLaunchApplyTitleLine: Equatable {
    public let id: Int64
    public let name: String
    public let isDefault: Bool
    public init(id: Int64, name: String, isDefault: Bool) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isDefault = isDefault
    }
}

public struct InvoiceLaunchApplyOrderLine: Equatable {
    public let orderID: Int64
    public let titleText: String
    public let amount: InvoiceLaunchApplyAmount
    public var amountText: String { amount.displayText }
    public init(orderID: Int64, title: String?, amount: InvoiceLaunchApplyAmount) {
        self.orderID = orderID
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.titleText = trimmed.isEmpty ? InvoiceLaunchApplyAmount.unknownDisplay : trimmed
        if case .known(let value) = amount, !value.isNaN {
            self.amount = .known(value)
        } else {
            self.amount = .unknown
        }
    }
}

public struct InvoiceLaunchApplyPage: Equatable {
    public enum Phase: Equatable {
        case loading
        case empty
        case error(String)
        case unknown
        case ready
    }
    public enum Key {
        public static let loading = "loading"
        public static let empty = "noOrders"
        public static let loadFailed = "loadFailed"
        public static let session = "session"
        public static let storage = "storage"
        public static let notSaved = "notSaved"
        public static let unknown = "unknown"
        public static let retry = "retry"
        public static let checkResult = "checkResult"
        /// Keys this model references. All of them already exist in InvoiceLaunchUI.
        public static let referenced = [loading, empty, loadFailed, session, storage, notSaved, unknown, retry, checkResult]
    }
    public static let unknownDisplay = InvoiceLaunchApplyAmount.unknownDisplay
    public static let titlesPath = InvoiceLaunchRoute.titles.path
    public static let eligibleOrdersPath = InvoiceLaunchRoute.eligibleOrders.path
    public static let listPath = InvoiceLaunchRoute.list.path
    public static let applyPath = InvoiceLaunchRoute.apply.path
    public static let routeMarkedLive = false
    public static let includedInPlayerFirstEntry = false
    public static let paymentEnabled = false
    public let readsGranted: Bool
    public let applyGranted: Bool
    public let phase: Phase?
    public let lines: [InvoiceLaunchApplyOrderLine]
    public let titles: [InvoiceLaunchApplyTitleLine]
    /// The body stays hidden while loading and when the read was not granted.
    public var hidden: Bool {
        switch phase {
        case .loading, nil: return true
        case .empty, .error, .unknown, .ready: return false
        }
    }
    public var stateKey: String? {
        switch phase {
        case .loading: return Key.loading
        case .empty: return Key.empty
        case .error(let key): return key
        case .unknown: return Key.unknown
        case .ready, nil: return nil
        }
    }
    public var retryKey: String? {
        if case .error = phase { return Key.retry }
        return nil
    }
    public var recoveryKey: String? {
        if case .unknown = phase { return Key.checkResult }
        return nil
    }
    /// Submit stays hidden unless the existing mutation switch is on and the read is ready.
    public var showsApplyAction: Bool {
        guard Self.paymentEnabled == false, readsGranted, applyGranted, !lines.isEmpty else { return false }
        guard case .ready = phase else { return false }
        return lines.allSatisfy { $0.amount.literal != nil }
    }

    public static func hidden() -> Self {
        Self(readsGranted: false, applyGranted: false, phase: nil, lines: [], titles: [])
    }
    public static func loading(capability: InvoiceLaunchApplyCapability) -> Self {
        Self(readsGranted: capability.readsGranted, applyGranted: false, phase: .loading, lines: [], titles: [])
    }

    public static func project(titles: [InvoiceLaunchTitle], orders: [InvoiceLaunchOrder], unresolved: Bool,
                               capability: InvoiceLaunchApplyCapability) -> Self {
        let titleLines = titles.map { InvoiceLaunchApplyTitleLine(id: $0.id, name: $0.titleName, isDefault: $0.isDefault) }
        let orderLines = orders.map { order in
            InvoiceLaunchApplyOrderLine(orderID: order.orderId, title: order.orderTitle, amount: .from(order.amount))
        }
        return project(lines: orderLines, titles: titleLines, unresolved: unresolved, capability: capability)
    }

    public static func project(lines: [InvoiceLaunchApplyOrderLine], titles: [InvoiceLaunchApplyTitleLine],
                               unresolved: Bool, capability: InvoiceLaunchApplyCapability) -> Self {
        guard capability.readsGranted else { return hidden() }
        if lines.contains(where: { $0.orderID <= 0 }) || titles.contains(where: { $0.id <= 0 || $0.name.isEmpty }) {
            return Self(readsGranted: true, applyGranted: capability.applyGranted, phase: .error(Key.loadFailed), lines: [], titles: [])
        }
        if unresolved || lines.contains(where: { $0.amount.literal == nil }) {
            return Self(readsGranted: true, applyGranted: capability.applyGranted, phase: .unknown, lines: lines, titles: titles)
        }
        if lines.isEmpty {
            return Self(readsGranted: true, applyGranted: capability.applyGranted, phase: .empty, lines: [], titles: titles)
        }
        return Self(readsGranted: true, applyGranted: capability.applyGranted, phase: .ready, lines: lines, titles: titles)
    }

    /// Reads the existing overview. A missing read does not call the coordinator.
    /// This never calls `apply` and never starts a payment.
    @MainActor public static func load(coordinator: InvoiceLaunchCoordinator, capability: InvoiceLaunchApplyCapability) async -> Self {
        guard capability.readsGranted else { return hidden() }
        do {
            let overview = try await coordinator.overview()
            return project(titles: overview.titles, orders: overview.eligibleOrders,
                           unresolved: overview.pending != nil, capability: capability)
        } catch is CancellationError {
            return loading(capability: capability)
        } catch let issue as InvoiceLaunchIssue {
            return from(issue, capability: capability)
        } catch {
            return Self(readsGranted: true, applyGranted: capability.applyGranted, phase: .error(Key.loadFailed), lines: [], titles: [])
        }
    }

    private static func from(_ issue: InvoiceLaunchIssue, capability: InvoiceLaunchApplyCapability) -> Self {
        switch issue {
        case .disabled:
            return hidden()
        case .outcomeUnknown, .originalReadUnavailable, .pendingConflict, .notFound:
            return Self(readsGranted: true, applyGranted: capability.applyGranted, phase: .unknown, lines: [], titles: [])
        case .staleSession, .unauthorized:
            return Self(readsGranted: true, applyGranted: capability.applyGranted, phase: .error(Key.session), lines: [], titles: [])
        case .storageUnavailable:
            return Self(readsGranted: true, applyGranted: capability.applyGranted, phase: .error(Key.storage), lines: [], titles: [])
        case .invalid, .rejected:
            return Self(readsGranted: true, applyGranted: capability.applyGranted, phase: .error(Key.notSaved), lines: [], titles: [])
        case .malformed, .unavailable:
            return Self(readsGranted: true, applyGranted: capability.applyGranted, phase: .error(Key.loadFailed), lines: [], titles: [])
        }
    }

    private init(readsGranted: Bool, applyGranted: Bool, phase: Phase?, lines: [InvoiceLaunchApplyOrderLine], titles: [InvoiceLaunchApplyTitleLine]) {
        guard readsGranted else {
            self.readsGranted = false
            self.applyGranted = false
            self.phase = nil
            self.lines = []
            self.titles = []
            return
        }
        self.readsGranted = true
        self.applyGranted = applyGranted
        switch phase {
        case .loading:
            self.phase = .loading
            self.lines = []
            self.titles = []
        case nil:
            self.phase = .unknown
            self.lines = []
            self.titles = []
        case .empty, .unknown, .ready:
            self.phase = phase
            self.lines = lines
            self.titles = titles
        case .error:
            self.phase = phase
            self.lines = []
            self.titles = []
        }
    }
}
