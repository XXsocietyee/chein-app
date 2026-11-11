import Foundation
import CoreFoundation

/// Read-only projection of ViewCouponHistory. Redemption credentials (couponCode, qrcodeUrl)
/// are deliberately not decoded or retained. These records are never persisted or logged.
/// The list projection may include a public shop. A missing coordinate stays unknown, never 0.
public struct AccountCollectionCoupon: Decodable, Equatable, Identifiable {
    public static let unknownCountText = "—"
    public let id: Int
    public let couponID: Int?
    public let useStatus: Int?
    public let name: String?
    public let description: String?
    public let note: String?
    public let receivedTime: String?
    public let usedTime: String?
    public let startTime: String?
    public let endTime: String?
    public let shopName: String?
    public let shopAddress: String?
    public let shopLatitude: Double?
    public let shopLongitude: Double?
    /// Both coordinates are present, including a literal 0. This does not open a map or a route.
    public var hasShopNavigation: Bool { shopLatitude != nil && shopLongitude != nil }
    /// A missing number is an em dash. A literal 0 stays 0. Whole numbers stay whole.
    public static func countText(_ value: Double?) -> String {
        guard let value, value.isFinite else { return unknownCountText }
        if value == 0 { return "0" }
        if value.rounded() == value, value <= Double(Int.max), value >= Double(Int.min) {
            return String(Int(value))
        }
        return String(value)
    }
    public var shopLatitudeText: String { Self.countText(shopLatitude) }
    public var shopLongitudeText: String { Self.countText(shopLongitude) }
    public var displayDescription: String? {
        if let description, !description.isEmpty { return description }
        return note
    }
    public var status: AccountCollectionCouponStatus {
        switch useStatus {
        case 0: return .unused
        case 1: return .used
        case 2: return .expired
        case 3: return .invalid
        default: return .unknown
        }
    }
    private enum CodingKeys: String, CodingKey {
        case id, couponId, useStatus, couponName, couponDescription, note, getTime, useTime, startTime, endTime
        case shopName, shopAddress, shopLat, shopLng
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        guard id > 0 else { throw APIError.malformedResponse }
        couponID = try c.decodeIfPresent(Int.self, forKey: .couponId)
        useStatus = try c.decodeIfPresent(Int.self, forKey: .useStatus)
        name = try c.decodeIfPresent(String.self, forKey: .couponName)
        description = try c.decodeIfPresent(String.self, forKey: .couponDescription)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        receivedTime = try c.decodeIfPresent(String.self, forKey: .getTime)
        usedTime = try c.decodeIfPresent(String.self, forKey: .useTime)
        startTime = try c.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try c.decodeIfPresent(String.self, forKey: .endTime)
        shopName = Self.publicText(c, .shopName)
        shopAddress = Self.publicText(c, .shopAddress)
        shopLatitude = Self.publicCoordinate(c, .shopLat)
        shopLongitude = Self.publicCoordinate(c, .shopLng)
    }
    /// A blank or non-string shop label is unknown. It is not stored as an empty place.
    private static func publicText(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        guard c.contains(key), (try? c.decodeNil(forKey: key)) != true else { return nil }
        guard let raw = try? c.decode(String.self, forKey: key) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    /// JSON numbers only. Null, a missing key, a numeric string, and a non-finite value stay unknown.
    private static func publicCoordinate(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        guard c.contains(key), (try? c.decodeNil(forKey: key)) != true else { return nil }
        guard let value = try? c.decode(Double.self, forKey: key), value.isFinite else { return nil }
        return value
    }
    /// Presentation only: an unused coupon may have a later business-calendar start day.
    /// This never decides whether the server will issue or accept a redemption code.
    public func futureStartDay(relativeTo now: Date) -> String? {
        guard status == .unused, now.timeIntervalSinceReferenceDate.isFinite,
              let startTime else { return nil }
        let source = startTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = Array(source.utf8)
        guard bytes.count == 10 || bytes.count == 19 else { return nil }
        if bytes.count == 19 {
            guard (bytes[10] == 32 || bytes[10] == 84), bytes[13] == 58, bytes[16] == 58,
                  [11,12,14,15,17,18].allSatisfy({ (48...57).contains(bytes[$0]) }) else { return nil }
            let hour = Int(bytes[11] - 48) * 10 + Int(bytes[12] - 48)
            let minute = Int(bytes[14] - 48) * 10 + Int(bytes[15] - 48)
            let second = Int(bytes[17] - 48) * 10 + Int(bytes[18] - 48)
            guard hour < 24, minute < 60, second < 60 else { return nil }
        }
        guard let day = Self.calendarDay(source) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        guard let year = parts.year, (1...9999).contains(year), let month = parts.month, let date = parts.day else { return nil }
        let today = String(format: "%04d.%02d.%02d", year, month, date)
        return day > today ? day : nil
    }
    /// The API supplies a China-calendar date. Preserve its day rather than converting to
    /// the device time zone. Invalid dates remain unknown; never compute expiry locally.
    public static func calendarDay(_ value: String?) -> String? {
        guard let value else { return nil }
        let prefix = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(10))
        let components = prefix.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 3, components[0].count == 4, components[1].count == 2, components[2].count == 2,
              components.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(components[0]), let month = Int(components[1]), let day = Int(components[2]), year > 0 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let parts = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: parts) else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day else { return nil }
        return prefix.replacingOccurrences(of: "-", with: ".")
    }
}
public enum AccountCollectionCouponStatus: String, Equatable { case unused, used, expired, invalid, unknown }

/// The source wallet has exactly four filters; invalid/unknown rows remain visible in All.
public enum AccountCollectionCouponFilter: String, CaseIterable, Identifiable {
    case all, unused, used, expired
    public var id: String { rawValue }
    public func includes(_ coupon: AccountCollectionCoupon) -> Bool {
        switch self {
        case .all: return true
        case .unused: return coupon.useStatus == 0
        case .used: return coupon.useStatus == 1
        case .expired: return coupon.useStatus == 2
        }
    }
}

/// This is a numbered legacy collection, not a community feed cursor. The raw
/// response length controls continuation even when display IDs are duplicates.
public struct AccountCollectionPostPage: Equatable {
    public let rows: [SquarePost]
    public let pageNumber: Int
    public let pageSize: Int
    /// The unmodified `/api/creativesquare/list` response body for this page, kept so
    /// `AccountCollectionFavoritesPageModel.resolvePosts` can tell a missing count from a literal 0.
    /// Nil for fixtures and for pages built without a body. Never persisted, never logged.
    public let rawPayload: Data?
    public var hasMore: Bool { rows.count >= pageSize }
    public init(rows: [SquarePost], pageNumber: Int, pageSize: Int, rawPayload: Data? = nil) {
        self.rows = rows; self.pageNumber = pageNumber; self.pageSize = pageSize; self.rawPayload = rawPayload
    }
}
public struct AccountCollectionPostPagination {
    public private(set) var rows: [SquarePost] = []
    public private(set) var nextPage = 1
    public private(set) var hasMore = true
    private var pageSize: Int?
    public init() {}
    public mutating func accept(_ page: AccountCollectionPostPage) throws {
        guard hasMore, page.pageNumber == nextPage, (1...100).contains(page.pageSize),
              pageSize == nil || pageSize == page.pageSize,
              page.rows.count <= page.pageSize,
              page.rows.allSatisfy({ $0.id > 0 && $0.generation == .legacySquare }) else { throw APIError.malformedResponse }
        var seen = Set(rows.map(\.id))
        rows += page.rows.filter { seen.insert($0.id).inserted }
        pageSize = page.pageSize
        hasMore = page.hasMore && nextPage < Int.max
        if nextPage < Int.max { nextPage += 1 }
    }
}

public enum AccountCollectionReadFailure: Error, Equatable {
    case unavailable
    case rejected(code: Int, message: String?)
}
public enum AccountCollectionIssue: Equatable {
    case login, notConfigured, unavailable, network, failure, server(String)
    public init(_ error: Error) {
        switch error {
        case APIError.unauthorized: self = .login
        case APIError.notConfigured: self = .notConfigured
        case AccountCollectionReadFailure.unavailable: self = .unavailable
        case AccountCollectionReadFailure.rejected(_, let message): self = message.map(Self.server) ?? .failure
        case is URLError: self = .network
        default: self = .failure
        }
    }
    public var localizationKey: String {
        switch self {
        case .login: return "accountCollection.signInRequired"
        case .notConfigured: return "accountCollection.notConfigured"
        case .unavailable: return "accountCollection.unavailable"
        case .network: return "accountCollection.network"
        case .failure, .server: return "accountCollection.failed"
        }
    }
}

/// Read-only projection of the favorites page (`pages/mylike/mylike`).
/// Posts are `POST /api/creativesquare/list` with `favorite_only=1`.
/// Topics are `POST /api/topic/like_list`. Both paths are already live.
/// This type does not build a request, open a session, or change a route mark.
///
/// `SquarePost` now keeps a missing like or comment count as nil (`SquareCountDisplay`);
/// `TopicSummary` still stores a missing count as 0. This projection does not change either decoder. An omitted count, null, a numeric string, a fraction,
/// a boolean, or a negative is U+2014. A literal JSON 0 stays "0".
public enum AccountCollectionFavoritesPageModel {
    /// Em dash (U+2014). Unknown numbers use this. A literal zero does not.
    public static let unknownMark = "\u{2014}"
    public static let postsPath = "/api/creativesquare/list"
    public static let topicsPath = "/api/topic/like_list"
    public static let postsEmptyKey = "member.favorites.postsEmpty"
    public static let topicsEmptyKey = "accountCollection.favorites.empty"
    public static let postsEndKey = "member.favorites.postsEnd"
    public static let topicsEndKey = "member.favorites.topicsEnd"

    /// Reads the existing mark. It does not insert a path or flip a mark to live.
    public static func existingRouteIsLive(_ path: String) -> Bool {
        ChinaReviewedRouteCapability.mark(for: path) == .liveInProduction
            && ChinaReviewedRouteCapability.admitsChinaProductionCall(path)
    }

    public static func countText(_ value: Any?) -> String {
        guard let number = AccountCollectionFavoritesWire.wholeNumber(value), number >= 0 else { return unknownMark }
        return String(number)
    }

    public static func titleKey(for error: Error) -> String {
        AccountCollectionIssue(error).localizationKey
    }

    public static func serverMessage(for error: Error) -> String? {
        guard case .server(let message) = AccountCollectionIssue(error) else { return nil }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// `failure` wins. A present payload wins over `loading`. No payload while loading is `.loading`.
    /// No payload while idle is `.unknown`, not an empty collection.
    public static func resolvePosts(loading: Bool, payload: Data?, failure: Error?, pageSize: Int) -> AccountCollectionFavoritesPostsState {
        switch AccountCollectionFavoritesWire.classify(loading: loading, payload: payload, failure: failure) {
        case .loading: return .loading
        case .unknown: return .unknown
        case .error(let titleKey, let serverMessage): return .error(titleKey: titleKey, serverMessage: serverMessage)
        case .value(let data): return projectPosts(data, pageSize: pageSize)
        }
    }

    public static func resolveTopics(loading: Bool, payload: Data?, failure: Error?, pageSize: Int) -> AccountCollectionFavoritesTopicsState {
        switch AccountCollectionFavoritesWire.classify(loading: loading, payload: payload, failure: failure) {
        case .loading: return .loading
        case .unknown: return .unknown
        case .error(let titleKey, let serverMessage): return .error(titleKey: titleKey, serverMessage: serverMessage)
        case .value(let data): return projectTopics(data, pageSize: pageSize)
        }
    }

    private static func projectPosts(_ data: Any, pageSize: Int) -> AccountCollectionFavoritesPostsState {
        guard (1...100).contains(pageSize) else { return .error(titleKey: "accountCollection.failed", serverMessage: nil) }
        if AccountCollectionFavoritesWire.isUnknownToken(data) || data is NSNull { return .unknown }
        guard let object = data as? [String: Any] else { return .error(titleKey: "accountCollection.failed", serverMessage: nil) }
        guard object.keys.contains("rows") else { return .unknown }
        return projectPostRows(object["rows"], pageSize: pageSize)
    }

    private static func projectTopics(_ data: Any, pageSize: Int) -> AccountCollectionFavoritesTopicsState {
        guard (1...100).contains(pageSize) else { return .error(titleKey: "accountCollection.failed", serverMessage: nil) }
        if AccountCollectionFavoritesWire.isUnknownToken(data) || data is NSNull { return .unknown }
        if let rows = data as? [Any] { return projectTopicRows(rows, pageSize: pageSize) }
        guard let object = data as? [String: Any] else { return .error(titleKey: "accountCollection.failed", serverMessage: nil) }
        guard object.keys.contains("rows") else { return .unknown }
        let rows = object["rows"]
        if AccountCollectionFavoritesWire.isUnknownToken(rows) || rows == nil || rows is NSNull { return .unknown }
        guard let list = rows as? [Any] else { return .error(titleKey: "accountCollection.failed", serverMessage: nil) }
        return projectTopicRows(list, pageSize: pageSize)
    }

    private static func projectPostRows(_ rows: Any?, pageSize: Int) -> AccountCollectionFavoritesPostsState {
        if AccountCollectionFavoritesWire.isUnknownToken(rows) || rows == nil || rows is NSNull { return .unknown }
        guard let list = rows as? [Any] else { return .error(titleKey: "accountCollection.failed", serverMessage: nil) }
        guard list.count <= pageSize else { return .error(titleKey: "accountCollection.failed", serverMessage: nil) }
        if list.isEmpty { return .empty }
        var posts: [AccountCollectionFavoritesPostFacts] = []
        posts.reserveCapacity(list.count)
        for row in list {
            guard let object = row as? [String: Any], !object.keys.contains("post"),
                  let id = AccountCollectionFavoritesWire.wholeNumber(object["id"]), id > 0 else {
                return .error(titleKey: "accountCollection.failed", serverMessage: nil)
            }
            posts.append(AccountCollectionFavoritesPostFacts(
                id: id,
                likeCountText: AccountCollectionFavoritesWire.count(object, keys: ["likeCount", "likeNum"]),
                commentCountText: AccountCollectionFavoritesWire.count(object, keys: ["commentCount"]),
                dislikeCountText: AccountCollectionFavoritesWire.count(object, keys: ["nolikeNum"]),
                nodeTotalText: AccountCollectionFavoritesWire.count(object, keys: ["nodeTotal"]),
                nodeDoneText: AccountCollectionFavoritesWire.count(object, keys: ["nodeDoneCount"]),
                memberLevelText: AccountCollectionFavoritesWire.level(object, keys: ["memberLevelId", "member_level_id"]),
                imageCountText: AccountCollectionFavoritesWire.imageCount(object),
                bookmarked: AccountCollectionFavoritesWire.bookmark(object["isBookmarked"])
            ))
        }
        return .ready(AccountCollectionFavoritesPostPage(posts: posts, hasMore: list.count >= pageSize))
    }

    private static func projectTopicRows(_ rows: [Any], pageSize: Int) -> AccountCollectionFavoritesTopicsState {
        guard rows.count <= pageSize else { return .error(titleKey: "accountCollection.failed", serverMessage: nil) }
        if rows.isEmpty { return .empty }
        var topics: [AccountCollectionFavoritesTopicFacts] = []
        topics.reserveCapacity(rows.count)
        for row in rows {
            guard let object = row as? [String: Any],
                  let id = AccountCollectionFavoritesWire.topicID(object["id"]) else {
                return .error(titleKey: "accountCollection.failed", serverMessage: nil)
            }
            topics.append(AccountCollectionFavoritesTopicFacts(
                id: id,
                locationCountText: AccountCollectionFavoritesWire.count(object, keys: ["locationCount"]),
                likeCountText: AccountCollectionFavoritesWire.count(object, keys: ["likeNum"])
            ))
        }
        return .ready(AccountCollectionFavoritesTopicPage(topics: topics, hasMore: rows.count >= pageSize))
    }
}

public enum AccountCollectionFavoritesPostsState: Equatable, Sendable {
    case loading
    case empty
    case error(titleKey: String, serverMessage: String?)
    case unknown
    case ready(AccountCollectionFavoritesPostPage)
}

public enum AccountCollectionFavoritesTopicsState: Equatable, Sendable {
    case loading
    case empty
    case error(titleKey: String, serverMessage: String?)
    case unknown
    case ready(AccountCollectionFavoritesTopicPage)
}

public enum AccountCollectionFavoritesFlag: Equatable, Sendable {
    case unknown
    case no
    case yes
}

public struct AccountCollectionFavoritesPostFacts: Equatable, Sendable {
    public let id: Int
    public let likeCountText: String
    public let commentCountText: String
    public let dislikeCountText: String
    public let nodeTotalText: String
    public let nodeDoneText: String
    public let memberLevelText: String
    public let imageCountText: String
    public let bookmarked: AccountCollectionFavoritesFlag
    /// This projection never sends a bookmark, unlike, or share.
    public var sends: Bool { false }
    public init(id: Int, likeCountText: String, commentCountText: String, dislikeCountText: String,
                nodeTotalText: String, nodeDoneText: String, memberLevelText: String, imageCountText: String,
                bookmarked: AccountCollectionFavoritesFlag) {
        self.id = id
        self.likeCountText = likeCountText
        self.commentCountText = commentCountText
        self.dislikeCountText = dislikeCountText
        self.nodeTotalText = nodeTotalText
        self.nodeDoneText = nodeDoneText
        self.memberLevelText = memberLevelText
        self.imageCountText = imageCountText
        self.bookmarked = bookmarked
    }
}

public struct AccountCollectionFavoritesPostPage: Equatable, Sendable {
    public let posts: [AccountCollectionFavoritesPostFacts]
    public let hasMore: Bool
    public var showsEnd: Bool { !posts.isEmpty && !hasMore }
    public init(posts: [AccountCollectionFavoritesPostFacts], hasMore: Bool) {
        self.posts = posts
        self.hasMore = hasMore
    }
}

public struct AccountCollectionFavoritesTopicFacts: Equatable, Sendable {
    public let id: Int
    public let locationCountText: String
    public let likeCountText: String
    /// This projection never sends a topic unlike.
    public var sends: Bool { false }
    public init(id: Int, locationCountText: String, likeCountText: String) {
        self.id = id
        self.locationCountText = locationCountText
        self.likeCountText = likeCountText
    }
}

public struct AccountCollectionFavoritesTopicPage: Equatable, Sendable {
    public let topics: [AccountCollectionFavoritesTopicFacts]
    public let hasMore: Bool
    public var showsEnd: Bool { !topics.isEmpty && !hasMore }
    public init(topics: [AccountCollectionFavoritesTopicFacts], hasMore: Bool) {
        self.topics = topics
        self.hasMore = hasMore
    }
}

private enum AccountCollectionFavoritesWire {
    enum Kind {
        case loading
        case unknown
        case error(String, String?)
        case value(Any)
    }

    static func classify(loading: Bool, payload: Data?, failure: Error?) -> Kind {
        if let failure {
            return .error(AccountCollectionFavoritesPageModel.titleKey(for: failure),
                          AccountCollectionFavoritesPageModel.serverMessage(for: failure))
        }
        guard let payload else { return loading ? .loading : .unknown }
        let trimmed = trim(payload)
        guard !trimmed.isEmpty else { return loading ? .loading : .unknown }
        guard let raw = try? JSONSerialization.jsonObject(with: trimmed, options: [.fragmentsAllowed]) else {
            return .error("accountCollection.failed", nil)
        }
        if isUnknownToken(raw) || raw is NSNull { return .unknown }
        guard let object = raw as? [String: Any] else { return .error("accountCollection.failed", nil) }
        guard object.keys.contains("code") else { return .error("accountCollection.failed", nil) }
        switch envelopeCode(object["code"]) {
        case .malformed:
            return .error("accountCollection.failed", nil)
        case .value(200):
            guard let data = object["data"] else { return .unknown }
            if isUnknownToken(data) || data is NSNull { return .unknown }
            return .value(data)
        case .value(401):
            return .error("accountCollection.signInRequired", message(object["msg"]))
        case .value:
            return .error("accountCollection.failed", message(object["msg"]))
        }
    }

    static func count(_ object: [String: Any], keys: [String]) -> String {
        for key in keys {
            guard object.keys.contains(key) else { continue }
            let value = object[key]
            if value == nil || value is NSNull { continue }
            return AccountCollectionFavoritesPageModel.countText(value)
        }
        return AccountCollectionFavoritesPageModel.unknownMark
    }

    /// Existing `memberLevelId` integer parse, including a decimal-digit string. A missing level stays unknown.
    static func level(_ object: [String: Any], keys: [String]) -> String {
        for key in keys {
            guard object.keys.contains(key) else { continue }
            let value = object[key]
            if value == nil || value is NSNull { continue }
            if let number = wholeNumber(value) { return number >= 0 ? String(number) : AccountCollectionFavoritesPageModel.unknownMark }
            if let text = value as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let digits = !trimmed.isEmpty && trimmed.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
                if digits, let number = Int(trimmed), number >= 0 { return String(number) }
            }
            return AccountCollectionFavoritesPageModel.unknownMark
        }
        return AccountCollectionFavoritesPageModel.unknownMark
    }

    /// Topic ids follow `TopicSummary`: a positive JSON integer, or a string `Int` accepts.
    static func topicID(_ value: Any?) -> Int? {
        if let number = wholeNumber(value), number > 0 { return number }
        guard let text = value as? String, let number = Int(text), number > 0 else { return nil }
        return number
    }

    static func bookmark(_ value: Any?) -> AccountCollectionFavoritesFlag {
        guard let number = wholeNumber(value) else { return .unknown }
        if number == 1 { return .yes }
        if number == 0 { return .no }
        return .unknown
    }

    static func imageCount(_ row: [String: Any]) -> String {
        let media = row["media"]
        if let rows = media as? [Any] {
            let images = rows.compactMap { item -> String? in
                guard let object = item as? [String: Any] else { return nil }
                let kind = (object["media_type"] as? String) ?? (object["mediaType"] as? String) ?? "IMAGE"
                guard kind == "IMAGE" else { return nil }
                let key = (object["derived_object_key"] as? String) ?? (object["derivedObjectKey"] as? String)
                let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            if !images.isEmpty { return String(images.count) }
            if !row.keys.contains("pics") { return "0" }
        } else if media != nil && !(media is NSNull) {
            return AccountCollectionFavoritesPageModel.unknownMark
        }
        guard row.keys.contains("pics") else { return AccountCollectionFavoritesPageModel.unknownMark }
        let pics = row["pics"]
        if pics == nil || pics is NSNull { return AccountCollectionFavoritesPageModel.unknownMark }
        if let count = pictureCount(pics as Any) { return String(count) }
        return AccountCollectionFavoritesPageModel.unknownMark
    }

    static func pictureCount(_ value: Any) -> Int? {
        if let rows = value as? [Any] {
            return rows.reduce(0) { count, item in
                guard let text = item as? String else { return count }
                return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? count : count + 1
            }
        }
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        if trimmed.hasPrefix("["), let data = trimmed.data(using: .utf8),
           let rows = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            return pictureCount(rows)
        }
        let parts = trimmed.components(separatedBy: CharacterSet(charactersIn: ";,，；"))
        return parts.reduce(0) { count, part in
            part.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? count : count + 1
        }
    }

    static func isUnknownToken(_ value: Any?) -> Bool {
        guard let text = value as? String else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) == "UNKNOWN"
    }

    static func message(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    enum Code: Equatable { case malformed, value(Int) }

    static func envelopeCode(_ value: Any?) -> Code {
        guard let number = wholeNumber(value), number >= 0 else { return .malformed }
        return .value(number)
    }

    /// A JSON integer, including 0. Numeric strings, booleans, and fractions are not integers.
    static func wholeNumber(_ value: Any?) -> Int? {
        guard let value, !(value is NSNull), !(value is String) else { return nil }  // no `is Bool`: Darwin bridges NSNumber 0/1 to Bool
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite, double.rounded() == double else { return nil }
        return Int(exactly: double)
    }

    static func trim(_ data: Data) -> Data {
        var bytes = data
        let whitespace = Set(" \n\r\t".utf8)
        while let first = bytes.first, whitespace.contains(first) { bytes.removeFirst() }
        while let last = bytes.last, whitespace.contains(last) { bytes.removeLast() }
        return bytes
    }
}

#if DEBUG
/// Synthetic favorites payloads. No host, token, or transport.
public enum AccountCollectionFavoritesPageFixtureData {
    public static let readyPosts = #"{"code":200,"data":{"rows":[{"id":11,"likeNum":12,"commentCount":3,"nolikeNum":0,"memberLevelId":"2","isBookmarked":1,"pics":"a;b","nodeTotal":6,"nodeDoneCount":0}],"total":900}}"#
    public static let literalZeroPosts = #"{"code":200,"data":{"rows":[{"id":11,"likeCount":0,"commentCount":0,"nolikeNum":0,"nodeTotal":0,"nodeDoneCount":0,"memberLevelId":0,"isBookmarked":0,"pics":""}]}}"#
    public static let unknownPostCounts = #"{"code":200,"data":{"rows":[{"id":11}]}}"#
    public static let numericStringCounts = #"{"code":200,"data":{"rows":[{"id":11,"likeCount":"0","commentCount":"4","nodeTotal":1.5,"nolikeNum":true,"pics":null}]}}"#
    public static let emptyPosts = #"{"code":200,"data":{"rows":[],"total":900}}"#
    public static let missingPostRows = #"{"code":200,"data":{"total":0}}"#
    public static let readyTopics = #"{"code":200,"data":{"rows":[{"id":301,"locationCount":0,"likeNum":4},{"id":"302","locationCount":2}]}}"#
    public static let unknownTopicCounts = #"{"code":200,"data":[{"id":301,"locationCount":"0","likeNum":null}]}"#
    public static let emptyTopics = #"{"code":200,"data":[]}"#
    public static let unknownBody = #""UNKNOWN""#
}
#endif
