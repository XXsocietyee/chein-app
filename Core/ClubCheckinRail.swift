import Foundation

/// Mini-program club/checkin-detail `buildRail`: 已报名 → 已接洽 → 已核销 → 已评价.
/// `railStep` = -1 (refunded) or an absent/non-integer step lights nothing; the client
/// never infers progress from other fields.
public struct ClubCheckinRail: Equatable {
    public enum Step: String, CaseIterable, Sendable { case signed, contacted, verified, reviewed }
    public enum StateKind: String, Equatable, Sendable {
        case missing
        case denied
        case error

        public var title: String {
            switch self {
            case .missing: return "核销记录不存在"
            case .denied: return "无权查看该核销记录"
            case .error: return "核销详情加载失败"
            }
        }
        /// Catalog keys for the titles above. They are not in the string catalog yet.
        public var titleKey: String {
            switch self {
            case .missing: return "club.checkin.state.missing"
            case .denied: return "club.checkin.state.denied"
            case .error: return "club.checkin.state.error"
            }
        }
    }
    public struct Stop: Equatable, Identifiable {
        public let step: Step
        public let reached: Bool
        public let current: Bool
        public var id: String { step.rawValue }
    }
    public let stops: [Stop]
    /// `statusCode == REFUNDED`: 这单已退款，履约轨迹不再推进。
    public let refunded: Bool
    public let sessionTimeText: String?
    public let statusTimeText: String?
    public init(railStep: ClubGovernanceValue, statusCode: ClubGovernanceValue, sessionTime: ClubGovernanceValue = .null, statusTime: ClubGovernanceValue = .null) {
        let at: Int? = { if case .integer(let value) = railStep { return value }; return nil }()
        stops = Step.allCases.enumerated().map { index, step in
            .init(step: step, reached: (at ?? -1) >= 0 && index <= (at ?? -1), current: at == index)
        }
        refunded = statusCode == .string("REFUNDED")
        sessionTimeText = Self.formatTime(sessionTime)
        statusTimeText = Self.formatTime(statusTime)
    }
    public static func stateKind(for failure: ClubGovernanceFailure?, recordPresent: Bool = true) -> StateKind? {
        if let failure {
            switch failure {
            case .forbidden: return .denied
            case .rejected(let code, _):
                if code == 403 { return .denied }
                if code == 404 { return .missing }
                return .error
            default:
                return .error
            }
        }
        return recordPresent ? nil : .missing
    }
    public static func stateTitle(for failure: ClubGovernanceFailure?, recordPresent: Bool = true) -> String? {
        stateKind(for: failure, recordPresent: recordPresent)?.title
    }
    public static func formatTime(_ value: ClubGovernanceValue) -> String? {
        switch value {
        case .string(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "T", with: " ")
            guard !trimmed.isEmpty else { return nil }
            return trimmed.count >= 16 ? String(trimmed.prefix(16)) : trimmed
        case .integer(let ms) where ms > 0:
            let seconds = ms > 10_000_000_000 ? Double(ms) / 1000.0 : Double(ms)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: Date(timeIntervalSince1970: seconds))
        default:
            return nil
        }
    }
}

/// Read-only binding for the existing club check-in detail contract.
/// `ClubGovernanceRead.checkin` already names `api/club/crm/checkin/detail`. This type does not
/// add a route and does not mark one live. Refund, payment, payout, and withdrawal stay off.
/// A missing client capability stays hidden. UNKNOWN, null, a missing number, and a numeric
/// string display as an em dash and are never stored as 0. A literal JSON 0 stays 0.
public struct ClubCheckinDetailPage: Equatable {
    public static let unknownDisplay = "—"
    public static let readPath = ClubGovernanceRead.checkin.path
    public static let emptyTitleKey = "club.gov.empty"

    public enum Phase: Equatable {
        case loading
        case empty
        case error(ClubCheckinRail.StateKind)
        case unknown
        case ready(Facts)
    }

    public struct Facts: Equatable {
        public let registrationIDText: String
        public let railStepText: String
        public let displayName: String
        public let topicName: String
        public let ticketText: String
        public let orderTimeText: String
        public let paidAmountText: String
        public let verifyTimeText: String
        public let storeName: String
        public let operatorName: String
        public let sessionTimeText: String
        public let statusTimeText: String
        public let statusText: String
        public let orderNoText: String
        public let phoneText: String
        public let avatar: String?
        public let rail: ClubCheckinRail
        /// JSON `true` only. A missing flag is not a refund.
        public let serverCanRefund: Bool
    }

    public let clientCapabilityPresent: Bool
    public let serverFactPresent: Bool
    public let phase: Phase?
    public var showsContent: Bool {
        switch phase {
        case .empty, .error, .unknown, .ready: return true
        case .loading, nil: return false
        }
    }
    public var showsMerchantChoice: Bool { false }
    public var showsRefundAction: Bool { false }
    public var refundDispatchEnabled: Bool { false }
    public var paymentEnabled: Bool { false }
    public var payoutEnabled: Bool { false }
    public var withdrawalEnabled: Bool { false }

    public init(clientCapabilityPresent: Bool, serverFactPresent: Bool, phase: Phase?) {
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
    }

    public static func loading(clientCapabilityPresent: Bool) -> Self {
        Self(clientCapabilityPresent: clientCapabilityPresent, serverFactPresent: false, phase: .loading)
    }

    /// `value == nil` with no failure and no load is hidden: the read has not produced a fact.
    /// `.null`, a numeric string id, or any other unnamed shape is `.unknown`, not an id of 0.
    public static func bind(clientCapabilityPresent: Bool, loading: Bool = false, failure: ClubGovernanceFailure? = nil, value: ClubGovernanceValue? = nil, recordPresent: Bool = true) -> Self {
        guard clientCapabilityPresent else {
            return Self(clientCapabilityPresent: false, serverFactPresent: false, phase: nil)
        }
        if let failure {
            let kind = ClubCheckinRail.stateKind(for: failure, recordPresent: recordPresent) ?? .error
            return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .error(kind))
        }
        if loading, value == nil {
            return .loading(clientCapabilityPresent: true)
        }
        if let value, case .object(let fields) = value, fields.isEmpty {
            return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .empty)
        }
        if let value, case .array(let rows) = value, rows.isEmpty {
            return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .empty)
        }
        if let value, let facts = Facts(value) {
            return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .ready(facts))
        }
        if let value, case .null = value {
            return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .unknown)
        }
        if value != nil {
            return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .unknown)
        }
        if !recordPresent {
            return Self(clientCapabilityPresent: true, serverFactPresent: true, phase: .empty)
        }
        return Self(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
    }

    /// Exact integer numbers only. Numeric strings, null, and non-integral numbers are unknown.
    public static func numberText(_ value: ClubGovernanceValue) -> String {
        switch value {
        case .integer(let number):
            return String(number)
        case .decimal(let number):
            guard number.isFinite, let exact = Int(exactly: number) else { return unknownDisplay }
            return String(exact)
        case .string, .bool, .null, .object, .array:
            return unknownDisplay
        }
    }

    /// Server text stays verbatim, including the digits `0`. The word UNKNOWN, blank, null,
    /// and a non-number object are an em dash. A JSON number 0 stays `0`.
    public static func display(_ value: ClubGovernanceValue) -> String {
        switch value {
        case .string(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "UNKNOWN" { return unknownDisplay }
            return trimmed
        case .integer(let number):
            return String(number)
        case .decimal(let number):
            guard number.isFinite else { return unknownDisplay }
            if let exact = Int(exactly: number) { return String(exact) }
            return String(number)
        case .bool, .null, .object, .array:
            return unknownDisplay
        }
    }

    public static func avatar(_ value: ClubGovernanceValue) -> String? {
        guard case .string(let raw) = value else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "UNKNOWN" else { return nil }
        return trimmed
    }
}

extension ClubCheckinDetailPage.Facts {
    init?(_ value: ClubGovernanceValue) {
        guard case .object = value, case .integer = value["registrationId"] else { return nil }
        registrationIDText = ClubCheckinDetailPage.numberText(value["registrationId"])
        railStepText = ClubCheckinDetailPage.numberText(value["railStep"])
        displayName = ClubCheckinDetailPage.display(value["displayName"])
        topicName = ClubCheckinDetailPage.display(value["topicName"])
        ticketText = ClubCheckinDetailPage.display(value["ticketText"])
        orderTimeText = ClubCheckinDetailPage.display(value["orderTimeText"])
        paidAmountText = ClubCheckinDetailPage.display(value["paidAmountText"])
        verifyTimeText = ClubCheckinDetailPage.display(value["verifyTimeText"])
        storeName = ClubCheckinDetailPage.display(value["storeName"])
        operatorName = ClubCheckinDetailPage.display(value["operatorName"])
        sessionTimeText = ClubCheckinDetailPage.display(Self.time(value, text: "sessionTimeText", instant: "sessionTime"))
        statusTimeText = ClubCheckinDetailPage.display(Self.time(value, text: "statusTimeText", instant: "statusTime"))
        statusText = ClubCheckinDetailPage.display(value["statusText"])
        orderNoText = ClubCheckinDetailPage.display(value["orderNo"])
        phoneText = ClubCheckinDetailPage.display(value["phoneText"])
        avatar = ClubCheckinDetailPage.avatar(value["avatar"])
        rail = ClubCheckinRail(railStep: value["railStep"], statusCode: value["statusCode"], sessionTime: value["sessionTime"], statusTime: value["statusTime"])
        serverCanRefund = value["canRefund"] == .bool(true)
    }

    private static func time(_ value: ClubGovernanceValue, text: String, instant: String) -> ClubGovernanceValue {
        if value[text] != .null { return value[text] }
        return value[instant]
    }
}
