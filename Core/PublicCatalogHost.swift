import Foundation

/// Read-only public catalog. List, filters, and info only.
/// Money stays off: quote, order, and pay throw and send nothing.
/// An unknown price is an em dash, never 0. A literal JSON 0 stays 0.
public struct PublicCatalogLink: Equatable, Hashable, Sendable {
    public enum Screen: String, Equatable, Hashable, Sendable {
        case list
        case filters
        case info
    }

    public static let readablePaths: [PWaveCatalogPath] = [.list, .filters, .info]
    /// Query keys that would start a charge. They are not catalog fields.
    public static let refusedMoneyKeys: Set<String> = ["pay", "quote", "order", "price", "amount", "buy", "payment"]

    public let screen: Screen
    public let fields: [String: String]

    public var catalogPath: PWaveCatalogPath {
        switch screen {
        case .list: return .list
        case .filters: return .filters
        case .info: return .info
        }
    }

    public init?(screen: Screen, fields: [String: String]) {
        guard Self.accepts(fields), screen != .info || fields["id"] != nil else { return nil }
        self.screen = screen
        self.fields = fields
    }

    /// Universal-link path. `/catalog` and `/catalog/list` are the list.
    /// Filters and info are the other two readable paths. Map, ids, and city list are not links.
    public static func parse(path: String, items: [URLQueryItem]) -> PublicCatalogLink? {
        let parts = path.split(separator: "/").map(String.init)
        guard path == "/" + parts.joined(separator: "/") else { return nil }
        let screen: Screen
        switch parts {
        case ["catalog"], ["catalog", "list"]: screen = .list
        case ["catalog", "filters"]: screen = .filters
        case ["catalog", "info"]: screen = .info
        default: return nil
        }
        guard Set(items.map(\.name)).count == items.count else { return nil }
        var fields: [String: String] = [:]
        for item in items {
            guard let value = item.value else { return nil }
            guard !refusedMoneyKeys.contains(item.name) else { return nil }
            guard PWaveThemeCollection.fields.contains(item.name), acceptable(value) else { return nil }
            fields[item.name] = value
        }
        return PublicCatalogLink(screen: screen, fields: fields)
    }

    private static func accepts(_ fields: [String: String]) -> Bool {
        fields.keys.allSatisfy { PWaveThemeCollection.fields.contains($0) && !refusedMoneyKeys.contains($0) }
            && fields.values.allSatisfy(acceptable)
    }

    private static func acceptable(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 256
            && value.unicodeScalars.allSatisfy { $0.value >= 32 && $0.value != 127 }
    }
}

public enum PublicCatalogPrice {
    /// `priceState == UNKNOWN`, a missing amount, a numeric string, or any other unknown fact is an em dash.
    /// A literal 0 is `"0"` only when the price state is not UNKNOWN.
    public static func text(state: String?, amount: PWaveNumberFact) -> String {
        if state == "UNKNOWN" { return PWaveNumberFact.unknownDisplay }
        return amount.displayText
    }
}

public struct PublicCatalogRow: Equatable, Sendable {
    public let title: String
    public let price: String?
    public let unit: String?
    public let summary: String?

    public init(title: String, price: String?, unit: String?, summary: String?) {
        self.title = title
        self.price = price
        self.unit = unit
        self.summary = summary
    }
}

public enum PublicCatalogScreenState: Equatable, Sendable {
    case unavailable
    case loading
    case empty
    case failed
    case unrecognized
    case ready([PublicCatalogRow])
}

public enum PublicCatalogScreen {
    public static func state(_ presentation: PWavePresentation<PWaveThemeCollectionFact>) -> PublicCatalogScreenState {
        guard !presentation.hidden, let phase = presentation.phase else { return .unavailable }
        switch phase {
        case .loading: return .loading
        case .empty: return .empty
        case .error: return .failed
        case .unknown: return .unrecognized
        case .ready(let fact):
            let rows = rows(fact)
            return rows.isEmpty ? .empty : .ready(rows)
        }
    }

    public static func rows(_ fact: PWaveThemeCollectionFact) -> [PublicCatalogRow] {
        let cards = fact.cards.map { card -> PublicCatalogRow in
            let price = PublicCatalogPrice.text(state: card.priceState, amount: card.priceFrom)
            let known = price != PWaveNumberFact.unknownDisplay
            let unit = known ? nonempty(card.priceUnit) : nil
            return PublicCatalogRow(title: nonempty(card.name) ?? PWaveNumberFact.unknownDisplay,
                                    price: price, unit: unit, summary: nonempty(card.summary))
        }
        let cities = fact.cities.map { city in
            PublicCatalogRow(title: nonempty(city.cityName) ?? nonempty(city.cityCode) ?? PWaveNumberFact.unknownDisplay,
                             price: nil, unit: nil, summary: nil)
        }
        return cards + cities
    }

    private static func nonempty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}

/// Host for the three public-catalog reads. The reader is injected.
/// `moneyEnabled` follows the payment host switch. Quote, order, and pay still throw.
public struct PublicCatalogHost {
    public static var moneyEnabled: Bool { ReleaseMoneyWriteSwitch.paymentEnabled }
    private let reader: PWaveReader

    public init(reader: PWaveReader) {
        self.reader = reader
    }

    public func load(_ link: PublicCatalogLink, token: String?, scope: PWaveSessionScope,
                     currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveThemeCollectionFact> {
        guard PublicCatalogLink.readablePaths.contains(link.catalogPath) else { throw PWaveRefusal.invalidRequest }
        return try await reader.themeCatalog(link.catalogPath, fields: link.fields, token: token,
                                             scope: scope, currentScope: currentScope)
    }

    public func quote(requestID: String, token: String) throws -> Never {
        _ = (requestID, token, reader)
        throw PWaveRefusal.writesNotAvailable
    }

    public func order(requestID: String, token: String) throws -> Never {
        _ = (requestID, token, reader)
        throw PWaveRefusal.writesNotAvailable
    }

    public func pay(orderNo: String, requestID: String, token: String) throws -> Never {
        _ = (orderNo, requestID, token, reader)
        throw PWaveRefusal.writesNotAvailable
    }
}
