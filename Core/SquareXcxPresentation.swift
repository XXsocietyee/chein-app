import Foundation

/// Display rules ported from the mini-program Square pages (`pages/square/list`, `pages/square/detail`,
/// `components/cy/post-card`). Pure presentation: no request, write or media authority lives here.
public enum SquareXcxTime {
    /// Source `toTimestamp`: wall-clock strings are China time (+08:00); ISO strings keep their offset;
    /// all-digit values are epoch milliseconds. Unparseable values stay unknown (nil), never "now".
    public static func date(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.utf8.allSatisfy({ (48...57).contains($0) }), let ms = Double(value), ms > 0 { return Date(timeIntervalSince1970: ms / 1000) }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        for pattern in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy/MM/dd HH:mm:ss"] {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
    public static func date(_ time: OfficialEventTime?) -> Date? {
        switch time {
        case .milliseconds(let ms)?: return ms > 0 ? Date(timeIntervalSince1970: ms / 1000) : nil
        case .text(let text)?: return date(text)
        case nil: return nil
        }
    }
}

/// Source `formatTimeDifference`: `N天前`, otherwise `[H时][M分]前`, and `刚刚` at zero minutes.
public enum SquareRelativeAge: Equatable {
    case justNow
    case days(Int)
    case hoursMinutes(hours: Int, minutes: Int)
    public static func of(_ createTime: String, now: Date) -> Self? {
        guard let date = SquareXcxTime.date(createTime) else { return nil }
        let elapsed = now.timeIntervalSince(date)
        guard elapsed.isFinite, elapsed > 0 else { return .justNow }
        let totalMinutes = Int(elapsed / 60)
        let days = totalMinutes / (24 * 60)
        if days > 0 { return .days(days) }
        let hours = totalMinutes / 60, minutes = totalMinutes % 60
        return hours == 0 && minutes == 0 ? .justNow : .hoursMinutes(hours: hours, minutes: minutes)
    }
}

/// Source list banner: official events with `bannerEnabled`, status 1 or 2, starting within the next 24 hours.
public struct SquareUpcomingBannerItem: Equatable, Identifiable {
    public enum Countdown: Equatable { case days(Int), hours(Int), minutes(Int), soon }
    public let id: Int
    public let title: String
    public let subtitle: String?
    public let start: Date
    public let avatars: [String]
    public let overflow: Int
    public func countdown(now: Date) -> Countdown {
        let seconds = start.timeIntervalSince(now)
        if seconds >= 86_400 { return .days(Int(seconds / 86_400)) }
        if seconds >= 3_600 { return .hours(Int(seconds / 3_600)) }
        if seconds >= 60 { return .minutes(Int(seconds / 60)) }
        return .soon
    }
    public static func select(_ events: [OfficialEvent], now: Date) -> [Self] {
        let horizon = now.addingTimeInterval(86_400)
        return events.compactMap { event -> Self? in
            guard event.isCompleteRecord, event.bannerEnabled, event.status == 1 || event.status == 2,
                  let start = SquareXcxTime.date(event.activityStart), start >= now, start < horizon else { return nil }
            let avatars = Array(event.participantAvatars.prefix(3))
            let total = max(event.participants ?? 0, event.participantAvatars.count)
            let subtitle = [event.subtitle, event.city].lazy.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
            return .init(id: event.id, title: event.title, subtitle: subtitle, start: start, avatars: avatars, overflow: max(0, total - 3))
        }.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
}

/// Derived post-card facts (source `cy-post-card` and `feed-play-card`).
public struct SquarePostCardFacts: Equatable {
    public enum Lifecycle: String, Equatable { case draft = "DRAFT", checking = "CHECKING", limited = "LIMITED", hidden = "HIDDEN", removed = "REMOVED" }
    public enum PlaySubtitle: Equatable { case completedNodes(Int), progress(done: Int, total: Int), completed, inProgress }
    public let isCompletionShare: Bool
    public let hasPlayCover: Bool
    public let playCover: String?
    public let playSubtitle: PlaySubtitle?
    public let lifecycle: Lifecycle?
    public let bodyExpandable: Bool
    /// Images shown in the horizontal strip; a route preview leads when the post has no play card.
    public let strip: [String]
    public let leadingRoutePreview: String?
    public let showsCountPill: Bool
    public let isRemixable: Bool
    public init(_ post: SquarePost) {
        let cover = SquarePostCardFacts.nonempty(post.routeImage) ?? SquarePostCardFacts.nonempty(post.referenceCover)
        let title = SquarePostCardFacts.nonempty(post.referenceTitle)
        isCompletionShare = post.dataType == 3 || (post.dataType == 1 && post.completed && title != nil)
        hasPlayCover = title != nil && cover != nil
        playCover = isCompletionShare ? (post.images.first ?? cover) : (hasPlayCover ? cover : nil)
        if title == nil { playSubtitle = nil }
        else if post.nodeTotal > 0 { playSubtitle = post.completed ? .completedNodes(post.nodeTotal) : .progress(done: max(0, min(post.nodeDoneCount, post.nodeTotal)), total: post.nodeTotal) }
        else { playSubtitle = post.completed ? .completed : .inProgress }
        lifecycle = Lifecycle(rawValue: post.lifecycle)
        let body = post.contents ?? ""
        // MP post-card js:77 `text.length > 120 || lines > 6` (wxss:169 clamps at 6 lines).
        bodyExpandable = body.count > 120 || body.split(separator: "\n", omittingEmptySubsequences: false).count > 6
        leadingRoutePreview = isCompletionShare || title != nil ? nil : cover
        strip = isCompletionShare ? [] : post.images
        showsCountPill = post.images.count >= 2
        isRemixable = post.isTopicTemplate && (post.topicID ?? 0) > 0
    }
    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

/// UGC safety entry for another member's post or comment on pages/square/detail.
/// Reporting is wired through the reviewed report flow. The mini-program and the backend expose no
/// "block this member" route for the square (blocking exists only inside a conversation), so the
/// block entry is shown honestly as not available yet: it never claims success and sends nothing.
public enum SquareAuthorSafety {
    public enum BlockAvailability: Equatable { case notAvailableYet }
    public static let blockAvailability: BlockAvailability = .notAvailableYet
    /// App-wide member blocking uses the existing IM/blacklist routes (`/api/im/block`, `/api/native/blacklist/*`).
    public static let usesMemberBlacklist = true
    /// Offered only for another signed-in viewer's view of someone else's content.
    public static func showsBlockEntry(authorMemberID: Int, viewerMemberID: Int?) -> Bool {
        guard let viewerMemberID, viewerMemberID > 0, authorMemberID > 0 else { return false }
        return authorMemberID != viewerMemberID
    }
}

/// Read-only projection of the existing square-detail contract (`SquareService.detail` /
/// `comments`, both generations). It does not build a request, open a session, or change
/// `ChinaReviewedRouteCapability`. A block route is not added.
///
/// Unknown counts are U+2014. A literal JSON 0 stays "0". `SquarePost` still stores a missing
/// count as 0; this type does not change that decoder.
public enum SquareDetailPageModel {
    /// Em dash (U+2014). Unknown numbers use this. A literal zero does not.
    public static let unknownMark = "\u{2014}"
    public static let emptyCommentsTitleKey = "square.xcx.noCommentsTitle"
    public static let emptyCommentsDetailKey = "square.xcx.noCommentsDetail"
    public static let legacyDetailPath = "/api/creativesquare/info"
    public static let communityDetailPath = "/api/v1/community/posts/{}"
    public static let legacyCommentsPath = "/api/comment/list"
    public static let communityCommentsPath = "/api/v1/community/posts/{}/comments"

    /// Reads the existing mark. It does not insert a path or flip a mark to live.
    public static func existingRouteIsLive(_ path: String) -> Bool {
        ChinaReviewedRouteCapability.mark(for: path) == .liveInProduction
            && ChinaReviewedRouteCapability.admitsChinaProductionCall(path)
    }

    /// No square block path is named on the reviewed map. This stays false.
    public static let blockRouteIsLive = false

    public static func countText(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return unknownMark }
        guard let number = SquareDetailWire.wholeNumber(value), number >= 0 else { return unknownMark }
        return String(number)
    }

    public static func titleKey(for error: Error) -> String {
        if let failure = error as? SquareReadFailure {
            switch failure {
            case .signInRequired: return "square.signInRequired"
            case .cityRequired: return "square.cityRequired"
            case .topicRequired: return "square.topicRequired"
            case .communityRequired: return "square.communityRequired"
            case .unavailable: return "square.unavailable"
            case .server: return "square.failed"
            }
        }
        if let api = error as? APIError {
            switch api {
            case .unauthorized: return "square.unauthorized"
            case .notConfigured: return "square.notConfigured"
            default: return "square.failed"
            }
        }
        return "square.failed"
    }

    public static func serverMessage(for error: Error) -> String? {
        guard case .server(_, let message) = error as? SquareReadFailure else { return nil }
        guard let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// `failure` wins. A closed community gate does not read the payload. An accepted post wins over `loading`.
    /// `communityRead == false` is the source closed gate. `nil` does not invent a gate.
    public static func resolvePost(loading: Bool, payload: Data?, failure: Error?, communityRead: Bool? = nil) -> SquareDetailPostState {
        if communityRead == false { return .error(titleKey: "square.xcx.closedTitle", serverMessage: nil) }
        if let failure { return .error(titleKey: titleKey(for: failure), serverMessage: serverMessage(for: failure)) }
        guard let payload else { return loading ? .loading : .empty }
        let trimmed = SquareDetailWire.trimmed(payload)
        guard !trimmed.isEmpty else { return loading ? .loading : .empty }
        guard let raw = try? JSONSerialization.jsonObject(with: trimmed, options: [.fragmentsAllowed]) else { return .error(titleKey: "square.failed", serverMessage: nil) }
        if SquareDetailWire.isUnknownToken(raw) { return .unknown }
        if raw is NSNull { return .empty }
        guard let object = raw as? [String: Any] else { return .error(titleKey: "square.failed", serverMessage: nil) }
        if object["id"] != nil || object["post"] != nil { return projectPost(object) }
        if object.isEmpty { return .empty }
        switch SquareDetailWire.envelopeCode(object["code"]) {
        case .absent:
            return object["data"] == nil ? .unknown : projectPostData(object["data"])
        case .malformed:
            return .error(titleKey: "square.failed", serverMessage: nil)
        case .value(200):
            guard let data = object["data"] else { return .empty }
            return projectPostData(data)
        case .value(401):
            return .error(titleKey: "square.unauthorized", serverMessage: SquareDetailWire.message(object["msg"]))
        case .value:
            return .error(titleKey: "square.failed", serverMessage: SquareDetailWire.message(object["msg"]))
        }
    }

    /// A missing or null comment list is `.unknown`, not an empty thread. `rows: []` or `items: []` is `.empty`.
    public static func resolveComments(loading: Bool, payload: Data?, failure: Error?, list: SquareDetailCommentList) -> SquareDetailCommentsState {
        if let failure { return .error(titleKey: titleKey(for: failure), serverMessage: serverMessage(for: failure)) }
        guard let payload else { return loading ? .loading : .unknown }
        let trimmed = SquareDetailWire.trimmed(payload)
        guard !trimmed.isEmpty else { return loading ? .loading : .unknown }
        guard let raw = try? JSONSerialization.jsonObject(with: trimmed, options: [.fragmentsAllowed]) else { return .error(titleKey: "square.failed", serverMessage: nil) }
        if SquareDetailWire.isUnknownToken(raw) { return .unknown }
        if let rows = raw as? [Any] {
            guard list == .legacyRows else { return .unknown }
            return projectCommentRows(rows, hasMore: .unknown)
        }
        guard let object = raw as? [String: Any] else { return .error(titleKey: "square.failed", serverMessage: nil) }
        if object[list.key] != nil && object["code"] == nil && object["data"] == nil {
            return projectCommentBody(object, list: list)
        }
        switch SquareDetailWire.envelopeCode(object["code"]) {
        case .absent:
            guard let data = object["data"] else { return .unknown }
            return projectCommentData(data, list: list)
        case .malformed:
            return .error(titleKey: "square.failed", serverMessage: nil)
        case .value(200):
            guard let data = object["data"] else { return .unknown }
            return projectCommentData(data, list: list)
        case .value(401):
            return .error(titleKey: "square.unauthorized", serverMessage: SquareDetailWire.message(object["msg"]))
        case .value:
            return .error(titleKey: "square.failed", serverMessage: SquareDetailWire.message(object["msg"]))
        }
    }

    private static func projectPostData(_ data: Any?) -> SquareDetailPostState {
        if SquareDetailWire.isUnknownToken(data) { return .unknown }
        if data == nil || data is NSNull { return .empty }
        // Source treats a non-object, including an array, as an empty detail rather than a loaded post.
        guard let object = data as? [String: Any] else { return .empty }
        if object.isEmpty { return .empty }
        return projectPost(object)
    }

    private static func projectPost(_ object: [String: Any]) -> SquareDetailPostState {
        if object["post"] != nil && !(object["post"] is [String: Any]) {
            return .error(titleKey: "square.failed", serverMessage: nil)
        }
        let post = object["post"] as? [String: Any] ?? object
        guard let id = SquareDetailWire.wholeNumber(post["id"]), id > 0 else {
            return .error(titleKey: "square.failed", serverMessage: nil)
        }
        return .ready(SquareDetailPostFacts(
            id: id,
            likeCountText: SquareDetailWire.count(post, keys: ["likeCount", "likeNum"]),
            commentCountText: SquareDetailWire.count(post, keys: ["commentCount"]),
            dislikeCountText: SquareDetailWire.count(post, keys: ["nolikeNum"]),
            nodeTotalText: SquareDetailWire.count(object, keys: ["nodeTotal"]),
            nodeDoneText: SquareDetailWire.count(object, keys: ["nodeDoneCount"]),
            memberLevelText: SquareDetailWire.level(post, keys: ["memberLevelId", "member_level_id"]),
            imageCountText: SquareDetailWire.imageCount(object, post: post),
            bookmarked: SquareDetailWire.bookmark(post["isBookmarked"]),
            viewerCanComment: SquareDetailWire.viewerCanComment(object["viewerCanComment"])
        ))
    }

    private static func projectCommentData(_ data: Any?, list: SquareDetailCommentList) -> SquareDetailCommentsState {
        if SquareDetailWire.isUnknownToken(data) { return .unknown }
        if data == nil || data is NSNull { return .unknown }
        guard let object = data as? [String: Any] else { return .error(titleKey: "square.failed", serverMessage: nil) }
        return projectCommentBody(object, list: list)
    }

    private static func projectCommentBody(_ object: [String: Any], list: SquareDetailCommentList) -> SquareDetailCommentsState {
        let key = list.key
        guard object.keys.contains(key) else { return .unknown }
        let value = object[key]
        if value == nil || value is NSNull || SquareDetailWire.isUnknownToken(value) { return .unknown }
        guard let rows = value as? [Any] else { return .error(titleKey: "square.failed", serverMessage: nil) }
        return projectCommentRows(rows, hasMore: SquareDetailWire.flag(object["hasMore"]))
    }

    private static func projectCommentRows(_ rows: [Any], hasMore: SquareDetailFlag) -> SquareDetailCommentsState {
        if rows.isEmpty { return .empty }
        var comments: [SquareDetailCommentFacts] = []
        comments.reserveCapacity(rows.count)
        for row in rows {
            guard let object = row as? [String: Any], let id = SquareDetailWire.wholeNumber(object["id"]), id > 0 else {
                return .error(titleKey: "square.failed", serverMessage: nil)
            }
            comments.append(SquareDetailCommentFacts(
                id: id,
                likeCountText: SquareDetailWire.count(object, keys: ["like_count", "likeCount"])
            ))
        }
        return .ready(SquareDetailCommentPage(comments: comments, hasMore: hasMore))
    }
}

public enum SquareDetailPostState: Equatable, Sendable {
    case loading
    case empty
    case error(titleKey: String, serverMessage: String?)
    case unknown
    case ready(SquareDetailPostFacts)
}

public enum SquareDetailCommentsState: Equatable, Sendable {
    case loading
    case empty
    case error(titleKey: String, serverMessage: String?)
    case unknown
    case ready(SquareDetailCommentPage)
}

public enum SquareDetailCommentList: Equatable, Sendable {
    case legacyRows
    case communityItems
    fileprivate var key: String {
        switch self {
        case .legacyRows: return "rows"
        case .communityItems: return "items"
        }
    }
}

public enum SquareDetailFlag: Equatable, Sendable {
    case unknown
    case no
    case yes
}

public struct SquareDetailPostFacts: Equatable, Sendable {
    public let id: Int
    public let likeCountText: String
    public let commentCountText: String
    public let dislikeCountText: String
    public let nodeTotalText: String
    public let nodeDoneText: String
    public let memberLevelText: String
    public let imageCountText: String
    public let bookmarked: SquareDetailFlag
    public let viewerCanComment: SquareDetailFlag
    /// This projection never sends a block, comment, like, or bookmark write.
    public var sends: Bool { false }
    public init(id: Int, likeCountText: String, commentCountText: String, dislikeCountText: String,
                nodeTotalText: String, nodeDoneText: String, memberLevelText: String, imageCountText: String,
                bookmarked: SquareDetailFlag, viewerCanComment: SquareDetailFlag) {
        self.id = id
        self.likeCountText = likeCountText
        self.commentCountText = commentCountText
        self.dislikeCountText = dislikeCountText
        self.nodeTotalText = nodeTotalText
        self.nodeDoneText = nodeDoneText
        self.memberLevelText = memberLevelText
        self.imageCountText = imageCountText
        self.bookmarked = bookmarked
        self.viewerCanComment = viewerCanComment
    }
}

public struct SquareDetailCommentFacts: Equatable, Sendable {
    public let id: Int
    public let likeCountText: String
    public init(id: Int, likeCountText: String) {
        self.id = id
        self.likeCountText = likeCountText
    }
}

public struct SquareDetailCommentPage: Equatable, Sendable {
    public let comments: [SquareDetailCommentFacts]
    public let hasMore: SquareDetailFlag
    public init(comments: [SquareDetailCommentFacts], hasMore: SquareDetailFlag) {
        self.comments = comments
        self.hasMore = hasMore
    }
}

private enum SquareDetailWire {
    enum Code: Equatable { case absent, malformed, value(Int) }

    static func trimmed(_ data: Data) -> Data {
        var bytes = data
        let whitespace = Set(" \n\r\t".utf8)
        while let first = bytes.first, whitespace.contains(first) { bytes.removeFirst() }
        while let last = bytes.last, whitespace.contains(last) { bytes.removeLast() }
        return bytes
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

    static func envelopeCode(_ value: Any?) -> Code {
        if value == nil || value is NSNull { return .absent }
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let number = Int(trimmed), trimmed == String(number), number >= 0 else { return .malformed }
            return .value(number)
        }
        guard let number = wholeNumber(value) else { return .malformed }
        return number >= 0 ? .value(number) : .malformed
    }

    /// A JSON integer, including 0. Numeric strings, booleans, and fractions are not integers.
    static func wholeNumber(_ value: Any?) -> Int? {
        // No `value is Bool`: on Darwin an NSNumber 0 or 1 bridges to Bool, which turned a real 0 or 1 into unknown.
        // The CFBoolean type check below is the exact test for a JSON true/false.
        guard let value, !(value is NSNull), !(value is String) else { return nil }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite, double.rounded() == double, double >= Double(Int.min), double <= Double(Int.max) else { return nil }
        return Int(double)
    }

    static func count(_ object: [String: Any], keys: [String]) -> String {
        for key in keys {
            guard object.keys.contains(key) else { continue }
            let value = object[key]
            if value == nil || value is NSNull { continue }
            return SquareDetailPageModel.countText(value)
        }
        return SquareDetailPageModel.unknownMark
    }

    /// Existing `memberLevelId` integer parse, including a numeric string. A missing level stays unknown.
    static func level(_ object: [String: Any], keys: [String]) -> String {
        for key in keys {
            guard object.keys.contains(key) else { continue }
            let value = object[key]
            if value == nil || value is NSNull { continue }
            if let number = wholeNumber(value) { return number >= 0 ? String(number) : SquareDetailPageModel.unknownMark }
            if let text = value as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let digits = trimmed.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
                if digits, let number = Int(trimmed), number >= 0 { return String(number) }
            }
            return SquareDetailPageModel.unknownMark
        }
        return SquareDetailPageModel.unknownMark
    }

    static func bookmark(_ value: Any?) -> SquareDetailFlag {
        guard let number = wholeNumber(value) else { return .unknown }
        if number == 1 { return .yes }
        if number == 0 { return .no }
        return .unknown
    }

    /// Absent `viewerCanComment` stays allowed, matching `SquarePost` (`null` or truthy).
    /// Truthy is JSON true, integer 1, or the string "1". Other present values stay not allowed.
    static func viewerCanComment(_ value: Any?) -> SquareDetailFlag {
        if value == nil || value is NSNull { return .yes }
        if let flag = value as? Bool { return flag ? .yes : .no }
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? .yes : .no }
        if wholeNumber(value) == 1 { return .yes }
        if let text = value as? String, text == "1" { return .yes }
        return .no
    }

    static func flag(_ value: Any?) -> SquareDetailFlag {
        if value == nil || value is NSNull { return .unknown }
        if let flag = value as? Bool { return flag ? .yes : .no }
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? .yes : .no }
        return .unknown
    }

    static func imageCount(_ root: [String: Any], post: [String: Any]) -> String {
        let media = root["media"]
        if let rows = media as? [Any] {
            let images = rows.compactMap { row -> String? in
                guard let object = row as? [String: Any] else { return nil }
                let kind = (object["media_type"] as? String) ?? (object["mediaType"] as? String) ?? "IMAGE"
                guard kind == "IMAGE" else { return nil }
                let key = (object["derived_object_key"] as? String) ?? (object["derivedObjectKey"] as? String)
                let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            if !images.isEmpty { return String(images.count) }
            if !root.keys.contains("pics") && !post.keys.contains("pics") { return "0" }
        } else if media != nil && !(media is NSNull) {
            return SquareDetailPageModel.unknownMark
        }
        let pics = post.keys.contains("pics") ? post["pics"] : root["pics"]
        let picsPresent = post.keys.contains("pics") || root.keys.contains("pics")
        if picsPresent {
            if pics == nil || pics is NSNull { return SquareDetailPageModel.unknownMark }
            if let count = pictureCount(pics) { return String(count) }
            return SquareDetailPageModel.unknownMark
        }
        return SquareDetailPageModel.unknownMark
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
}

#if DEBUG
/// Synthetic detail payloads. No host, token, or transport.
public enum SquareDetailPageFixtureData {
    public static let ready = #"{"id":701,"likeNum":12,"commentCount":3,"nolikeNum":0,"memberLevelId":"2","isBookmarked":0,"pics":"","nodeTotal":6,"nodeDoneCount":6}"#
    public static let unknownCounts = #"{"id":701,"likeNum":null,"commentCount":null,"nolikeNum":null,"nodeTotal":null,"nodeDoneCount":null}"#
    public static let literalZero = #"{"id":701,"likeCount":0,"commentCount":0,"nolikeNum":0,"nodeTotal":0,"nodeDoneCount":0,"memberLevelId":0,"isBookmarked":0,"pics":""}"#
    public static let numericStringCounts = #"{"id":701,"likeCount":"4","commentCount":"0","nodeTotal":"6"}"#
    public static let emptyObject = "{}"
    public static let envelope = #"{"code":200,"data":{"id":701,"likeCount":2}}"#
    public static let emptyComments = #"{"code":200,"data":{"rows":[]}}"#
    public static let unknownCommentList = #"{"code":200,"data":{}}"#
}
#endif
