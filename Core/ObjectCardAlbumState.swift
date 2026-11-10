import Foundation

/// Count from the existing `POST /api/object-card/list` body.
/// A missing, null, or non-numeric `total` is unknown and displays an em dash.
/// A literal zero stays `"0"`. Numeric strings are not parsed into a guessed count.
public enum ObjectCardTotalFact: Equatable, Sendable {
    public static let unknownText = "—"
    case unknown
    case known(Int)

    public var text: String {
        switch self {
        case .unknown: return Self.unknownText
        case .known(let value): return String(value)
        }
    }
}

/// The list call returned cards but withheld a usable total. Not a zero count.
public struct ObjectCardTotalUnknown: Error, Equatable {
    public let cards: [ObjectCard]
    public init(cards: [ObjectCard]) { self.cards = cards }
}

/// `data` object of a 200 list envelope. Negative and fractional totals stay malformed.
public struct ObjectCardListedData: Decodable, Equatable {
    public let cards: [ObjectCard]
    public let total: ObjectCardTotalFact

    private enum CodingKeys: String, CodingKey { case list, total }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cards = try container.decode([ObjectCard].self, forKey: .list)
        if try container.contains(.total) == false || container.decodeNil(forKey: .total) {
            total = .unknown
            return
        }
        if let value = try? container.decode(Int.self, forKey: .total) {
            guard value >= 0 else { throw APIError.malformedResponse }
            total = .known(value)
            return
        }
        if (try? container.decode(Double.self, forKey: .total)) != nil {
            throw APIError.malformedResponse
        }
        total = .unknown
    }
}

public enum ObjectCardAlbumPhase: Equatable, Sendable {
    case loading
    case empty
    case error
    case unknown
    case ready
}
