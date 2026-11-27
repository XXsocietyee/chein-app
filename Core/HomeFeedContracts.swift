import Foundation

/// Namespaced identity prevents an activity and a route sharing an integer from colliding.
public enum HomeFeedDestination: Hashable { case activity(Int), topic(Int) }
public enum HomeFeedKind: String, CaseIterable, Hashable { case topics, activities }
public enum HomeFeedSection: String, CaseIterable, Hashable { case recommended, nearby, upcoming }
public struct HomeFeedQuery: Hashable {
    public var kind: HomeFeedKind
    public var keyword: String
    public var categoryID: Int?
    public var pageSize: Int
    public init(kind: HomeFeedKind = .topics, keyword: String = "", categoryID: Int? = nil, pageSize: Int = 20) {
        self.kind = kind; self.keyword = keyword; self.categoryID = categoryID; self.pageSize = pageSize
    }
}
public enum HomeFeedItem: Equatable, Identifiable {
    case activity(ActivitySummary), topic(TopicSummary)
    public var id: HomeFeedDestination {
        switch self { case .activity(let a): return .activity(a.id); case .topic(let t): return .topic(t.id) }
    }
    public var name: String { switch self { case .activity(let a): return a.name; case .topic(let t): return t.name } }
    public var imageURL: String? { switch self { case .activity(let a): return a.imageURL; case .topic(let t): return t.imageURL } }
    public var introduction: String? { switch self { case .activity(let a): return a.description; case .topic(let t): return t.introduction } }
    public var amount: Decimal? { switch self { case .activity(let a): return a.minimumAmount; case .topic(let t): return t.minimumAmount } }
    /// These verified list contracts provide no currency. Never derive it from device locale.
    public var currencyCode: String? { nil }
    public var startDate: String? { switch self { case .activity(let a): return a.startDate; case .topic(let t): return t.startDate } }
    public var categoryNames: [String] {
        switch self { case .activity(let a): return a.categoryNames; case .topic(let t): return t.categoryNames }
    }
    /// First two category names, matching the feed card tags.
    public var feedTags: [String] { Array(categoryNames.prefix(2)) }
    public var productType: Int? {
        switch self { case .activity(let a): return a.productType; case .topic(let t): return t.productType }
    }
    /// MP 附近活动 distance (metres). Topics carry none.
    public var distanceMeters: Double? { if case .activity(let a) = self { return a.distanceMeters }; return nil }
    /// MP 编辑精选 「N 人已报名」 count. Activities carry none on these lists.
    public var signupCount: Int? { if case .topic(let t) = self { return t.signupCount }; return nil }
    public var clubLabel: String? {
        switch self { case .activity(let a): return a.clubLabel; case .topic(let t): return t.clubLabel }
    }
    public var statusLabel: String? {
        switch self { case .activity(let a): return a.statusLabel; case .topic(let t): return t.statusLabel }
    }
    /// Category names already on the topic-list row (at most the two feed tags). Blank names are dropped.
    /// MP 编辑精选 shows only the first category (`item.tags[0]`, pages/index/index.wxml:113).
    public var featuredCategoryTags: [String] {
        let tags = feedTags.compactMap { raw -> String? in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return Array(tags.prefix(1))
    }
    /// Server status text from the same row. A missing or blank label stays nil.
    public var featuredStatusText: String? {
        guard let raw = statusLabel else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    /// Club or merchant name from the same row. A category is not treated as a club.
    public var featuredClubText: String? {
        let raw: String?
        switch self {
        case .activity(let activity): raw = activity.clubName ?? activity.merchantName
        case .topic(let topic): raw = topic.clubName ?? topic.merchantName
        }
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    public var place: String? {
        switch self { case .activity(let a): return homeFeedNonempty(a.addressName) ?? homeFeedNonempty(a.address)
        case .topic(let t): return homeFeedNonempty(t.addressName) }
    }
    public var isBeta: Bool { if case .topic(let t) = self { return t.betaFlag == 1 }; return false }
    public func isLive(at now: Date, sourceTimeZone: TimeZone? = nil) -> Bool {
        guard case .activity = self, let start = HomeFeedDate.parse(startDate, sourceTimeZone: sourceTimeZone) else { return false }
        return start <= now
    }
}
public struct HomeFeedPage: Equatable {
    public let items: [HomeFeedItem]
    public let number: Int
    public let size: Int
    public var hasMore: Bool { items.count >= size }
    public init(items: [HomeFeedItem], number: Int, size: Int) { self.items = items; self.number = number; self.size = size }
}
public struct HomeFeedPagination {
    public private(set) var items: [HomeFeedItem] = []
    public private(set) var nextPage = 1
    public private(set) var hasMore = true
    public init() {}
    public mutating func accept(_ page: HomeFeedPage) throws {
        guard page.number == nextPage, page.size > 0 else { throw APIError.invalidRequest }
        var seen = Set(items.map(\.id))
        items += page.items.filter { seen.insert($0.id).inserted }
        hasMore = page.hasMore && nextPage < Int.max
        if nextPage < Int.max { nextPage += 1 }
    }
}
private func homeFeedNonempty(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return value
}

/// Loading, empty, error, and unknown readiness for the home discovery feed.
/// Unknown is the em dash. A missing number is never shown as 0.
public enum HomeFeedSurfaceState: Equatable, Sendable {
    case loading
    case empty
    case error
    case unknown
    case ready

    public static let unknownText = "—"

    public static func slot(failed: Bool, loaded: Bool, loading: Bool, isEmpty: Bool) -> HomeFeedSurfaceState {
        if failed { return .error }
        if !loaded || loading { return .loading }
        if isEmpty { return .empty }
        return .ready
    }
}

/// A decoded zero stays zero. Absence stays unknown and renders as an em dash.
public enum HomeFeedAmountState: Equatable, Sendable {
    case unknown
    case known(Decimal)

    public init(_ value: Decimal?) {
        if let value { self = .known(value) } else { self = .unknown }
    }

    public var text: String {
        switch self {
        case .unknown: return HomeFeedSurfaceState.unknownText
        case .known(let value): return HomeFeedAmountState.render(value)
        }
    }

    static func render(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        if number == .notANumber { return HomeFeedSurfaceState.unknownText }
        let raw = number.stringValue
        if raw.isEmpty || raw == "NaN" { return HomeFeedSurfaceState.unknownText }
        return raw
    }
}

/// Blank or missing copy is unknown. A non-empty server string is kept as written.
public enum HomeFeedTextState: Equatable, Sendable {
    case unknown
    case known(String)

    public init(optional raw: String?) {
        guard let trimmed = homeFeedNonempty(raw) else { self = .unknown; return }
        self = .known(trimmed)
    }

    public var text: String {
        switch self {
        case .unknown: return HomeFeedSurfaceState.unknownText
        case .known(let value): return value
        }
    }
}

public extension HomeFeedItem {
    var amountState: HomeFeedAmountState { HomeFeedAmountState(amount) }
    var placeState: HomeFeedTextState { HomeFeedTextState(optional: place) }
    /// Missing dates are unknown. An unparsed non-empty value stays the server text, not a guessed clock.
    var dateState: HomeFeedTextState { HomeFeedTextState(optional: startDate) }
}

/// Matches the retained home_activity_live.dart wire contract, including strict calendar checks.
public enum HomeFeedDate {
    public static func display(_ raw: String?, locale: Locale, sourceTimeZone: TimeZone? = nil,
                               displayTimeZone: TimeZone = .current) -> String {
        guard let date = parse(raw, sourceTimeZone: sourceTimeZone) else { return homeFeedNonempty(raw) ?? "—" }
        var style = Date.FormatStyle.dateTime.year().month(.abbreviated).day().hour().minute().locale(locale)
        style.timeZone = displayTimeZone
        return date.formatted(style)
    }

    public static func parse(_ raw: String?, sourceTimeZone: TimeZone? = nil) -> Date? {
        guard let raw else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.range(of: #"^(\d{10}|\d{13})$"#, options: .regularExpression) != nil,
           let number = Double(text), number > 0 {
            return Date(timeIntervalSince1970: text.count == 13 ? number / 1000 : number)
        }
        let pattern = #"^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2})(\.\d{1,9})?)?)?([zZ]|[+-]\d{2}:?\d{2})?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        func group(_ i: Int) -> String? { Range(match.range(at: i), in: text).map { String(text[$0]) } }
        let values = (1...6).map { Int(group($0) ?? "0") ?? 0 }
        var offset: Int?
        if let zone = group(8) {
            guard group(4) != nil else { return nil }
            if zone.lowercased() == "z" { offset = 0 }
            else {
                let digits = zone.dropFirst().replacingOccurrences(of: ":", with: "")
                guard let hours = Int(digits.prefix(2)), let minutes = Int(digits.suffix(2)), hours <= 23, minutes <= 59 else { return nil }
                offset = (hours * 3600 + minutes * 60) * (zone.first == "-" ? -1 : 1)
            }
        }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: values[0], month: values[1], day: values[2], hour: values[3], minute: values[4], second: values[5])
        guard let date = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard check.year == values[0], check.month == values[1], check.day == values[2], check.hour == values[3], check.minute == values[4], check.second == values[5] else { return nil }
        if let offset { return date.addingTimeInterval(-Double(offset) + (Double(group(7) ?? "0") ?? 0)) }
        guard let sourceTimeZone else { return nil }
        calendar.timeZone = sourceTimeZone
        guard let localDate = calendar.date(from: components) else { return nil }
        let localCheck = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: localDate)
        guard localCheck.year == values[0], localCheck.month == values[1], localCheck.day == values[2], localCheck.hour == values[3], localCheck.minute == values[4], localCheck.second == values[5] else { return nil }
        return localDate
    }
}
