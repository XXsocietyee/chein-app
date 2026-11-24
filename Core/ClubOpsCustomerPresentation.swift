import Foundation

/// Mini-program pages/club/customers view-model parity. Phone numbers are only the server-rendered phoneText.
public enum ClubOpsCustomerText {
    public static func trimmed(_ value: ClubGovernanceValue) -> String? {
        guard let text = value.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
    /// Leading yyyy-MM-dd of the server string; no time zone conversion, matching the mini-program.
    public static func dateParts(_ value: ClubGovernanceValue) -> (year: Int, month: Int, day: Int)? {
        guard let raw = value.string else { return nil }
        let chars = Array(raw.replacingOccurrences(of: "T", with: " "))
        guard chars.count >= 10, chars[4] == "-", chars[7] == "-" else { return nil }
        func digits(_ range: Range<Int>) -> Int? {
            let slice = chars[range]
            guard slice.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            return Int(String(slice))
        }
        guard let year = digits(0..<4), let month = digits(5..<7), let day = digits(8..<10) else { return nil }
        return (year, month, day)
    }
    public static func monthDay(_ value: ClubGovernanceValue) -> String? {
        guard let parts = dateParts(value) else { return nil }
        return String(format: "%02d-%02d", parts.month, parts.day)
    }
    public static func count(_ value: ClubGovernanceValue) -> Int? {
        guard case .integer(let number) = value, number >= 0 else { return nil }
        return number
    }
}

public enum ClubOpsCustomerMeta: Equatable {
    case pending(count: Int, topic: String?)
    case verified(count: Int, monthDay: String?)
}

public struct ClubOpsCustomerRow: Identifiable, Equatable {
    public let id: Int
    public let displayName: String?
    public let hasRemark: Bool
    public let meta: ClubOpsCustomerMeta
    /// Remark first; otherwise the server-rendered phone line.
    public let subText: String?
    /// CLB-customers-02 (parity r2): the customer's avatar (MP cy-avatar src); nil falls back to the initial.
    public var avatar: String? = nil
}

public struct ClubOpsCustomerListPresentation: Equatable {
    public let total: Int
    public let monthNew: Int
    public let rows: [ClubOpsCustomerRow]
    public init(value: ClubGovernanceValue) throws {
        guard let total = ClubOpsCustomerText.count(value["total"]), let monthNew = ClubOpsCustomerText.count(value["monthNew"]),
              let items = value["items"].array else { throw ClubGovernanceFailure.malformed }
        var rows: [ClubOpsCustomerRow] = [], seen = Set<Int>()
        for item in items {
            guard item.object != nil, let id = ClubCustomerHistoryTopicRoute.positiveID(item["memberId"]), seen.insert(id).inserted,
                  let verified = ClubOpsCustomerText.count(item["verifiedCount"]), let pending = ClubOpsCustomerText.count(item["pendingCount"]) else { throw ClubGovernanceFailure.malformed }
            let remark = ClubOpsCustomerText.trimmed(item["remark"])
            rows.append(.init(id: id, displayName: ClubOpsCustomerText.trimmed(item["displayName"]), hasRemark: remark != nil,
                              meta: pending > 0 ? .pending(count: pending, topic: ClubOpsCustomerText.trimmed(item["lastTopicName"]))
                                               : .verified(count: verified, monthDay: ClubOpsCustomerText.monthDay(item["lastVisitDate"])),
                              subText: remark ?? ClubOpsCustomerText.trimmed(item["phoneText"]),
                              avatar: ClubOpsCustomerText.trimmed(item["avatar"])))
        }
        self.total = total; self.monthNew = monthNew; self.rows = rows
    }
    private init(total: Int, monthNew: Int, rows: [ClubOpsCustomerRow]) { self.total = total; self.monthNew = monthNew; self.rows = rows }
    /// MP customers/index.js PAGE_SIZE.
    public static let pageSize = 50
    /// First page: more exists only when the page was full and still short of the total (MP js:155).
    public var hasMoreAfterFirstPage: Bool { rows.count >= Self.pageSize && rows.count < total }
    /// MP appendPage (js:179-189): dedupe by memberId, keep the newest counts, stop on a page
    /// that adds nothing, a short page, or once the list reaches the total.
    public func appending(_ page: ClubOpsCustomerListPresentation) -> (list: ClubOpsCustomerListPresentation, hasMore: Bool) {
        let seen = Set(rows.map(\.id))
        let fresh = page.rows.filter { !seen.contains($0.id) }
        let merged = ClubOpsCustomerListPresentation(total: page.total, monthNew: page.monthNew, rows: rows + fresh)
        return (merged, !fresh.isEmpty && page.rows.count >= Self.pageSize && merged.rows.count < page.total)
    }
}

public enum ClubOpsCustomerRecordStatus: String, CaseIterable, Equatable {
    case verified = "VERIFIED", pending = "PENDING", contacted = "CONTACTED", refunded = "REFUNDED", cancelled = "CANCELLED", registered = "REGISTERED"
    public var localizationKey: String { "clubOps.customer.status." + rawValue }
}

public struct ClubOpsCustomerRecord: Identifiable, Equatable {
    public let id: String
    public let topicID: Int?
    public let title: String?
    public let day: Int?
    public let month: Int?
    public let status: ClubOpsCustomerRecordStatus
    /// The exact returned row; topic navigation re-validates it through ClubCustomerHistoryTopicRoute.
    public let source: ClubGovernanceValue
}

public struct ClubOpsCustomerDetailPresentation: Equatable {
    public let memberID: Int
    public let displayName: String?
    public let phoneText: String?
    /// 2026-11-02 owner decision: the server alone decides whether this viewer may call.
    public let phoneCallable: Bool
    public let lastInteraction: (month: Int, day: Int)?
    public let remark: String?
    /// nil means the server withheld the amount for this role; never rendered as zero.
    public let paidAmountText: String?
    public let arrivedCount: Int
    public let pendingCount: Int
    public let refundedCount: Int
    public let records: [ClubOpsCustomerRecord]
    public let tags: [String]
    public let canEdit: Bool
    /// CLB-customer-detail-02 (parity r2): `summary.avatar` (MP cy-avatar src); nil keeps the generated art.
    public private(set) var avatar: String? = nil
    public init(value: ClubGovernanceValue, memberID expected: Int?) throws {
        let summary = value["summary"]
        guard summary.object != nil, let expected, let memberID = ClubCustomerHistoryTopicRoute.positiveID(summary["memberId"]), memberID == expected,
              let arrived = ClubOpsCustomerText.count(summary["arrivedCount"]), let pending = ClubOpsCustomerText.count(summary["pendingCount"]),
              let refunded = ClubOpsCustomerText.count(summary["refundedCount"]),
              let rows = value["records"].array, let rawTags = value["tags"].array else { throw ClubGovernanceFailure.malformed }
        let paid = summary["paidAmount"]
        if paid == .null || paid == .string("") { paidAmountText = nil }
        else {
            guard let amount = paid.number, amount.isFinite, amount >= 0 else { throw ClubGovernanceFailure.malformed }
            paidAmountText = Self.money(amount)
        }
        records = try rows.map { row in
            guard row.object != nil, let key = ClubOpsCustomerText.trimmed(row["key"]),
                  let status = ClubOpsCustomerRecordStatus(rawValue: row["statusCode"].string ?? "") else { throw ClubGovernanceFailure.malformed }
            let parts = ClubOpsCustomerText.dateParts(row["occurredAt"])
            return .init(id: key, topicID: ClubCustomerHistoryTopicRoute.positiveID(row["topicId"]), title: ClubOpsCustomerText.trimmed(row["title"]),
                         day: parts?.day, month: parts?.month, status: status, source: row)
        }
        // Record keys are list identities; a repeated key is a malformed receipt, not two rows.
        guard Set(records.map(\.id)).count == records.count else { throw ClubGovernanceFailure.malformed }
        tags = try rawTags.map { tag in
            guard let name = ClubOpsCustomerText.trimmed(tag) ?? ClubOpsCustomerText.trimmed(tag["name"]) else { throw ClubGovernanceFailure.malformed }
            return name
        }
        self.memberID = memberID
        displayName = ClubOpsCustomerText.trimmed(summary["displayName"])
        phoneText = ClubOpsCustomerText.trimmed(summary["phoneText"])
        phoneCallable = summary["phoneCallable"] == .bool(true)
        lastInteraction = ClubOpsCustomerText.dateParts(summary["lastInteractionTime"]).map { (month: $0.month, day: $0.day) }
        remark = ClubOpsCustomerText.trimmed(value["remark"])
        arrivedCount = arrived; pendingCount = pending; refundedCount = refunded
        canEdit = value["canEdit"] == .bool(true)
        avatar = ClubOpsCustomerText.trimmed(summary["avatar"])
    }
    /// Mini-program trimMoney: whole yuan without decimals, otherwise two decimals.
    public static func money(_ amount: Double) -> String {
        if amount.rounded() == amount, amount < 1e15 { return "¥" + String(Int(amount)) }
        return "¥" + String(format: "%.2f", amount)
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.memberID == rhs.memberID && lhs.displayName == rhs.displayName && lhs.phoneText == rhs.phoneText && lhs.phoneCallable == rhs.phoneCallable &&
        lhs.lastInteraction?.month == rhs.lastInteraction?.month && lhs.lastInteraction?.day == rhs.lastInteraction?.day &&
        lhs.remark == rhs.remark && lhs.paidAmountText == rhs.paidAmountText && lhs.arrivedCount == rhs.arrivedCount &&
        lhs.pendingCount == rhs.pendingCount && lhs.refundedCount == rhs.refundedCount && lhs.records == rhs.records &&
        lhs.tags == rhs.tags && lhs.canEdit == rhs.canEdit
    }
}

/// Inline tag/remark editor over the existing comma-joined draft field (same command fields, same request ID rules).
public struct ClubOpsCustomerTagRemarkDraft: Equatable {
    public enum Issue: String, Equatable {
        case remarkTooLong, tagTooLong, tooManyTags
        public var localizationKey: String { "clubOps.customer.issue." + rawValue }
    }
    public static let maxTags = 8, maxTagLength = 12, maxRemarkLength = 200
    public private(set) var tags: [String]
    public init(tagsText: String) { tags = Self.split(tagsText) }
    public var tagsText: String { tags.joined(separator: ",") }
    static func split(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    /// Adds a typed tag (commas split it, matching the draft's wire parsing). Rejects without mutating.
    public mutating func add(_ input: String) -> Issue? {
        let added = Self.split(input)
        guard !added.isEmpty else { return nil }
        var next = tags
        for name in added where !next.contains(name) { next.append(name) }
        if let issue = Self.issue(tags: next, remark: "") { return issue }
        tags = next; return nil
    }
    public mutating func remove(at index: Int) {
        guard tags.indices.contains(index) else { return }
        tags.remove(at: index)
    }
    public static func issue(tags: [String], remark: String) -> Issue? {
        if remark.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count > maxRemarkLength { return .remarkTooLong }
        var seen = Set<String>()
        for name in tags.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !name.isEmpty {
            if name.utf16.count > maxTagLength { return .tagTooLong }
            seen.insert(name)
        }
        return seen.count > maxTags ? .tooManyTags : nil
    }
    public static func issue(tagsText: String, remark: String) -> Issue? { issue(tags: split(tagsText), remark: remark) }
}

/// Page-specific failure copy for customers, customer detail and settlement; other reads keep generic copy.
public struct ClubOpsFailureCopy: Equatable {
    public let titleKey: String
    public let detailKey: String?
    public let retryKey: String?
    /// Server sentence for a specific customer-detail refusal, or the settlement split title.
    public let literalTitle: String?
    /// 「返回」 when the refusal is terminal. Nil keeps the existing retry.
    public let backTitle: String?
    public init?(operation: ClubGovernanceRead, failure: ClubGovernanceFailure) {
        let forbidden = failure == .forbidden
        switch operation {
        case .customers, .customer:
            if forbidden {
                titleKey = "clubOps.customers.forbidden"; detailKey = "clubOps.customers.forbiddenDetail"; retryKey = nil
                literalTitle = nil; backTitle = nil
            } else if failure == .signedOut { return nil }
            else if operation == .customer, case .rejected(let code, let message) = failure,
                    let sentence = ClubCustomerDetailRefusal.sentence(code: code, message: message) {
                titleKey = "clubOps.customer.failed"; detailKey = nil; retryKey = "clubOps.customers.retry"
                literalTitle = sentence; backTitle = "返回"
            } else {
                titleKey = operation == .customers ? "clubOps.customers.failed" : "clubOps.customer.failed"
                detailKey = nil; retryKey = "clubOps.customers.retry"
                literalTitle = nil; backTitle = nil
            }
        case .settlement:
            guard !forbidden, failure != .signedOut else { return nil }
            titleKey = "clubOps.settlement.failed"; detailKey = nil; retryKey = "clubOps.settlement.retry"
            literalTitle = ClubOpsNetworkFailureClassifier.settlementTitle(failure)
            backTitle = nil
        default: return nil
        }
    }
}

/// MP `refusalOf`: a non-generic business refusal becomes the not-found sentence. 401/403 and the busy line do not.
public enum ClubCustomerDetailRefusal {
    public static let generic = "系统繁忙，请稍后重试"
    public static func sentence(code: Int?, message: String?) -> String? {
        guard let code, code != 200, code != 401, code != 2, code != 403,
              let message = message?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty, message != generic else { return nil }
        return message
    }
}

/// Page model for pages/club/customer-detail/index.
/// Uses the existing `ClubGovernanceRead.customer` contract (`api/club/crm/customers/detail`).
/// A missing directory capability stays hidden. This type does not register a route and is not a player-first entry.
public struct ClubCustomerDetailCapability: Equatable {
    public let granted: Bool
    public init(granted: Bool) { self.granted = granted }
    public static let absent = Self(granted: false)
    public static let granted = Self(granted: true)
    /// Same local preflight as the customer read. Event-only grants do not count.
    public init(permissions: ClubGovernancePermissions?, scope: ClubGovernanceScope) {
        granted = permissions?.allows(ClubGovernanceRead.customer.permission, scope: scope) == true
    }
}

/// A count the server actually sent. Unknown is never stored as 0.
public enum ClubCustomerDetailCount: Equatable {
    case known(Int)
    case unknown
    public static let unknownDisplay = "—"
    /// The server literal, including 0. Unknown is nil.
    public var literal: Int? {
        if case .known(let number) = self { return number }
        return nil
    }
    /// Unknown, null, a numeric string, and a non-integer are an em dash, never 0.
    public var displayText: String {
        switch self {
        case .known(let number): return String(number)
        case .unknown: return Self.unknownDisplay
        }
    }
    public static func parse(_ value: ClubGovernanceValue) -> Self {
        if case .integer(let number) = value, number >= 0 { return .known(number) }
        return .unknown
    }
}

/// Null and "" stay withheld (the existing detail contract). UNKNOWN and a numeric string are an em dash.
public enum ClubCustomerDetailPaidAmount: Equatable {
    case withheld
    case unknown
    case amount(String)
    public var displayText: String? {
        switch self {
        case .withheld: return nil
        case .unknown: return ClubCustomerDetailCount.unknownDisplay
        case .amount(let text): return text
        }
    }
    public static func parse(_ value: ClubGovernanceValue) -> Self {
        switch value {
        case .null: return .withheld
        case .string(let raw): return raw.isEmpty ? .withheld : .unknown
        case .integer(let number):
            guard number >= 0 else { return .unknown }
            return .amount(ClubOpsCustomerDetailPresentation.money(Double(number)))
        case .decimal(let number):
            guard number.isFinite, number >= 0 else { return .unknown }
            return .amount(ClubOpsCustomerDetailPresentation.money(number))
        case .bool, .array, .object: return .unknown
        }
    }
    static func from(detail: ClubOpsCustomerDetailPresentation) -> Self {
        if let text = detail.paidAmountText { return .amount(text) }
        return .withheld
    }
}

public struct ClubCustomerDetailMetrics: Equatable {
    public let arrived: ClubCustomerDetailCount
    public let pending: ClubCustomerDetailCount
    public let refunded: ClubCustomerDetailCount
    public var containsUnknown: Bool { arrived.literal == nil || pending.literal == nil || refunded.literal == nil }
    public init(arrived: ClubCustomerDetailCount, pending: ClubCustomerDetailCount, refunded: ClubCustomerDetailCount) {
        self.arrived = arrived; self.pending = pending; self.refunded = refunded
    }
    init(detail: ClubOpsCustomerDetailPresentation) {
        self.init(arrived: .known(detail.arrivedCount), pending: .known(detail.pendingCount), refunded: .known(detail.refundedCount))
    }
}

public struct ClubCustomerDetailPage: Equatable {
    public enum Phase: Equatable {
        case loading
        case empty
        case error(ClubGovernanceFailure)
        case unknown
        case ready
    }
    public static let unknownDisplay = ClubCustomerDetailCount.unknownDisplay
    /// Existing backend read. Not a new route.
    public static let readOperation = ClubGovernanceRead.customer
    public static let includedInPlayerFirstEntry = false
    public static let routeMarkedLive = false
    public enum Copy {
        public static let loading = "club.customerDetail.page.loading"
        public static let empty = "club.customerDetail.page.empty"
        public static let error = "clubOps.customer.failed"
        public static let unknown = "club.customerDetail.page.unknown"
        public static let retry = "clubOps.customers.retry"
        public static let forbidden = "clubOps.customers.forbidden"
        public static let forbiddenDetail = "clubOps.customers.forbiddenDetail"
        public static let recordsEmpty = "clubOps.customer.recordsEmpty"
        public static let amountHidden = "clubOps.customer.amountHidden"
    }
    public enum Accessibility {
        public static let loading = "club.customerDetail.page.loading"
        public static let empty = "club.customerDetail.page.empty"
        public static let error = "club.customerDetail.page.error"
        public static let unknown = "club.customerDetail.page.unknown"
        public static let arrived = "club.customerDetail.metric.arrived"
        public static let pending = "club.customerDetail.metric.pending"
        public static let refunded = "club.customerDetail.metric.refunded"
        public static let paidAmount = "clubOps.customer.paidAmount"
    }
    public let clientCapabilityPresent: Bool
    public let serverFactPresent: Bool
    public let phase: Phase?
    public let metrics: ClubCustomerDetailMetrics?
    public let paidAmount: ClubCustomerDetailPaidAmount?
    public let recordCount: Int?
    public let hasTagsOrRemark: Bool
    public let displayName: String?
    /// Set only for a revealed empty or ready body. Hidden and unknown pages do not carry it.
    public let detail: ClubOpsCustomerDetailPresentation?
    public var hidden: Bool { !(clientCapabilityPresent && serverFactPresent) }

    public static func loading(clientCapabilityPresent: Bool) -> Self {
        Self(clientCapabilityPresent: clientCapabilityPresent, serverFactPresent: false, phase: .loading,
             metrics: nil, paidAmount: nil, recordCount: nil, hasTagsOrRemark: false, displayName: nil, detail: nil)
    }

    /// Projects one returned customer document. Does not invent counts.
    public static func project(value: ClubGovernanceValue, memberID: Int?, capability: ClubCustomerDetailCapability) -> Self {
        guard capability.granted else { return .loading(clientCapabilityPresent: false) }
        guard let memberID, memberID > 0 else {
            return revealed(phase: .error(.invalidRequest))
        }
        if let detail = try? ClubOpsCustomerDetailPresentation(value: value, memberID: memberID) {
            let bodyEmpty = detail.records.isEmpty && detail.tags.isEmpty && detail.remark == nil
            return revealed(phase: bodyEmpty ? .empty : .ready, metrics: .init(detail: detail),
                            paidAmount: .from(detail: detail), recordCount: detail.records.count,
                            hasTagsOrRemark: !detail.tags.isEmpty || detail.remark != nil,
                            displayName: detail.displayName, detail: detail)
        }
        let summary = value["summary"]
        guard summary.object != nil, ClubCustomerHistoryTopicRoute.positiveID(summary["memberId"]) == memberID else {
            return revealed(phase: .error(.malformed))
        }
        let metrics = ClubCustomerDetailMetrics(arrived: .parse(summary["arrivedCount"]), pending: .parse(summary["pendingCount"]), refunded: .parse(summary["refundedCount"]))
        let paid = ClubCustomerDetailPaidAmount.parse(summary["paidAmount"])
        if metrics.containsUnknown || paid == .unknown {
            return revealed(phase: .unknown, metrics: metrics, paidAmount: paid, displayName: ClubOpsCustomerText.trimmed(summary["displayName"]))
        }
        return revealed(phase: .error(.malformed))
    }

    public init(snapshot: ClubGovernanceSnapshot) {
        let capability = ClubCustomerDetailCapability(permissions: snapshot.permissions, scope: snapshot.scope)
        guard snapshot.operation == .customer, capability.granted else {
            self = .loading(clientCapabilityPresent: false)
            return
        }
        self = .project(value: snapshot.value, memberID: snapshot.scope.memberID, capability: capability)
    }

    /// Reads the existing customer detail. A missing capability does not call the reader.
    @MainActor public static func load(access: any ClubGovernanceAccess, scope: ClubGovernanceScope, capability: ClubCustomerDetailCapability) async -> Self {
        guard capability.granted else { return .loading(clientCapabilityPresent: false) }
        do {
            let snapshot = try await access.read(readOperation, scope: scope, options: [:])
            return Self(snapshot: snapshot)
        } catch let failure as ClubGovernanceFailure {
            if failure == .forbidden || failure == .signedOut { return .loading(clientCapabilityPresent: false) }
            return revealed(phase: .error(failure))
        } catch is CancellationError {
            return .loading(clientCapabilityPresent: true)
        } catch {
            return revealed(phase: .error(.unknown(message: nil)))
        }
    }

    private init(clientCapabilityPresent: Bool, serverFactPresent: Bool, phase: Phase?, metrics: ClubCustomerDetailMetrics?, paidAmount: ClubCustomerDetailPaidAmount?, recordCount: Int?, hasTagsOrRemark: Bool, displayName: String?, detail: ClubOpsCustomerDetailPresentation?) {
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
        switch self.phase {
        case .some(.empty), .some(.unknown), .some(.ready):
            self.metrics = metrics; self.paidAmount = paidAmount; self.recordCount = recordCount
            self.hasTagsOrRemark = hasTagsOrRemark; self.displayName = displayName; self.detail = detail
        case .some(.loading), .some(.error), .none:
            self.metrics = nil; self.paidAmount = nil; self.recordCount = nil
            self.hasTagsOrRemark = false; self.displayName = nil; self.detail = nil
        }
    }

    private static func revealed(phase: Phase, metrics: ClubCustomerDetailMetrics? = nil, paidAmount: ClubCustomerDetailPaidAmount? = nil, recordCount: Int? = nil, hasTagsOrRemark: Bool = false, displayName: String? = nil, detail: ClubOpsCustomerDetailPresentation? = nil) -> Self {
        Self(clientCapabilityPresent: true, serverFactPresent: true, phase: phase, metrics: metrics, paidAmount: paidAmount, recordCount: recordCount, hasTagsOrRemark: hasTagsOrRemark, displayName: displayName, detail: detail)
    }
}

#if DEBUG
/// Offline customer-detail documents. Compiled only in DEBUG. Not a live account.
public enum ClubCustomerDetailFixtureData {
    public static let scope = ClubGovernanceScope(clubID: 81, memberID: 704)
    public static var ready: ClubGovernanceValue { ClubGovernanceFixtures.value(.customer) }
    public static var emptyBody: ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"summary":{"memberId":704,"displayName":"Fixture customer","arrivedCount":0,"pendingCount":0,"refundedCount":0,"paidAmount":0},"records":[],"tags":[],"remark":null,"canEdit":false}"#)
    }
    public static var unknownCounts: ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"summary":{"memberId":704,"displayName":"Fixture customer","arrivedCount":"UNKNOWN","pendingCount":null,"refundedCount":"0","paidAmount":"UNKNOWN"},"records":[],"tags":[],"canEdit":false}"#)
    }
}
#endif

/// Page-ready read model for `pages/club/customers/index`.
/// Projects the existing `ClubGovernanceRead.customers` contract (`api/club/crm/customers/list`)
/// from the coordinator's read context. A viewer without `CUSTOMER_DIRECTORY` stays `.hidden`.
/// This type does not register a route and is not a player-home entry.
public struct ClubCustomersIndexModel: Equatable {
    public enum State: Equatable {
        case hidden
        case loading
        case empty
        case error(ClubOpsFailureCopy)
        case unknown
        case ready(ClubOpsCustomerListPresentation)
    }

    /// A count the server actually sent as a non-negative integer, or an unconfirmed count.
    /// Unknown, null, a numeric string, a decimal, and a bool stay `.unknown`.
    /// The display for `.unknown` is an em dash. A literal zero stays zero.
    public enum Count: Equatable {
        case known(Int)
        case unknown
        public static let unknownDisplay = "\u{2014}"
        public var text: String {
            switch self {
            case .known(let number): return String(number)
            case .unknown: return Self.unknownDisplay
            }
        }
    }

    public enum Accessibility {
        public static let hidden = "clubOps.customers.hidden"
        public static let loading = "club.gov.loading"
        public static let empty = "clubOps.customers.empty"
        public static let errorTitle = "clubOps.failure.title"
        public static let retry = "clubOps.failure.retry"
        public static let count = "clubOps.customers.count"
        public static let unknown = "clubOps.customers.unknown"
        public static let row = "club.gov.route.customer"
        public static let clearFilters = "club.gov.customers.clearFilters"
        public static let displayName = "club.gov.fact.displayName"
        public static let malformed = "clubOps.customers.malformed"
    }

    public static let contract = ClubGovernanceRead.customers
    public static let unknownLabelKey = "clubOps.customers.unknownLabel"
    public static let unknownValueKey = "clubOps.customers.unknown"
    /// Club operations stay off the player-first home.
    public static let playerHomeVisible = false

    public let state: State
    public let total: Count
    public let monthNew: Count
    public let filtered: Bool

    public var totalText: String { total.text }
    public var monthNewText: String { monthNew.text }
    public var emptyTitleKey: String {
        filtered ? "clubOps.customers.filteredEmpty" : "clubOps.customers.empty"
    }
    public var accessibilityIdentifier: String {
        switch state {
        case .hidden: return Accessibility.hidden
        case .loading: return Accessibility.loading
        case .empty: return Accessibility.empty
        case .error: return Accessibility.errorTitle
        case .unknown: return Accessibility.unknown
        case .ready: return Accessibility.count
        }
    }

    /// `filtered` is the coordinator's current chip or keyword, already on the customers read.
    public init(snapshot: ClubGovernanceSnapshot?, acceptedContext: ClubGovernanceReadContext?, expectedContext: ClubGovernanceReadContext, failure: ClubGovernanceFailure?, loading: Bool, filtered: Bool = false) {
        self.filtered = filtered
        let dash = Count.unknown
        guard expectedContext.operation == .customers,
              (expectedContext.scope.clubID ?? 0) > 0,
              (expectedContext.identity?.accountID ?? 0) > 0 else {
            state = .hidden; total = dash; monthNew = dash
            return
        }
        let contextMatches = acceptedContext == expectedContext
        let currentSnapshot: ClubGovernanceSnapshot? = {
            guard contextMatches, let snapshot, expectedContext.accepts(snapshot) else { return nil }
            return snapshot
        }()
        let currentFailure: ClubGovernanceFailure? = {
            guard let failure, acceptedContext == nil || contextMatches else { return nil }
            return failure
        }()
        if let currentFailure {
            if currentFailure == .forbidden || currentFailure == .signedOut {
                state = .hidden; total = dash; monthNew = dash
            } else if let copy = ClubOpsFailureCopy(operation: .customers, failure: currentFailure) {
                state = .error(copy); total = dash; monthNew = dash
            } else {
                state = .unknown; total = dash; monthNew = dash
            }
            return
        }
        if let currentSnapshot {
            guard currentSnapshot.permissions?.allows(ClubGovernanceRead.customers.permission, scope: expectedContext.scope) == true else {
                state = .hidden; total = dash; monthNew = dash
                return
            }
            let projected = Self.project(currentSnapshot.value)
            state = projected.0; total = projected.1; monthNew = projected.2
            return
        }
        if loading || (acceptedContext != nil && !contextMatches) {
            state = .loading; total = dash; monthNew = dash
            return
        }
        state = .unknown; total = dash; monthNew = dash
    }

    private enum CountFact: Equatable {
        case known(Int), unknown, invalid
        init(_ value: ClubGovernanceValue) {
            guard case .integer(let number) = value else { self = .unknown; return }
            self = number >= 0 ? .known(number) : .invalid
        }
        var count: Count {
            if case .known(let number) = self { return .known(number) }
            return .unknown
        }
    }

    private static func project(_ value: ClubGovernanceValue) -> (State, Count, Count) {
        let dash = Count.unknown
        if value == .string("UNKNOWN") || value == .null { return (.unknown, dash, dash) }
        guard value.object != nil else { return malformed() }
        let totalFact = CountFact(value["total"])
        let monthFact = CountFact(value["monthNew"])
        if totalFact == .invalid || monthFact == .invalid { return malformed() }
        let total = totalFact.count
        let month = monthFact.count
        if total == .unknown || month == .unknown { return (.unknown, total, month) }
        do {
            let list = try ClubOpsCustomerListPresentation(value: value)
            if list.rows.isEmpty { return (.empty, total, month) }
            return (.ready(list), total, month)
        } catch {
            return malformed()
        }
    }

    private static func malformed() -> (State, Count, Count) {
        let dash = Count.unknown
        guard let copy = ClubOpsFailureCopy(operation: .customers, failure: .malformed) else {
            return (.unknown, dash, dash)
        }
        return (.error(copy), dash, dash)
    }
}

/// MP pages/club/utils/club-phone-call.js: a call is offered only when the server grants
/// `phoneCallable` and the rendered text is an 11-digit mainland mobile number. No
/// permission is inferred here and the number is never logged.
public enum ClubPhoneCall {
    public static func callableNumber(_ value: String?) -> String? {
        let phone = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard phone.count == 11, phone.first == "1", phone.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return phone
    }
    public static func url(phoneText: String?, callable: Bool) -> URL? {
        guard callable, let number = callableNumber(phoneText) else { return nil }
        return URL(string: "tel:" + number)
    }
}
