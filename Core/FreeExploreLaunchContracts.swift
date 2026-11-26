import Foundation
import CryptoKit

public enum FreeExploreLaunchFailure: Error, Equatable {
    case invalid, malformed, staleSession, disabled, busy, pendingConflict
    case storageUnavailable, outcomeUnknown, cancellationQuoteUnavailable
    case response(status: Int, code: Int, businessCode: String?, message: String?)
}

/// Java Longs must never pass through Double (including persisted recovery IDs).
public struct FreeExploreLaunchID: Codable, Hashable {
    public let value: Int64
    public var text: String { String(value) }
    public init(_ value: Int64) throws {
        guard value > 0 else { throw FreeExploreLaunchFailure.invalid }
        self.value = value
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let text = try? c.decode(String.self) {
            guard let value = Int64(text), String(value) == text, value > 0 else { throw FreeExploreLaunchFailure.malformed }
            self.value = value
        } else {
            let value = try c.decode(Int64.self)
            guard value > 0 else { throw FreeExploreLaunchFailure.malformed }
            self.value = value
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer(); try c.encode(value)
    }
}

/// Server decimals are display values. There is no refund/price arithmetic here.
public struct FreeExploreLaunchDecimal: Decodable, Equatable {
    public let text: String
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let string = try? c.decode(String.self) { text = string }
        else { text = NSDecimalNumber(decimal: try c.decode(Decimal.self)).stringValue }
        guard !text.isEmpty, text.utf8.count <= 100,
              text.range(of: "^(0|[1-9][0-9]*)(\\.[0-9]+)?$", options: .regularExpression) != nil else {
            throw FreeExploreLaunchFailure.malformed
        }
    }
}

public struct FreeExploreLaunchCatalog: Decodable, Equatable {
    public struct Item: Decodable, Equatable {
        public struct Store: Decodable, Equatable {
            public let offerId: FreeExploreLaunchID
            public let merchantName: String?
            public let validEnd: String?
            /// `store.available === true`. A missing key is false. The row still shows.
            public let available: Bool
            private enum CodingKeys: String, CodingKey { case offerId, merchantName, validEnd, available }
            public init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                offerId = try c.decode(FreeExploreLaunchID.self, forKey: .offerId)
                merchantName = try c.decodeIfPresent(String.self, forKey: .merchantName)
                validEnd = try c.decodeIfPresent(String.self, forKey: .validEnd)
                available = (try? c.decode(Bool.self, forKey: .available)) == true
            }
        }
        public let chapterId: FreeExploreLaunchID
        public let name: String?
        public let termsMode: String?
        public let unitsPerHolder: Int
        public let stores: [Store]
    }
    public let topicId: FreeExploreLaunchID
    public let topicName: String?
    public let productType: Int
    public let saleEnabled: Bool
    public let reservationEnabled: Bool
    public let items: [Item]
}

public struct FreeExploreLaunchReservation: Decodable, Equatable {
    public let id: FreeExploreLaunchID
    public let registrationId: FreeExploreLaunchID
    public let holderMemberId: FreeExploreLaunchID
    public let unitId: FreeExploreLaunchID
    public let chapterId: FreeExploreLaunchID
    public let offerId: FreeExploreLaunchID
    public let merchantId: FreeExploreLaunchID
    public let startAt: String
    /// Unknown values remain readable; they never become permission to write.
    public let status: String
    public let idempotencyKey: String
    public let requestFingerprint: String
    /// MP `reservation`: only `BOOKED` can cancel. This does not send a cancel.
    public var canCancel: Bool { status == "BOOKED" }
    public func matches(_ command: FreeExploreLaunchReservationCommand, owner: FreeExploreLaunchID) -> Bool {
        holderMemberId == owner && registrationId == command.registrationId && unitId == command.unitId
            && offerId == command.offerId && idempotencyKey == command.idempotencyKey
            && requestFingerprint == command.fingerprint && !status.isEmpty
    }
}

public struct FreeExploreLaunchOrder: Decodable, Equatable {
    public struct Bundle: Decodable, Equatable {
        public struct Owner: Decodable, Equatable {
            public let registrationId: FreeExploreLaunchID
            public let holderMemberId: FreeExploreLaunchID
            public let topicId: FreeExploreLaunchID
        }
        public struct Unit: Decodable, Equatable {
            public let id: FreeExploreLaunchID
            public let registrationId: FreeExploreLaunchID
            public let holderMemberId: FreeExploreLaunchID
            public let chapterId: FreeExploreLaunchID
            public let status: String
            /// MP `unit.validTo`. Absent stays nil so a legacy order still decodes.
            public let validTo: String?
        }
        public struct Chapter: Decodable, Equatable {
            public struct Store: Decodable, Equatable {
                public let offerId: FreeExploreLaunchID
                public let merchantName: String?
                public let perkName: String?
            }
            public let chapterId: FreeExploreLaunchID
            public let name: String?
            public let content: String?
            public let stores: [Store]
            private enum CodingKeys: String, CodingKey { case chapterId, name, content, stores }
            public init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                chapterId = try c.decode(FreeExploreLaunchID.self, forKey: .chapterId)
                name = try c.decodeIfPresent(String.self, forKey: .name)
                content = try c.decodeIfPresent(String.self, forKey: .content)
                stores = try c.decodeIfPresent([Store].self, forKey: .stores) ?? []
            }
        }
        public struct RefundHold: Decodable, Equatable {
            public let state: String
            public let refundId: String?
            public let sourceRegistrationId: String?
            private enum CodingKeys: String, CodingKey { case state, refundId, sourceRegistrationId }
            public init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                state = try c.decode(String.self, forKey: .state)
                refundId = Self.loose(c, .refundId)
                sourceRegistrationId = Self.loose(c, .sourceRegistrationId)
            }
            private static func loose(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
                guard c.contains(key), (try? c.decodeNil(forKey: key)) != true else { return nil }
                if let text = try? c.decode(String.self, forKey: key) {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }
                if let number = try? c.decode(Int64.self, forKey: key) { return String(number) }
                return nil
            }
        }
        public struct ExitCase: Decodable, Equatable {
            public let id: FreeExploreLaunchID
            public let decision: String
            public let unitId: FreeExploreLaunchID?
            public let targetOfferId: FreeExploreLaunchID?
            public let idempotencyKey: String?
        }
        public let order: Owner
        public let units: [Unit]
        public let reservations: [FreeExploreLaunchReservation]
        public let chapters: [Chapter]
        public let refundHold: RefundHold?
        public let exitCases: [ExitCase]
        private enum CodingKeys: String, CodingKey {
            case order, units, reservations, chapters, refundHold, exitCases
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            order = try c.decode(Owner.self, forKey: .order)
            units = try c.decode([Unit].self, forKey: .units)
            reservations = try c.decode([FreeExploreLaunchReservation].self, forKey: .reservations)
            chapters = try c.decodeIfPresent([Chapter].self, forKey: .chapters) ?? []
            refundHold = try c.decodeIfPresent(RefundHold.self, forKey: .refundHold)
            if c.contains(.exitCases) {
                exitCases = try c.decode([ExitCase].self, forKey: .exitCases)
            } else {
                exitCases = []
            }
        }
        /// MP chapter content for a unit. Missing chapter is an empty string.
        public func chapterContent(chapterID: FreeExploreLaunchID) -> String {
            chapters.first { $0.chapterId == chapterID }?.content ?? ""
        }
        /// MP shop name for an offer. A present store with a blank name reads 商家.
        public func shopName(offerID: FreeExploreLaunchID) -> String {
            for chapter in chapters {
                if let store = chapter.stores.first(where: { $0.offerId == offerID }) {
                    let name = store.merchantName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return name.isEmpty ? "商家" : name
                }
            }
            return ""
        }
    }
    public let registrationId: FreeExploreLaunchID
    public let registrationNo: String?
    public let parentOrderNo: String?
    public let paymentStatus: Int?
    public let registrationStatus: Int?
    public let bundle: Bundle?
    func validate(owner: FreeExploreLaunchID, registration: FreeExploreLaunchID) throws {
        guard registrationId == registration else { throw FreeExploreLaunchFailure.malformed }
        // A legacy/no-ledger order is read-only. The existing endpoint enforces its owner.
        guard let bundle else { return }
        guard bundle.order.registrationId == registration, bundle.order.holderMemberId == owner,
              Set(bundle.units.map(\.id)).count == bundle.units.count,
              Set(bundle.reservations.map(\.id)).count == bundle.reservations.count,
              bundle.units.allSatisfy({ $0.registrationId == registration && $0.holderMemberId == owner && !$0.status.isEmpty }),
              bundle.reservations.allSatisfy({ row in
                  row.registrationId == registration && row.holderMemberId == owner && !row.status.isEmpty
                      && bundle.units.contains(where: { $0.id == row.unitId && $0.chapterId == row.chapterId })
              }) else { throw FreeExploreLaunchFailure.malformed }
    }
}

public struct FreeExploreLaunchRefundQuote: Decodable, Equatable {
    public let route: String
    public let amount: FreeExploreLaunchDecimal
    public let totalValue: FreeExploreLaunchDecimal
    public let remainingValue: FreeExploreLaunchDecimal
    public let remainingRatio: FreeExploreLaunchDecimal
    public let afterSalesForMerchantBreach: Bool
    public let reason: String
    public let policyVersion: String
}

public struct FreeExploreLaunchReservationCommand: Codable, Equatable {
    public let registrationId: FreeExploreLaunchID
    public let unitId: FreeExploreLaunchID
    public let offerId: FreeExploreLaunchID
    /// Controller contract: epoch milliseconds, not an ISO date or seconds.
    public let startAt: Int64
    public let idempotencyKey: String
    public init(registrationId: FreeExploreLaunchID, unitId: FreeExploreLaunchID,
                offerId: FreeExploreLaunchID, startAt: Int64, idempotencyKey: String = "fx-" + UUID().uuidString) throws {
        self.registrationId = registrationId; self.unitId = unitId; self.offerId = offerId
        self.startAt = startAt; self.idempotencyKey = idempotencyKey
        try validate()
    }
    func validate() throws {
        guard startAt > 0, (1...64).contains(idempotencyKey.utf8.count),
              idempotencyKey.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw FreeExploreLaunchFailure.invalid
        }
    }
    var fingerprint: String {
        let input = "\(registrationId.text)|\(unitId.text)|\(offerId.text)|\(startAt)"
        return SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    func wireData() throws -> Data {
        try validate(); let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

/// Page state for `subpackageMember/free-explore/index`.
/// Reads the existing catalog, order, and refund-quote contracts. It does not mark a route live,
/// and it does not start a purchase, refund, payout, withdrawal, or virtual-goods write.
public enum FreeExploreBundlePageReady {
    /// Unknown money. A missing, blank, or non-numeric amount is this dash, never `0`.
    public static let unknownMoney = "—"
    /// This page is not on the player-first welcome. `WelcomeView.showsMerchantChoice` stays false.
    public static let includedInPlayerFirstEntry = false
    /// Existing catalog read. Already live; this constant does not change that mark.
    public static let catalogRoute = "/api/free-explore/bundle/catalog"
    /// Existing order read. Already live; this constant does not change that mark.
    public static let orderRoute = "/api/free-explore/bundle/order"
    /// Existing refund-quote read. A quote is not a refund.
    public static let refundQuoteRoute = "/api/free-explore/bundle/order/refund-quote"

    public enum Lane: Equatable {
        case idle, loading, outcomeUnknown, confirmed, staleSession
    }

    public enum Failure: Equatable {
        case load, stale
    }

    /// One finished read. Nil catalog means the sale flag did not arrive; it is not `false`.
    public struct Snapshot: Equatable {
        public var catalog: FreeExploreLaunchCatalog?
        public var order: FreeExploreLaunchOrder?
        public var quote: FreeExploreLaunchRefundQuote?
        /// Raw server price text from the catalog extra. Nil when the server omitted it.
        public var priceText: String?
        /// Raw server paid amount. Nil on the thin order, which has no amount field.
        public var paidAmountText: String?
        public init(catalog: FreeExploreLaunchCatalog? = nil, order: FreeExploreLaunchOrder? = nil,
                    quote: FreeExploreLaunchRefundQuote? = nil, priceText: String? = nil, paidAmountText: String? = nil) {
            self.catalog = catalog
            self.order = order
            self.quote = quote
            self.priceText = priceText
            self.paidAmountText = paidAmountText
        }
    }

    public struct Facts: Equatable {
        public let priceText: String
        public let paidAmountText: String
        public let refundAmountText: String
        public let remainingValueText: String
        public let totalValueText: String
        public let refreshing: Bool
        public let refreshFailed: Bool
        public let catalogEmpty: Bool
        public let legacyOrder: Bool
        /// Nil when no catalog arrived. A missing flag is not stored as `false`.
        public let saleEnabled: Bool?
        public let showsPurchase: Bool
        public let showsUnsubscribe: Bool
        /// True only when a server quote is on screen. The quote does not move money.
        public let showsQuoteOnlyNotice: Bool
    }

    public enum Screen: Equatable {
        case loading
        /// No topic or registration, or a finished read with no catalog items, order, or quote.
        case empty
        case error(Failure)
        /// The original reservation result is not known. Not a price of 0.
        case unknown
        case ready(Facts)
    }

    /// The server's own decimal text, or an em dash. A literal `0` stays `"0"`. A literal `"0.00"` stays `"0.00"`.
    public static func moneyText(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty,
              trimmed.range(of: "^(0|[1-9][0-9]*)(\\.[0-9]+)?$", options: .regularExpression) != nil else {
            return unknownMoney
        }
        return trimmed
    }

    /// The decoded server decimal, or an em dash. This does not reformat or recompute the amount.
    public static func moneyText(_ value: FreeExploreLaunchDecimal?) -> String {
        guard let value else { return unknownMoney }
        return moneyText(value.text)
    }

    /// Hidden on the player-first entry and when the existing reads are not offered.
    /// A nil base offers nothing. This does not mark a route live.
    public static func showsPage(baseURL: URL?, playerFirstEntry: Bool) -> Bool {
        guard includedInPlayerFirstEntry == false, playerFirstEntry == false else { return false }
        return ChinaReviewedRouteCapability.offersFeature(catalogRoute, baseURL: baseURL)
            && ChinaReviewedRouteCapability.offersFeature(orderRoute, baseURL: baseURL)
            && ChinaReviewedRouteCapability.offersFeature(refundQuoteRoute, baseURL: baseURL)
    }

    /// Always false. A server `saleEnabled` flag does not start payment or virtual goods.
    public static func showsPurchase(baseURL: URL?, playerFirstEntry: Bool, saleEnabled: Bool) -> Bool {
        _ = (baseURL, playerFirstEntry, saleEnabled, ReleaseMoneyWriteSwitch.paymentEnabled, ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        return false
    }

    /// Always false. A refund quote does not start a refund, payout, or withdrawal.
    public static func showsUnsubscribe(baseURL: URL?, playerFirstEntry: Bool) -> Bool {
        _ = (baseURL, playerFirstEntry, ReleaseMoneyWriteSwitch.payoutEnabled, ReleaseMoneyWriteSwitch.withdrawalEnabled)
        return false
    }

    /// Classify one read of the existing contracts.
    /// `linkMissing` is the empty link (no topic and no registration). A later failure keeps the previous record
    /// instead of replacing its amounts with 0. An unknown reservation result stays `.unknown`.
    public static func screen(state: Lane, failed: Bool, linkMissing: Bool, kept: Snapshot?) -> Screen {
        switch state {
        case .staleSession:
            return .error(.stale)
        case .outcomeUnknown:
            return .unknown
        case .loading:
            if linkMissing { return .empty }
            guard let kept, !isEmpty(kept) else { return .loading }
            return ready(kept, refreshing: true, refreshFailed: false)
        case .idle, .confirmed:
            if linkMissing { return .empty }
            if failed {
                guard let kept, !isEmpty(kept) else { return .error(.load) }
                return ready(kept, refreshing: false, refreshFailed: true)
            }
            guard let kept else { return .unknown }
            if isEmpty(kept) { return .empty }
            return ready(kept, refreshing: false, refreshFailed: false)
        }
    }

    private static func isEmpty(_ snapshot: Snapshot) -> Bool {
        let hasItems = snapshot.catalog?.items.isEmpty == false
        return !hasItems && snapshot.order == nil && snapshot.quote == nil
            && moneyText(snapshot.priceText) == unknownMoney && moneyText(snapshot.paidAmountText) == unknownMoney
    }

    private static func ready(_ snapshot: Snapshot, refreshing: Bool, refreshFailed: Bool) -> Screen {
        .ready(Facts(
            priceText: moneyText(snapshot.priceText),
            paidAmountText: moneyText(snapshot.paidAmountText),
            refundAmountText: moneyText(snapshot.quote?.amount),
            remainingValueText: moneyText(snapshot.quote?.remainingValue),
            totalValueText: moneyText(snapshot.quote?.totalValue),
            refreshing: refreshing,
            refreshFailed: refreshFailed,
            catalogEmpty: snapshot.catalog?.items.isEmpty ?? true,
            legacyOrder: snapshot.order != nil && snapshot.order?.bundle == nil,
            saleEnabled: snapshot.catalog?.saleEnabled,
            showsPurchase: false,
            showsUnsubscribe: false,
            showsQuoteOnlyNotice: snapshot.quote != nil))
    }
}
