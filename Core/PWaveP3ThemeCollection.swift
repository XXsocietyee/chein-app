import Foundation

/// P3 public catalog. Ordinary form fields only; this reader does not send a JSON body.
/// Sample chapters are the names the server returned. A list shorter than three stays that long.
/// `priceState == UNKNOWN` is an em dash and does not fall back to another price.
/// Null group or school eligibility is undeclared. Listing a work does not mark it field-verified.
/// There is no arrival-reminder success. Social proof without a named source stays hidden.

public struct PWaveCatalogCity: Equatable, Sendable {
    public let cityCode: String?
    public let cityName: String?

    public init(cityCode: String?, cityName: String?) {
        self.cityCode = cityCode
        self.cityName = cityName
    }
}

public struct PWaveCatalogCard: Equatable, Sendable {
    public let id: String?
    public let canonicalPath: String?
    public let cityCode: String?
    public let cityName: String?
    public let name: String?
    public let subtitle: String?
    public let summary: String?
    public let imageURL: String?
    public let productType: String?
    public let chapterNames: [String]?
    public let priceFrom: PWaveNumberFact
    public let priceState: String?
    public let priceUnit: String?
    public let saleState: String?
    public let freeSelfPlay: Bool?
    public let groupEligible: Bool?
    public let schoolEligible: Bool?
    public let requestedLocale: String?
    public let actualLocale: String?
    public let translationState: String?
    public let revisionState: String?

    public var sampleCountText: String { PWaveCountText.text(chapterNames?.count) }
    public var samplesPadded: Bool { false }
    public var priceText: String {
        if priceState == "UNKNOWN" { return PWaveNumberFact.unknownDisplay }
        return priceFrom.displayText
    }
    public var groupEligibilityDeclared: Bool { groupEligible != nil }
    public var schoolEligibilityDeclared: Bool { schoolEligible != nil }
    public var presentsAsDoesNotHost: Bool { false }
    public var fieldVerified: Bool { false }
    public var arrivalReminderSucceeded: Bool { false }
    public var socialProofHidden: Bool { true }
    public var primaryTargetID: String? { id }
    public var opensEmptySignup: Bool { false }
    public var localeFellBack: Bool? {
        guard let requestedLocale, let actualLocale else { return nil }
        return requestedLocale != actualLocale
    }

    public init(id: String?, canonicalPath: String?, cityCode: String?, cityName: String?, name: String?,
                subtitle: String?, summary: String?, imageURL: String?, productType: String?,
                chapterNames: [String]?, priceFrom: PWaveNumberFact, priceState: String?, priceUnit: String?,
                saleState: String?, freeSelfPlay: Bool?, groupEligible: Bool?, schoolEligible: Bool?,
                requestedLocale: String?, actualLocale: String?, translationState: String?, revisionState: String?) {
        self.id = id
        self.canonicalPath = canonicalPath
        self.cityCode = cityCode
        self.cityName = cityName
        self.name = name
        self.subtitle = subtitle
        self.summary = summary
        self.imageURL = imageURL
        self.productType = productType
        self.chapterNames = chapterNames
        self.priceFrom = priceFrom
        self.priceState = priceState
        self.priceUnit = priceUnit
        self.saleState = saleState
        self.freeSelfPlay = freeSelfPlay
        self.groupEligible = groupEligible
        self.schoolEligible = schoolEligible
        self.requestedLocale = requestedLocale
        self.actualLocale = actualLocale
        self.translationState = translationState
        self.revisionState = revisionState
    }
}

public struct PWaveThemeCollectionFact: Equatable, Sendable {
    public let cards: [PWaveCatalogCard]
    public let cities: [PWaveCatalogCity]
    public var leaksPaidBody: Bool { false }
    public var insertsDelistedSamples: Bool { false }
    public var arrivalReminderSucceeded: Bool { false }

    public init(cards: [PWaveCatalogCard], cities: [PWaveCatalogCity]) {
        self.cards = cards
        self.cities = cities
    }
}

public enum PWaveCatalogPath: String, Equatable, Sendable {
    case cityList = "api/public-catalog/city/list"
    case list = "api/public-catalog/list"
    case map = "api/public-catalog/map"
    case ids = "api/public-catalog/ids"
    case info = "api/public-catalog/info"
    case filters = "api/public-catalog/filters"
}

public enum PWaveThemeCollection {
    public static let fields: Set<String> = [
        "city_code", "locale", "keyword", "product_type", "delivery_mode", "group_eligible",
        "school_eligible", "audience_age", "min_minutes", "max_minutes", "sort", "id", "ids"
    ]

    public static func decode(data: Data, status: Int, supported: Set<String>) -> PWavePresentation<PWaveThemeCollectionFact> {
        PWaveServerCapability.presentation(data: data, status: status, supported: supported) { _, payload in
            fact(payload)
        }
    }

    static func fact(_ payload: PlayWireValue) -> PWaveServerFact<PWaveThemeCollectionFact> {
        switch payload {
        case .array(let items):
            if items.isEmpty { return .empty }
            return collected(items)
        case .object(_):
            return collected([payload])
        default:
            return .unknown
        }
    }

    private static func collected(_ items: [PlayWireValue]) -> PWaveServerFact<PWaveThemeCollectionFact> {
        var cards: [PWaveCatalogCard] = []
        var cities: [PWaveCatalogCity] = []
        for item in items {
            guard let object = item.object else { return .unknown }
            if let card = card(object) {
                cards.append(card)
            } else if let city = city(object) {
                cities.append(city)
            } else {
                return .unknown
            }
        }
        if cards.isEmpty && cities.isEmpty { return .unknown }
        return .ready(PWaveThemeCollectionFact(cards: cards, cities: cities))
    }

    private static func card(_ object: [String: PlayWireValue]) -> PWaveCatalogCard? {
        let id = identifier(object["id"])
        let name = PWaveEnvelope.text(object["name"] ?? .null)
        let path = PWaveEnvelope.text(object["canonicalPath"] ?? .null)
        guard id != nil || name != nil || path != nil else { return nil }
        let names = chapterNames(object)
        let priceState = PWaveEnvelope.text(object["priceState"] ?? .null)
        let price = priceState == "UNKNOWN" ? PWaveNumberFact.unknown : number(object, "priceFrom")
        return PWaveCatalogCard(
            id: id, canonicalPath: path,
            cityCode: PWaveEnvelope.text(object["cityCode"] ?? .null),
            cityName: PWaveEnvelope.text(object["cityName"] ?? .null),
            name: name, subtitle: PWaveEnvelope.text(object["subtitle"] ?? .null),
            summary: PWaveEnvelope.text(object["summary"] ?? .null),
            imageURL: PWaveEnvelope.text(object["imgUrl"] ?? .null),
            productType: PWaveEnvelope.text(object["productType"] ?? .null),
            chapterNames: names,
            priceFrom: price,
            priceState: priceState,
            priceUnit: PWaveEnvelope.text(object["priceUnit"] ?? .null),
            saleState: PWaveEnvelope.text(object["saleState"] ?? .null),
            freeSelfPlay: object["freeSelfPlay"]?.bool,
            groupEligible: object["groupEligible"]?.bool,
            schoolEligible: object["schoolEligible"]?.bool,
            requestedLocale: PWaveEnvelope.text(object["requestedLocale"] ?? .null),
            actualLocale: PWaveEnvelope.text(object["actualLocale"] ?? .null),
            translationState: PWaveEnvelope.text(object["translationState"] ?? .null),
            revisionState: PWaveEnvelope.text(object["revision"]?.object?["state"] ?? .null))
    }

    private static func city(_ object: [String: PlayWireValue]) -> PWaveCatalogCity? {
        let code = PWaveEnvelope.text(object["cityCode"] ?? .null)
        let name = PWaveEnvelope.text(object["cityName"] ?? .null)
        guard code != nil || name != nil else { return nil }
        return PWaveCatalogCity(cityCode: code, cityName: name)
    }

    private static func chapterNames(_ object: [String: PlayWireValue]) -> [String]? {
        guard let value = object["chapterNames"] else { return nil }
        guard case .array(let items) = value else { return nil }
        var names: [String] = []
        for item in items {
            guard let text = PWaveEnvelope.text(item) else { return nil }
            names.append(text)
        }
        return names
    }

    private static func identifier(_ value: PlayWireValue?) -> String? {
        guard let value else { return nil }
        switch PWaveIdentifierFact.parse(value) {
        case .text(let raw): return raw
        case .integer(let number): return String(number)
        case .unknown: return nil
        }
    }

    private static func number(_ object: [String: PlayWireValue], _ key: String) -> PWaveNumberFact {
        guard let value = object[key] else { return .unknown }
        return PWaveNumberFact.parse(value)
    }
}
