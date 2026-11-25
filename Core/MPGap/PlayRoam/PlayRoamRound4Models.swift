import Foundation

/// Round-4 Core models for `play-roam` Gemini items:
/// `JSETTLE-r7-1` (完局优惠卡), `ROAM-13` (City strip), `B3D-1` (Identity pin 3D), `OCARDS-2` (Pile item).

// MARK: - JSETTLE-r7-1: 完局优惠卡 (ports `subpackageJourney/utils/finish-offer.js`)

public enum JourneyFinishOfferKind: String, Equatable, Sendable {
    case pass
    case product
}

public struct JourneyFinishOffer: Equatable, Sendable {
    public let kind: JourneyFinishOfferKind
    public let id: String
    public let name: String
    public let priceText: String

    public init(kind: JourneyFinishOfferKind, id: String, name: String, priceText: String) {
        self.kind = kind
        self.id = id
        self.name = name
        self.priceText = priceText
    }

    /// `finish_offer_shown` / `finish_offer_click` analytics payload (no name/price per MP).
    public var analyticsProperties: [String: String] {
        var props = ["offerKind": kind.rawValue]
        if kind == .pass { props["planCode"] = id }
        return props
    }

    /// `finish-offer.js` `trackPayload`. `topicId` is a number when it is an id.
    /// Pass `bizType` is `platform_pass` and `bizID` stays nil. Product `bizType` is `marketing_product`
    /// and `bizID` is the product id. Name and price are not included.
    public func trackPayload(topicID: String?) -> JourneyFinishOfferAnalytics {
        var properties: [String: PlayWireValue] = ["offerKind": .string(kind.rawValue)]
        if kind == .pass, !id.isEmpty { properties["planCode"] = .string(id) }
        if let topicID, JourneyLoopSource.isID(topicID), let number = Int(topicID), number <= 9_007_199_254_740_991 {
            properties["topicId"] = .integer(Int64(number))
        }
        let bizType = kind == .pass ? "platform_pass" : "marketing_product"
        let bizID: Int? = {
            guard kind == .product, JourneyLoopSource.isID(id), let number = Int(id), number <= 9_007_199_254_740_991 else { return nil }
            return number
        }()
        return JourneyFinishOfferAnalytics(bizType: bizType, bizID: bizID, properties: properties)
    }
}

public struct JourneyFinishOfferAnalytics: Equatable, Sendable {
    public static let shown = "finish_offer_shown"
    public static let click = "finish_offer_click"
    public let bizType: String
    public let bizID: Int?
    public let properties: [String: PlayWireValue]
    public init(bizType: String, bizID: Int?, properties: [String: PlayWireValue]) {
        self.bizType = bizType
        self.bizID = bizID
        self.properties = properties
    }
}

public struct JourneyFinishOfferPassInput: Equatable, Sendable {
    public let enabled: Bool
    public let holdingActive: Bool
    public let libraryCount: Int
    public let monthPlanTitle: String?
    public let monthPlanPriceFen: Int?

    public init(
        enabled: Bool,
        holdingActive: Bool,
        libraryCount: Int,
        monthPlanTitle: String?,
        monthPlanPriceFen: Int?
    ) {
        self.enabled = enabled
        self.holdingActive = holdingActive
        self.libraryCount = libraryCount
        self.monthPlanTitle = monthPlanTitle
        self.monthPlanPriceFen = monthPlanPriceFen
    }
}

public struct JourneyFinishOfferProductInput: Equatable, Sendable {
    public let productID: Int
    public let productKind: Int
    public let productName: String
    public let cashPrice: Double?
    public let pointsPrice: Int?
    public let coveredTopicIDs: [Int]

    public init(
        productID: Int,
        productKind: Int,
        productName: String,
        cashPrice: Double?,
        pointsPrice: Int?,
        coveredTopicIDs: [Int]
    ) {
        self.productID = productID
        self.productKind = productKind
        self.productName = productName
        self.cashPrice = cashPrice
        self.pointsPrice = pointsPrice
        self.coveredTopicIDs = coveredTopicIDs
    }
}

public enum JourneyFinishOfferResolver {
    public static func resolve(
        isMerchantView: Bool,
        pass: JourneyFinishOfferPassInput?,
        products: [JourneyFinishOfferProductInput],
        currentTopicID: Int?
    ) -> JourneyFinishOffer? {
        guard !isMerchantView else { return nil }
        if let pass, pass.holdingActive { return nil }

        if let pass,
           pass.enabled,
           pass.libraryCount >= 2,
           let title = pass.monthPlanTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
           let priceFen = pass.monthPlanPriceFen, priceFen > 0 {
            let yuan = Double(priceFen) / 100.0
            let priceText = String(format: "¥%.2f", yuan)
            return JourneyFinishOffer(kind: .pass, id: "MONTH", name: title, priceText: priceText)
        }

        for p in products {
            guard p.productID > 0, (p.productKind == 2 || p.productKind == 3) else { continue }
            let name = p.productName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let coversOther = p.coveredTopicIDs.contains { $0 > 0 && $0 != currentTopicID }
            guard coversOther else { continue }
            let priceText: String
            if let cash = p.cashPrice, cash > 0 {
                priceText = String(format: "¥%.2f", cash)
            } else if let pts = p.pointsPrice, pts > 0 {
                priceText = "\(pts) 积分"
            } else {
                continue
            }
            return JourneyFinishOffer(kind: .product, id: String(p.productID), name: name, priceText: priceText)
        }

        return nil
    }
}

// MARK: - ROAM-13: City Strip Model

public struct RoamCityStripSummary: Equatable, Sendable {
    public let cityName: String
    public let activeEventsCount: Int
    public let liveTeamsCount: Int

    public init(cityName: String, activeEventsCount: Int, liveTeamsCount: Int) {
        self.cityName = cityName
        self.activeEventsCount = activeEventsCount
        self.liveTeamsCount = liveTeamsCount
    }
}

// MARK: - B3D-1: Identity (`pin`) Badge 3D Parameters

public struct IdentityPinBadge3DParameters: Equatable, Sendable {
    public let badgeCode: String
    public let glyphName: String
    public let rarityTier: Int
    public let hintKey: String

    public init(badgeCode: String, categoryTrack: Int) {
        self.badgeCode = badgeCode
        self.glyphName = badgeCode.isEmpty ? "pin.circle.fill" : "medal.fill"
        self.rarityTier = max(1, categoryTrack)
        self.hintKey = "objects.badge3d.hint.pin"
    }
}

// MARK: - OCARDS-2: Object Card Pile Item

public struct ObjectCardPileItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let thumbnailURL: String?

    public init(id: String, title: String, thumbnailURL: String?) {
        self.id = id
        self.title = title
        self.thumbnailURL = thumbnailURL
    }
}
