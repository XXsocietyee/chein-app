import Foundation

/// P2 `GET /api/marketing/affiliate/summary?limit=20`.
/// The read does not issue a link, settle, or pay. Credentials are not copied, so a plaintext token
/// cannot be shown. `held.amountFen` null stays unknown. `payout.available` must be JSON true before
/// a withdrawal can be offered, and a false flag is not a balance. Multi-currency totals stay unknown.

public struct PWaveAffiliateSummaryFact: Equatable, Sendable {
    public static let multipleCurrenciesCopy = "多币种暂不合计"
    public static let emptyRecordsCopy = "暂无可核实记录"
    public static let multipleCurrenciesReason = "MULTIPLE_CURRENCIES"

    public let credentialCount: Int?
    public let campaignCount: Int?
    public let allocationCount: Int?
    public let heldAmountFen: PWaveNumberFact
    public let heldAmountNull: Bool
    public let payoutAvailable: Bool?
    public let multipleCurrencies: Bool
    public let currency: String?

    public var heldAmountText: String {
        multipleCurrencies ? Self.multipleCurrenciesCopy : heldAmountFen.displayText
    }
    public var credentialCountText: String { PWaveCountText.text(credentialCount) }
    public var campaignCountText: String { PWaveCountText.text(campaignCount) }
    public var allocationCountText: String { PWaveCountText.text(allocationCount) }
    public var withdrawShown: Bool {
        payoutAvailable == true && !multipleCurrencies && !heldAmountNull && heldAmountFen.literal != nil
    }
    public var showsArrived: Bool { false }
    public var usesMerchantWithdraw: Bool { false }
    public var issuesLinkOnRead: Bool { false }
    public var storesPlaintextToken: Bool { false }
    public var sumsCurrencies: Bool { false }
    public var mergedAwayPartialReversals: Bool { false }
    public var campaignRefundSummaryCoversEveryPartialRefund: Bool { false }

    public init(credentialCount: Int?, campaignCount: Int?, allocationCount: Int?, heldAmountFen: PWaveNumberFact,
                heldAmountNull: Bool, payoutAvailable: Bool?, multipleCurrencies: Bool, currency: String?) {
        self.credentialCount = credentialCount
        self.campaignCount = campaignCount
        self.allocationCount = allocationCount
        self.heldAmountFen = heldAmountFen
        self.heldAmountNull = heldAmountNull
        self.payoutAvailable = payoutAvailable
        self.multipleCurrencies = multipleCurrencies
        self.currency = currency
    }
}

public enum PWaveAffiliateCenter {
    public static let limit = 20

    public static func decode(data: Data, status: Int, supported: Set<String>) -> PWavePresentation<PWaveAffiliateSummaryFact> {
        PWaveServerCapability.presentation(data: data, status: status, supported: supported) { _, payload in
            fact(payload)
        }
    }

    static func fact(_ payload: PlayWireValue) -> PWaveServerFact<PWaveAffiliateSummaryFact> {
        guard let object = payload.object else { return .unknown }
        let credentialCount = PWaveCountText.arrayCount(object, "credentials")
        let campaignCount = PWaveCountText.arrayCount(object, "campaigns")
        let allocationCount = PWaveCountText.arrayCount(object, "allocations")
        let held = heldAmount(object)
        let payoutAvailable = object["payout"]?.object?["available"]?.bool
        let multiple = multipleCurrencies(object)
        let currency = multiple ? nil : currencyText(object)
        let classified = credentialCount != nil || campaignCount != nil || allocationCount != nil
            || object.keys.contains("held") || object.keys.contains("payout") || multiple
        guard classified else { return .unknown }
        let summary = PWaveAffiliateSummaryFact(
            credentialCount: credentialCount, campaignCount: campaignCount, allocationCount: allocationCount,
            heldAmountFen: multiple ? .unknown : held.amount, heldAmountNull: held.wasNull || multiple,
            payoutAvailable: payoutAvailable, multipleCurrencies: multiple, currency: currency)
        if credentialCount == 0 && campaignCount == 0 && allocationCount == 0
            && summary.heldAmountFen.literal == nil && !multiple && payoutAvailable != true {
            return .empty
        }
        return .ready(summary)
    }

    private static func heldAmount(_ object: [String: PlayWireValue]) -> (amount: PWaveNumberFact, wasNull: Bool) {
        guard let held = object["held"] else { return (.unknown, false) }
        if case .null = held { return (.unknown, true) }
        guard let fields = held.object else { return (.unknown, false) }
        guard fields.keys.contains("amountFen") else { return (.unknown, false) }
        let raw = fields["amountFen"] ?? .null
        if case .null = raw { return (.unknown, true) }
        return (PWaveNumberFact.parse(raw), false)
    }

    private static func multipleCurrencies(_ object: [String: PlayWireValue]) -> Bool {
        if isMultiple(object) { return true }
        if isMultiple(object["held"]?.object) { return true }
        for key in ["allocations", "campaigns"] {
            for item in object[key]?.array ?? [] {
                if isMultiple(item.object) { return true }
            }
        }
        return false
    }

    private static func isMultiple(_ object: [String: PlayWireValue]?) -> Bool {
        guard case .string(let raw)? = object?["amountUnavailableReason"] else { return false }
        return raw == PWaveAffiliateSummaryFact.multipleCurrenciesReason
    }

    private static func currencyText(_ object: [String: PlayWireValue]) -> String? {
        let held = PWaveEnvelope.text(object["held"]?.object?["currency"] ?? .null)
        if let held, held != "UNKNOWN" { return held }
        let root = PWaveEnvelope.text(object["currency"] ?? .null)
        if let root, root != "UNKNOWN" { return root }
        return nil
    }
}

enum PWaveCountText {
    static func text(_ count: Int?) -> String {
        guard let count else { return PWaveNumberFact.unknownDisplay }
        return String(count)
    }

    static func arrayCount(_ object: [String: PlayWireValue], _ key: String) -> Int? {
        guard let value = object[key], case .array(let items) = value else { return nil }
        return items.count
    }
}
