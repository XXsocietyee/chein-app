import Foundation

/// P6 product catalog and frozen order read.
/// Sale is not decided from the tier. The deal price stays unknown until a server quote exists,
/// and this reader does not quote, order, pay, or activate. A fixed term is not described as
/// renewing, and no trial product is added. `priceState == UNKNOWN` is an em dash, never 0.
/// Order coverage is the snapshot on that response. It is not replaced by a later catalog.

public struct PWaveProductFact: Equatable, Sendable {
    public let purchaseKind: PWaveNumberFact
    public let exploreCapacity: PWaveNumberFact
    public let validityKind: PWaveNumberFact
    public let validDays: PWaveNumberFact
    public let fixedValidFrom: String?
    public let fixedValidTo: String?
    public let seatCount: PWaveNumberFact
    public let coveredTopicIDs: [String]?
    public let catalogPrice: PWaveNumberFact
    public let priceState: String?
    public let refundPolicy: String?
    public let contentRevisionPresent: Bool
    public let frozenSnapshot: Bool

    public var catalogPriceText: String {
        if priceState == "UNKNOWN" { return PWaveNumberFact.unknownDisplay }
        return catalogPrice.displayText
    }
    public var seatCountText: String { seatCount.displayText }
    public var coveredTopicCountText: String { PWaveCountText.text(coveredTopicIDs?.count) }
    public var validDaysText: String { validDays.displayText }
    public var saleDecidedFromTier: Bool { false }
    public var dealPriceText: String { PWaveNumberFact.unknownDisplay }
    public var purchaseShown: Bool { false }
    public var trialOffered: Bool { false }
    public var autoRenewOffered: Bool { false }
    public var describesFixedTermAsAutoRenew: Bool { false }
    public var paymentEqualsActivation: Bool { false }
    public var pricedLocally: Bool { false }
    public var hardcodesUsedNonRefundable: Bool { false }
    public var adoptsLaterCatalog: Bool { false }

    public init(purchaseKind: PWaveNumberFact, exploreCapacity: PWaveNumberFact, validityKind: PWaveNumberFact,
                validDays: PWaveNumberFact, fixedValidFrom: String?, fixedValidTo: String?, seatCount: PWaveNumberFact,
                coveredTopicIDs: [String]?, catalogPrice: PWaveNumberFact, priceState: String?, refundPolicy: String?,
                contentRevisionPresent: Bool, frozenSnapshot: Bool) {
        self.purchaseKind = purchaseKind
        self.exploreCapacity = exploreCapacity
        self.validityKind = validityKind
        self.validDays = validDays
        self.fixedValidFrom = fixedValidFrom
        self.fixedValidTo = fixedValidTo
        self.seatCount = seatCount
        self.coveredTopicIDs = coveredTopicIDs
        self.catalogPrice = catalogPrice
        self.priceState = priceState
        self.refundPolicy = refundPolicy
        self.contentRevisionPresent = contentRevisionPresent
        self.frozenSnapshot = frozenSnapshot
    }
}

public struct PWaveCityPassFact: Equatable, Sendable {
    public let products: [PWaveProductFact]
    public var purchaseShown: Bool { false }
    public var trialOffered: Bool { false }
    public var autoRenewOffered: Bool { false }
    public var dealPriceText: String { PWaveNumberFact.unknownDisplay }

    public init(products: [PWaveProductFact]) {
        self.products = products
    }
}

public enum PWaveCityPass {
    public static let listLimit = 20

    public static func decode(data: Data, status: Int, supported: Set<String>, frozenSnapshot: Bool) -> PWavePresentation<PWaveCityPassFact> {
        PWaveServerCapability.presentation(data: data, status: status, supported: supported) { _, payload in
            fact(payload, frozenSnapshot: frozenSnapshot)
        }
    }

    static func fact(_ payload: PlayWireValue, frozenSnapshot: Bool) -> PWaveServerFact<PWaveCityPassFact> {
        switch payload {
        case .array(let items):
            if items.isEmpty { return .empty }
            var products: [PWaveProductFact] = []
            for item in items {
                guard let product = product(item, frozenSnapshot: frozenSnapshot) else { return .unknown }
                products.append(product)
            }
            return .ready(PWaveCityPassFact(products: products))
        case .object(_):
            guard let product = product(payload, frozenSnapshot: frozenSnapshot) else { return .unknown }
            return .ready(PWaveCityPassFact(products: [product]))
        default:
            return .unknown
        }
    }

    private static func product(_ value: PlayWireValue, frozenSnapshot: Bool) -> PWaveProductFact? {
        guard let object = value.object else { return nil }
        let keys = ["purchase_kind", "explore_capacity", "validityKind", "validDays", "fixedValidFrom",
                    "fixedValidTo", "seat_count", "coveredTopics", "price", "priceState", "refundPolicy", "contentRevision"]
        guard keys.contains(where: { object.keys.contains($0) }) else { return nil }
        let priceState = PWaveEnvelope.text(object["priceState"] ?? .null)
        let price = priceState == "UNKNOWN" ? PWaveNumberFact.unknown : number(object, "price")
        return PWaveProductFact(
            purchaseKind: number(object, "purchase_kind"),
            exploreCapacity: number(object, "explore_capacity"),
            validityKind: number(object, "validityKind"),
            validDays: number(object, "validDays"),
            fixedValidFrom: PWaveEnvelope.text(object["fixedValidFrom"] ?? .null),
            fixedValidTo: PWaveEnvelope.text(object["fixedValidTo"] ?? .null),
            seatCount: number(object, "seat_count"),
            coveredTopicIDs: topics(object["coveredTopics"]),
            catalogPrice: price,
            priceState: priceState,
            refundPolicy: PWaveEnvelope.text(object["refundPolicy"] ?? .null),
            contentRevisionPresent: present(object["contentRevision"]),
            frozenSnapshot: frozenSnapshot)
    }

    private static func topics(_ value: PlayWireValue?) -> [String]? {
        guard let value else { return nil }
        guard case .array(let items) = value else { return nil }
        var ids: [String] = []
        for item in items {
            switch PWaveIdentifierFact.parse(item) {
            case .text(let raw): ids.append(raw)
            case .integer(let number): ids.append(String(number))
            case .unknown: return nil
            }
        }
        return ids
    }

    private static func present(_ value: PlayWireValue?) -> Bool {
        guard let value else { return false }
        if case .null = value { return false }
        return true
    }

    private static func number(_ object: [String: PlayWireValue], _ key: String) -> PWaveNumberFact {
        guard let value = object[key] else { return .unknown }
        return PWaveNumberFact.parse(value)
    }
}
