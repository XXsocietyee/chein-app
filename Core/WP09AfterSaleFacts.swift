import Foundation

// MARK: OWN-U02-04

/// Source lineage on a template the author already copied. Diff and save-as-new stay closed until a server action exists. No revision evidence says the history still needs checking.
public struct SourceLineagePresentation: Equatable {
    public let identity: String
    public let historyPending: Bool
    public let continueCurrent: Bool
    public let viewDiff: Bool
    public let saveAsNew: Bool

    public init(sourceContentRevisionId: String?) {
        let trimmed = sourceContentRevisionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            identity = WP09Copy.unknown
            historyPending = true
            continueCurrent = false
            viewDiff = false
            saveAsNew = false
        } else {
            identity = trimmed
            historyPending = false
            continueCurrent = true
            viewDiff = false
            saveAsNew = false
        }
    }

    public func historyLine(chinese: Bool) -> String {
        historyPending ? WP09Copy.text("历史来源待核对", "Source history still needs checking", chinese: chinese) : identity
    }
}

// MARK: OWN-U06-04

public struct TeamPlayRoleFacts: Decodable, Equatable {
    public let myRoleLabel: String?
    public let myTask: String?
    public let myEvidence: [String]
    public let waitingOn: String?
    public let myPrivateClues: [String]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        myRoleLabel = Self.text(c, .myRoleLabel)
        myTask = Self.text(c, .myTask)
        myEvidence = Self.list(c, .myEvidence)
        waitingOn = Self.text(c, .waitingOn)
        myPrivateClues = Self.list(c, .myPrivateClues)
    }

    private enum CodingKeys: String, CodingKey {
        case myRoleLabel, myTask, myEvidence, waitingOn, myPrivateClues
    }

    private static func text(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        let raw = (try? c.decodeIfPresent(String.self, forKey: key))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
    }

    private static func list(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> [String] {
        ((try? c.decodeIfPresent([String].self, forKey: key)) ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

/// Organizer facts and a shared result. Club headcount and this session's participants stay on different labels. No merchant-asset write is offered.
public struct TeamSharedOutcome: Decodable, Equatable {
    public let whoMustAct: String?
    public let chapterRelease: String?
    public let paused: Bool?
    public let summary: String?
    public let population: String?
    public let timeWindow: String?
    public let clubHeadcount: Int?
    public let sessionParticipants: Int?

    public static let merchantAssetWrites: [String] = []

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        whoMustAct = Self.text(c, .whoMustAct)
        chapterRelease = Self.text(c, .chapterRelease)
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused)
        summary = Self.text(c, .summary)
        population = Self.text(c, .population)
        timeWindow = Self.text(c, .timeWindow)
        clubHeadcount = Self.count(c, .clubHeadcount)
        sessionParticipants = Self.count(c, .sessionParticipants)
    }

    private enum CodingKeys: String, CodingKey {
        case whoMustAct, chapterRelease, paused, summary, population, timeWindow, clubHeadcount, sessionParticipants
    }

    public func line(_ value: String?) -> String { value?.isEmpty == false ? value! : WP09Copy.unknown }

    public func countLine(_ value: Int?) -> String { value.map(String.init) ?? WP09Copy.unknown }

    public func pausedLine(chinese: Bool) -> String {
        switch paused {
        case true: return WP09Copy.text("已暂停", "Paused", chinese: chinese)
        case false: return WP09Copy.text("未暂停", "Not paused", chinese: chinese)
        case nil: return WP09Copy.unknown
        }
    }

    private static func text(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        let raw = (try? c.decodeIfPresent(String.self, forKey: key))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
    }

    private static func count(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? c.decodeIfPresent(Int.self, forKey: key), value >= 0 { return value }
        return nil
    }
}

// MARK: OWN-U07-01

public struct OrderDeliveryFacts: Decodable, Equatable {
    public let purchaseKind: String?
    public let ticketName: String?
    public let teamSize: Int?
    public let minPeople: Int?
    public let maxPeople: Int?
    public let needAudit: Bool?
    public let serviceStartAt: String?
    public let serviceEndAt: String?
    public let refundRule: String?
    public let beneficiaryKind: String?
    public let amountFromServer: Decimal?

    public var mixedTickets: Bool {
        purchaseKind == nil && ticketName == nil && teamSize == nil && minPeople == nil && maxPeople == nil
            && serviceStartAt == nil && serviceEndAt == nil && refundRule == nil && beneficiaryKind == nil
    }

    public func headline(chinese: Bool) -> String {
        mixedTickets ? WP09Copy.text("按票种分别说明", "Each ticket type is explained separately", chinese: chinese) : (ticketName ?? WP09Copy.unknown)
    }

    /// `refundRule == nil` does not say the order can be refunded.
    public func refundLine(chinese: Bool) -> String? {
        guard let refundRule, !refundRule.isEmpty else { return nil }
        return refundRule
    }

    public var amountLine: String { WP09Copy.amount(amountFromServer) }
}

// MARK: OWN-U07-02

public enum PaymentReturnPhase: Equatable {
    case querying, received, pendingConfirmation, cancelled, failed, unknown

    public init(loading: Bool, payment: Int?, registration: Int?) {
        if loading { self = .querying; return }
        if payment == 2 { self = .received; return }
        if registration == 3 { self = .cancelled; return }
        if payment == 3 || payment == 4 { self = .failed; return }
        if payment == nil && registration == nil { self = .unknown; return }
        self = .pendingConfirmation
    }

    /// Server paid is the only open. An SDK success while the order is still pending does not unlock anything.
    public var unlocksEntitlement: Bool { self == .received }

    public func title(chinese: Bool) -> String {
        switch self {
        case .querying: return WP09Copy.text("查询中", "Checking", chinese: chinese)
        case .received: return WP09Copy.text("已到账", "Received", chinese: chinese)
        case .pendingConfirmation: return WP09Copy.text("待确认", "Waiting for confirmation", chinese: chinese)
        case .cancelled: return WP09Copy.text("已取消", "Canceled", chinese: chinese)
        case .failed: return WP09Copy.text("确定失败", "Failed", chinese: chinese)
        case .unknown: return WP09Copy.unknown
        }
    }
}

public struct PaymentChannelNote: Equatable {
    public let text: String
    public init(channels: [String]?, chinese: Bool) {
        guard let channels else { text = WP09Copy.unknown; return }
        if channels.contains(where: { $0.caseInsensitiveCompare("wechat") == .orderedSame || $0 == "微信" }) {
            text = WP09Copy.text("微信通道就绪。这不代表 App 内购买或商店政策已通过。", "The WeChat channel is ready. That is not an in-app purchase or a store-policy approval.", chinese: chinese)
        } else if channels.isEmpty {
            text = WP09Copy.unknown
        } else {
            text = channels.joined(separator: ", ")
        }
    }
}

// MARK: OWN-U07-04

/// Partial refund amounts are the server's figures. They are never added together on the device. An incomplete set does not show a definite total.
public struct OrderSettlementFacts: Decodable, Equatable {
    public let refundStage: String?
    public let refundPendingAmount: Decimal?
    public let refundProcessingAmount: Decimal?
    public let refundCompletedAmount: Decimal?
    public let amountsComplete: Bool?

    public var pendingLine: String { WP09Copy.amount(refundPendingAmount) }
    public var processingLine: String { WP09Copy.amount(refundProcessingAmount) }
    public var completedLine: String { WP09Copy.amount(refundCompletedAmount) }
    public var stageLine: String { refundStage?.isEmpty == false ? refundStage! : WP09Copy.unknown }

    public func totalLine(chinese: Bool) -> String {
        guard amountsComplete == true else {
            return WP09Copy.text("合计未齐", "The total is not complete", chinese: chinese)
        }
        return WP09Copy.unknown
    }

    /// The three server amounts and nothing derived from them.
    public var serverAmounts: [String] { [pendingLine, processingLine, completedLine] }
}

// MARK: OWN-U07-05

public struct CreatorAccrualProjection: Equatable {
    public enum State: Equatable { case available, unknown }
    public let state: State
    public let gross: Decimal?
    public let refunded: Decimal?
    public let net: Decimal?
    public let basisNote: String?
    public let reason: String?
    public let periodStart: String?
    public let periodEnd: String?

    public struct Line: Equatable { public let title: String; public let value: String }

    public static func unknown(reason: String?) -> CreatorAccrualProjection {
        CreatorAccrualProjection(state: .unknown, gross: nil, refunded: nil, net: nil, basisNote: nil, reason: reason, periodStart: nil, periodEnd: nil)
    }

    /// Amounts appear only for a successful read. Unknown shows no amount, including no zero. Net is accrual, not a balance that can be withdrawn. Marketing allocation is not added.
    public func lines(chinese: Bool) -> [Line] {
        let period = [periodStart, periodEnd].compactMap { $0 }.joined(separator: " – ")
        switch state {
        case .unknown:
            return [
                Line(title: WP09Copy.text("收益", "Earnings", chinese: chinese),
                     value: WP09Copy.text("收益暂不可用", "Earnings are unavailable right now", chinese: chinese)),
                Line(title: WP09Copy.text("原因", "Reason", chinese: chinese), value: reason?.isEmpty == false ? reason! : WP09Copy.unknown)
            ]
        case .available:
            return [
                Line(title: WP09Copy.text("应计", "Accrual", chinese: chinese), value: basisNote?.isEmpty == false ? basisNote! : WP09Copy.unknown),
                Line(title: WP09Copy.text("成交", "Gross", chinese: chinese), value: WP09Copy.amount(gross)),
                Line(title: WP09Copy.text("退款冲销", "Refunded", chinese: chinese), value: WP09Copy.amount(refunded)),
                Line(title: WP09Copy.text("应计净额", "Accrual net", chinese: chinese), value: WP09Copy.amount(net)),
                Line(title: WP09Copy.text("期间", "Period", chinese: chinese), value: period.isEmpty ? WP09Copy.unknown : period)
            ]
        }
    }

    public var showsAmounts: Bool { state == .available }
}
