import Foundation

/// SmsCoupon definition identity; never pass this to qr-token or redemption APIs.
public struct CouponDefinitionID: Hashable, Codable {
    public let value: Int
    public init(_ value: Int) throws { guard value > 0 else { throw CouponManagementError.invalid }; self.value = value }
    public init(from decoder: Decoder) throws { try self.init(decoder.singleValueContainer().decode(Int.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(value) }
}
public enum CouponManagementError: Error, Equatable {
    case invalid, malformed, unavailable, signedOut, changed, forbidden, storage, locked
    case server(String)
    public var messageKey: String {
        switch self {
        case .invalid: return "couponManagement.invalid"
        case .malformed: return "couponManagement.malformed"
        case .unavailable: return "couponManagement.unavailable"
        case .signedOut: return "couponManagement.signIn"
        case .changed: return "couponManagement.changed"
        case .forbidden: return "couponManagement.forbidden"
        case .storage: return "couponManagement.storage"
        case .locked: return "couponManagement.unknownOutcome"
        case .server: return "couponManagement.serverError"
        }
    }
}
public enum CouponDefinitionStatus: Equatable {
    case scheduled, active, ended, invalidated, stopped, unknown
    public init(_ raw: Int?) {
        switch raw { case 0: self = .scheduled; case 1: self = .active; case 2: self = .ended; case 3: self = .invalidated; case 4: self = .stopped; default: self = .unknown }
    }
    public var canStop: Bool { self == .scheduled || self == .active }
    public var key: String {
        switch self { case .scheduled: return "couponManagement.scheduled"; case .active: return "couponManagement.active"; case .ended: return "couponManagement.ended"; case .invalidated: return "couponManagement.invalidated"; case .stopped: return "couponManagement.stopped"; case .unknown: return "couponManagement.unknownStatus" }
    }
}
/// List projection only. No derived claim/redemption eligibility, money defaults or credential fields.
public struct CouponDefinition: Decodable, Equatable, Identifiable {
    public let id: CouponDefinitionID
    public let name: String?
    public let description: String?
    public let status: Int?
    public let couponType: Int?
    public let publishCount: Int?
    public let receiveCount: Int?
    public let useCount: Int?
    public let startTime: String?
    public let endTime: String?
    // Optional passthrough metadata, never emitted in the source publish request.
    public let amount: Decimal?
    public let currency: String?
    public let perLimit: Int?
    /// Publisher batch reference from SmsCoupon.code. Never use for issuing, claiming or redeeming.
    public let publishedBatchCode: String?
    private enum CodingKeys: String, CodingKey {
        case id, name, description, status, couponType, publishCount, receiveCount, useCount, startTime, endTime, amount, currency, perLimit, code
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(CouponDefinitionID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        status = try c.decodeIfPresent(Int.self, forKey: .status)
        couponType = try c.decodeIfPresent(Int.self, forKey: .couponType)
        publishCount = try c.decodeIfPresent(Int.self, forKey: .publishCount)
        receiveCount = try c.decodeIfPresent(Int.self, forKey: .receiveCount)
        useCount = try c.decodeIfPresent(Int.self, forKey: .useCount)
        startTime = try c.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try c.decodeIfPresent(String.self, forKey: .endTime)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        perLimit = try c.decodeIfPresent(Int.self, forKey: .perLimit)
        let sourceCode = try c.decodeIfPresent(String.self, forKey: .code)
        publishedBatchCode = sourceCode.flatMap { value in
            guard value != "—", !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        if !c.contains(.amount) { amount = nil }
        else if try c.decodeNil(forKey: .amount) { amount = nil }
        else if let number = try? c.decode(Decimal.self, forKey: .amount) { amount = number }
        else {
            let string = try c.decode(String.self, forKey: .amount)
            guard string.range(of: #"^-?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
                  let number = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else { throw CouponManagementError.malformed }
            amount = number
        }
    }
    public var state: CouponDefinitionStatus { .init(status) }
    public var remaining: Int? {
        guard let published = publishCount, let received = receiveCount, published >= 0, received >= 0 else { return nil }
        return received >= published ? 0 : published - received
    }
    public var typeKey: String { CouponManagementDraft.typeKey(couponType) }
    public static func displayDay(_ raw: String?) -> String? {
        // Display only. The server owns status and precise time eligibility.
        guard let raw else { return nil }
        let day = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(10))
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard let date = formatter.date(from: day), formatter.string(from: date) == day else { return nil }
        return day.replacingOccurrences(of: "-", with: ".")
    }
}
/// Coupon validity uses the existing merchant contract's China civil time, never the device zone.
public enum CouponValidityTime {
    public static var timeZone: TimeZone { TimeZone(secondsFromGMT: 8 * 3600)! }
    public static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = timeZone
        return value
    }
    private static func formatter(_ pattern: String) -> DateFormatter {
        let value = DateFormatter()
        value.locale = Locale(identifier: "en_US_POSIX")
        value.calendar = calendar
        value.timeZone = timeZone
        value.dateFormat = pattern
        value.isLenient = false
        return value
    }
    public static func wire(_ date: Date) -> String {
        formatter("yyyy-MM-dd HH:mm:ss").string(from: date)
    }
    public static func parse(_ raw: String) -> Date? {
        let value = formatter("yyyy-MM-dd HH:mm:ss")
        guard raw.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"#, options: .regularExpression) != nil,
              let date = value.date(from: raw), value.string(from: date) == raw else { return nil }
        return date
    }
    public static func display(_ date: Date) -> String {
        formatter("yyyy.MM.dd HH:mm:ss").string(from: date)
    }
    public static func display(_ raw: String?) -> String? {
        guard let raw, let date = parse(raw) else { return nil }
        return display(date)
    }
}
public struct CouponManagementDraft: Codable, Equatable {
    public var name = ""
    public var description = ""
    public var startTime: Date?
    public var endTime: Date?
    public var quantity = ""
    /// nil is the picker placeholder; wire types are exactly 0...3.
    public var couponType: Int?
    public init() {}
    public var dirty: Bool { !name.isEmpty || !description.isEmpty || startTime != nil || endTime != nil || !quantity.isEmpty || couponType != nil }
    public var blocker: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "couponManagement.nameRequired" }
        guard let start = startTime, let end = endTime else { return "couponManagement.datesRequired" }
        guard let type = couponType, (0...3).contains(type) else { return "couponManagement.typeRequired" }
        guard let count = Int(quantity.trimmingCharacters(in: .whitespacesAndNewlines)), count > 0 else { return "couponManagement.quantityRequired" }
        guard start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite,
              let wireStart = CouponValidityTime.parse(CouponValidityTime.wire(start)),
              let wireEnd = CouponValidityTime.parse(CouponValidityTime.wire(end)),
              wireEnd > wireStart else { return "couponManagement.dateOrder" }
        return nil
    }
    public static func typeKey(_ value: Int?) -> String {
        switch value { case 0: return "couponManagement.gift"; case 1: return "couponManagement.tenPercent"; case 2: return "couponManagement.twentyPercent"; case 3: return "couponManagement.experience"; default: return "couponManagement.coupon" }
    }
}
public struct CouponManagementSession: Equatable, Hashable {
    public let accountID: Int
    public let namespace: String
    public let epoch: UInt64
    public let authorizationRevision: String
    public init(accountID: Int, namespace: String, epoch: UInt64, authorizationRevision: String) throws {
        guard accountID > 0, !namespace.isEmpty, !authorizationRevision.isEmpty else { throw CouponManagementError.signedOut }
        self.accountID = accountID; self.namespace = namespace; self.epoch = epoch; self.authorizationRevision = authorizationRevision
    }
    // Durable identity deliberately excludes epoch: logging out cannot clear an uncertain submission.
    public var ownerKey: String { "\(namespace.utf8.count):\(namespace):\(accountID)" }
}
public struct CouponPublisherPermission: Equatable {
    public let revision: String
    public let mayPublish: Bool
    public let merchantID: Int?
    public let ownerMemberID: Int?
    public init(revision: String, mayPublish: Bool, merchantID: Int? = nil, ownerMemberID: Int? = nil) { self.revision = revision; self.mayPublish = mayPublish; self.merchantID = merchantID; self.ownerMemberID = ownerMemberID }
}
/// Host must supply fresh source-backed publisher eligibility, not a cached display role.
@MainActor public protocol CouponPublisherAuthorizing: AnyObject {
    func freshPermission(session: CouponManagementSession) async throws -> CouponPublisherPermission
}
@MainActor public final class CouponPublisherUnavailable: CouponPublisherAuthorizing {
    public init() {}
    public func freshPermission(session: CouponManagementSession) async throws -> CouponPublisherPermission { throw CouponManagementError.unavailable }
}

/// Read model for `subpackageMember/couponInfo/couponInfo`.
/// It uses the existing published list and the existing publish contract.
/// It does not register a route, mark one live, save an edit, or take payment.
/// Unknown amounts are an em dash. A literal 0 stays 0. A missing read stays hidden.
public struct CouponInfoSettingsCapability: Equatable {
    public let readsGranted: Bool
    public let publishGranted: Bool
    public init(readsGranted: Bool, publishGranted: Bool) {
        self.readsGranted = readsGranted
        self.publishGranted = readsGranted && publishGranted
    }
    /// The host's existing read and submit switches. This does not turn either one on.
    public init(canRead: Bool, canSubmitPublish: Bool) {
        self.init(readsGranted: canRead, publishGranted: canSubmitPublish)
    }
    public static let absent = Self(readsGranted: false, publishGranted: false)
}

/// A server amount on the coupon settings page. Unknown is never stored as 0.
public enum CouponInfoAmount: Equatable {
    case known(Decimal)
    case unknown
    public static let unknownDisplay = "—"
    public var literal: Decimal? {
        if case .known(let value) = self, !value.isNaN { return value }
        return nil
    }
    public var displayText: String {
        switch self {
        case .unknown: return Self.unknownDisplay
        case .known(let value): return Self.plain(value)
        }
    }
    public static func from(_ value: Decimal?) -> Self {
        guard let value, !value.isNaN else { return .unknown }
        return .known(value)
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
        let text = NSDecimalNumber(decimal: value).stringValue
        if text.isEmpty || text == "NaN" { return unknownDisplay }
        return text
    }
}

public enum CouponInfoCount {
    public static func display(_ value: Int?) -> String {
        guard let value else { return CouponInfoAmount.unknownDisplay }
        return String(value)
    }
}

public struct CouponInfoSettingsForm: Equatable {
    public let nameText: String
    public let descriptionText: String
    public let typeText: String
    public let quantityText: String
    public let startText: String
    public let endText: String
    public let amount: CouponInfoAmount
    public var amountText: String { amount.displayText }
    public let currencyText: String
    public let publishedText: String
    public let receivedText: String
    public let usedText: String
    public let remainingText: String
    public let perLimitText: String
    public let statusText: String

    public static func blank(_ draft: CouponManagementDraft = .init()) -> Self {
        let dash = CouponInfoAmount.unknownDisplay
        let quantity = draft.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self(
            nameText: draft.name,
            descriptionText: draft.description,
            typeText: draft.couponType.map { CouponManagementDraft.typeKey($0) } ?? dash,
            quantityText: quantity,
            startText: draft.startTime.map { CouponValidityTime.display($0) } ?? dash,
            endText: draft.endTime.map { CouponValidityTime.display($0) } ?? dash,
            amount: .unknown,
            currencyText: dash,
            publishedText: dash,
            receivedText: dash,
            usedText: dash,
            remainingText: dash,
            perLimitText: dash,
            statusText: dash)
    }

    init(_ row: CouponDefinition) {
        nameText = Self.serverText(row.name)
        descriptionText = Self.serverText(row.description)
        typeText = row.couponType == nil ? CouponInfoAmount.unknownDisplay : row.typeKey
        quantityText = CouponInfoCount.display(row.publishCount)
        startText = CouponValidityTime.display(row.startTime) ?? CouponInfoAmount.unknownDisplay
        endText = CouponValidityTime.display(row.endTime) ?? CouponInfoAmount.unknownDisplay
        amount = .from(row.amount)
        currencyText = Self.serverText(row.currency)
        publishedText = CouponInfoCount.display(row.publishCount)
        receivedText = CouponInfoCount.display(row.receiveCount)
        usedText = CouponInfoCount.display(row.useCount)
        remainingText = CouponInfoCount.display(row.remaining)
        perLimitText = CouponInfoCount.display(row.perLimit)
        statusText = row.state.key
    }

    private static func serverText(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? CouponInfoAmount.unknownDisplay : trimmed
    }

    private init(nameText: String, descriptionText: String, typeText: String, quantityText: String,
                 startText: String, endText: String, amount: CouponInfoAmount, currencyText: String,
                 publishedText: String, receivedText: String, usedText: String, remainingText: String,
                 perLimitText: String, statusText: String) {
        self.nameText = nameText
        self.descriptionText = descriptionText
        self.typeText = typeText
        self.quantityText = quantityText
        self.startText = startText
        self.endText = endText
        self.amount = amount
        self.currencyText = currencyText
        self.publishedText = publishedText
        self.receivedText = receivedText
        self.usedText = usedText
        self.remainingText = remainingText
        self.perLimitText = perLimitText
        self.statusText = statusText
    }
}

public struct CouponInfoSettingsPage: Equatable {
    public enum Phase: Equatable {
        case loading
        case empty
        case error(String)
        case unknown
        case ready
    }
    public enum Key {
        public static let loading = "couponManagement.loading"
        public static let empty = "couponManagement.empty"
        public static let signIn = "couponManagement.signIn"
        public static let unavailable = "couponManagement.unavailable"
        public static let malformed = "couponManagement.malformed"
        public static let serverError = "couponManagement.serverError"
        public static let unknownOutcome = "couponManagement.unknownOutcome"
        public static let forbidden = "couponManagement.forbidden"
        public static let storage = "couponManagement.storage"
        public static let changed = "couponManagement.changed"
        public static let invalid = "couponManagement.invalid"
        public static let refresh = "couponManagement.refresh"
        public static let checkPendingResults = "couponManagement.checkPendingResults"
        public static let referenced = [
            loading, empty, signIn, unavailable, malformed, serverError, unknownOutcome,
            forbidden, storage, changed, invalid, refresh, checkPendingResults
        ]
    }
    public static let publishedPath = "/api/coupon/mypublishlist"
    public static let publishPath = "/api/coupon/publish"
    public static let routeMarkedLive = false
    public static let includedInPlayerFirstEntry = false
    public static let paymentEnabled = false
    public static let virtualGoodsEnabled = false
    public static let saveEnabled = false

    public let readsGranted: Bool
    public let publishGranted: Bool
    public let phase: Phase?
    public let form: CouponInfoSettingsForm?
    public let editingID: Int?
    public let draft: CouponManagementDraft?
    public let emptyKey: String?

    public var hidden: Bool {
        switch phase {
        case .loading, nil: return true
        case .empty, .error, .unknown, .ready: return false
        }
    }
    public var stateKey: String? {
        switch phase {
        case .loading: return Key.loading
        case .empty: return emptyKey
        case .error(let key): return key
        case .unknown: return Key.unknownOutcome
        case .ready, nil: return nil
        }
    }
    public var retryKey: String? {
        if case .error = phase { return Key.refresh }
        return nil
    }
    public var recoveryKey: String? {
        if case .unknown = phase { return Key.checkPendingResults }
        return nil
    }
    /// Create stays hidden unless the existing publish grant is on and the draft is valid.
    /// An edit never publishes, and this never saves. Payment and virtual goods stay off.
    public var showsPublishAction: Bool {
        guard !Self.paymentEnabled, !Self.virtualGoodsEnabled, !Self.saveEnabled else { return false }
        guard readsGranted, publishGranted, editingID == nil else { return false }
        guard case .ready = phase, let draft, draft.blocker == nil else { return false }
        return true
    }
    public var showsSaveAction: Bool { false }

    public static func hidden() -> Self {
        Self(readsGranted: false, publishGranted: false, phase: nil, form: nil, editingID: nil, draft: nil, emptyKey: nil)
    }
    public static func loading(capability: CouponInfoSettingsCapability) -> Self {
        guard capability.readsGranted else { return hidden() }
        return Self(readsGranted: true, publishGranted: false, phase: .loading, form: nil, editingID: nil, draft: nil, emptyKey: nil)
    }

    public static func project(sessionPresent: Bool, editingID: Int?, rows: [CouponDefinition]?,
                               failure: CouponManagementError?, unresolved: Bool,
                               draft: CouponManagementDraft?, capability: CouponInfoSettingsCapability) -> Self {
        guard capability.readsGranted else { return hidden() }
        guard sessionPresent else {
            return Self(readsGranted: true, publishGranted: capability.publishGranted, phase: .empty,
                        form: nil, editingID: nil, draft: nil, emptyKey: Key.signIn)
        }
        if let failure {
            if case .locked = failure {
                return Self(readsGranted: true, publishGranted: capability.publishGranted, phase: .unknown,
                            form: .blank(), editingID: positive(editingID), draft: nil, emptyKey: nil)
            }
            return Self(readsGranted: true, publishGranted: capability.publishGranted, phase: .error(failure.messageKey),
                        form: nil, editingID: positive(editingID), draft: nil, emptyKey: nil)
        }
        if let raw = editingID {
            guard let id = positive(raw) else {
                return Self(readsGranted: true, publishGranted: capability.publishGranted, phase: .error(Key.invalid),
                            form: nil, editingID: nil, draft: nil, emptyKey: nil)
            }
            guard let rows else { return loading(capability: capability) }
            guard let row = rows.first(where: { $0.id.value == id }) else {
                return Self(readsGranted: true, publishGranted: capability.publishGranted, phase: .error(Key.unavailable),
                            form: nil, editingID: id, draft: nil, emptyKey: nil)
            }
            let form = CouponInfoSettingsForm(row)
            let phase: Phase = (unresolved || row.state == .unknown) ? .unknown : .ready
            return Self(readsGranted: true, publishGranted: capability.publishGranted, phase: phase,
                        form: form, editingID: id, draft: nil, emptyKey: nil)
        }
        guard capability.publishGranted else {
            return Self(readsGranted: true, publishGranted: false, phase: .empty,
                        form: nil, editingID: nil, draft: nil, emptyKey: Key.empty)
        }
        let value = draft ?? CouponManagementDraft()
        return Self(readsGranted: true, publishGranted: true, phase: unresolved ? .unknown : .ready,
                    form: .blank(value), editingID: nil, draft: value, emptyKey: nil)
    }

    /// Reads the existing published list when an edit id is present.
    /// A missing read does not call the adapter. This never publishes, saves, or pays.
    @MainActor public static func load(adapter: CouponManagementAdapter, session: CouponManagementSession?,
                                       editingID: Int?, unresolved: Bool = false,
                                       draft: CouponManagementDraft? = nil,
                                       capability: CouponInfoSettingsCapability) async -> Self {
        guard capability.readsGranted else { return hidden() }
        guard let session else {
            return project(sessionPresent: false, editingID: editingID, rows: nil, failure: nil,
                           unresolved: unresolved, draft: draft, capability: capability)
        }
        guard let editingID else {
            return project(sessionPresent: true, editingID: nil, rows: nil, failure: nil,
                           unresolved: unresolved, draft: draft, capability: capability)
        }
        guard editingID > 0 else {
            return project(sessionPresent: true, editingID: editingID, rows: nil, failure: nil,
                           unresolved: unresolved, draft: nil, capability: capability)
        }
        do {
            let rows = try await adapter.published(session: session)
            return project(sessionPresent: true, editingID: editingID, rows: rows, failure: nil,
                           unresolved: unresolved, draft: nil, capability: capability)
        } catch is CancellationError {
            return loading(capability: capability)
        } catch let error as CouponManagementError {
            return project(sessionPresent: true, editingID: editingID, rows: nil, failure: error,
                           unresolved: unresolved, draft: nil, capability: capability)
        } catch {
            return project(sessionPresent: true, editingID: editingID, rows: nil, failure: .unavailable,
                           unresolved: unresolved, draft: nil, capability: capability)
        }
    }

    private static func positive(_ raw: Int?) -> Int? {
        guard let raw, raw > 0 else { return nil }
        return raw
    }

    private init(readsGranted: Bool, publishGranted: Bool, phase: Phase?, form: CouponInfoSettingsForm?,
                 editingID: Int?, draft: CouponManagementDraft?, emptyKey: String?) {
        guard readsGranted else {
            self.readsGranted = false
            self.publishGranted = false
            self.phase = nil
            self.form = nil
            self.editingID = nil
            self.draft = nil
            self.emptyKey = nil
            return
        }
        self.readsGranted = true
        self.publishGranted = publishGranted
        self.editingID = editingID
        self.emptyKey = emptyKey
        switch phase {
        case .loading:
            self.phase = .loading
            self.form = nil
            self.draft = nil
        case nil:
            self.phase = .unknown
            self.form = form ?? .blank()
            self.draft = nil
        case .empty, .error:
            self.phase = phase
            self.form = nil
            self.draft = nil
        case .unknown, .ready:
            self.phase = phase
            self.form = form
            self.draft = draft
        }
    }
}
