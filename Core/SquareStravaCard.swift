import Foundation

/// One point on a supplied route preview. Values outside the geographic range are dropped.
public struct SquareRoutePoint: Equatable, Hashable {
    public let latitude: Double
    public let longitude: Double
    public init?(latitude: Double, longitude: Double) {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) <= 90, abs(longitude) <= 180 else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Fields the Strava card reads. Every metric stays nil when the payload omits it.
public struct SquareStravaAttachment: Equatable {
    public let activityID: Int?
    public let distanceKilometers: Double?
    public let durationSeconds: Int?
    public let nodeDone: Int?
    public let nodeTotal: Int?
    public let nodesProvided: Bool
    public let cleared: Bool
    public let kudosAvatars: [String]
    public let commentAuthor: String?
    public let commentBody: String?
    public let viewerFollowing: Bool?
    public let reposted: Bool?
    public let repostCount: Int?
    public let route: [SquareRoutePoint]
    public let hasActivity: Bool

    public init(root: SquareValue, post: SquareValue, dataType: Int, referenceType: String?) {
        activityID = root.first("activityId", "activity_id").positiveInt ?? post.first("activityId", "activity_id").positiveInt
        distanceKilometers = root.first("distance", "distanceKm").nonNegativeDouble ?? post.first("distance", "distanceKm").nonNegativeDouble
        durationSeconds = root.first("durationSeconds", "duration").wholeNonNegative ?? post.first("durationSeconds", "duration").wholeNonNegative
        let done = root.first("nodeDoneCount", "doneCount")
        let total = root.first("nodeTotal", "total")
        nodesProvided = !done.isNull || !total.isNull
        nodeDone = done.wholeNonNegative
        nodeTotal = total.wholeNonNegative
        cleared = root["completed"].truthy || post["completed"].truthy
        kudosAvatars = Self.avatars(root.first("kudosUsers", "kudosAvatars"))
        let comment = root.first("latestComment", "commentPreview")
        let author = comment.first("nickname", "memberNickname", "authorNickname").nonempty
        let body = comment.first("content", "contents", "body").nonempty
        commentAuthor = author
        commentBody = body
        viewerFollowing = Self.flag(root.first("isFollowTheUser", "viewerFollowing"))
        reposted = Self.flag(root.first("reposted", "isReposted"))
        repostCount = root.first("repostCount", "repost_count").wholeNonNegative
        route = Self.points(root.first("routePolyline", "routePoints"))
        hasActivity = activityID != nil || dataType == 1 || referenceType == "ACTIVITY"
    }

    public init(clubJSON json: [String: Any], refType: Int?) {
        let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        let root = (try? JSONDecoder().decode(SquareValue.self, from: data)) ?? .null
        let activity = refType == 1
        self.init(root: root, post: .null, dataType: activity ? 1 : 0, referenceType: activity ? "ACTIVITY" : nil)
    }

    private static func flag(_ value: SquareValue) -> Bool? {
        if value.isNull { return nil }
        if case .bool(let flag) = value { return flag }
        if value.number == 1 || value.string == "1" { return true }
        if value.number == 0 || value.string == "0" { return false }
        return nil
    }

    private static func avatars(_ value: SquareValue) -> [String] {
        guard let rows = value.array else { return [] }
        return rows.compactMap { row in
            if let url = row.nonempty { return url }
            return row.first("avatar", "memberAvatar", "authorAvatar").nonempty
        }
    }

    private static func points(_ value: SquareValue) -> [SquareRoutePoint] {
        guard let rows = value.array else { return [] }
        return rows.compactMap { row in
            if let pair = row.array, pair.count >= 2,
               let latitude = pair[0].nonNegativeLatitude, let longitude = pair[1].longitudeValue {
                return SquareRoutePoint(latitude: latitude, longitude: longitude)
            }
            guard let latitude = row.first("latitude", "lat").latitudeValue,
                  let longitude = row.first("longitude", "lng", "lon").longitudeValue else { return nil }
            return SquareRoutePoint(latitude: latitude, longitude: longitude)
        }
    }
}

private extension SquareValue {
    var latitudeValue: Double? {
        guard let value = finite else { return nil }
        return abs(value) <= 90 ? value : nil
    }
    var longitudeValue: Double? {
        guard let value = finite else { return nil }
        return abs(value) <= 180 ? value : nil
    }
    /// Pair form `[lat, lng]` uses this only for the first slot, which may be negative.
    var nonNegativeLatitude: Double? { latitudeValue }
    var finite: Double? {
        switch self {
        case .double(let value): return value.isFinite ? value : nil
        case .integer(let value): return Double(value)
        case .string(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = Double(trimmed), value.isFinite else { return nil }
            return value
        default: return nil
        }
    }
}

/// Display strings for the activity card. Unknown metrics are an em dash.
public struct SquareStravaFacts: Equatable {
    public let hasActivity: Bool
    public let title: String?
    public let distanceText: String
    public let paceText: String
    public let durationText: String
    public let cleared: Bool
    public let route: [SquareRoutePoint]
    public let showsRoute: Bool
    public let kudosAvatars: [String]
    public let commentAuthor: String?
    public let commentBody: String?
    public let viewerFollowing: Bool?
    public let reposted: Bool?
    public let repostCountText: String?
    public let likeText: String
    public let commentCountText: String
    public let liked: Bool

    public var showsKudos: Bool { !kudosAvatars.isEmpty }
    public var showsComment: Bool {
        guard let commentAuthor, let commentBody else { return false }
        return !commentAuthor.isEmpty && !commentBody.isEmpty
    }
    public var showsRepost: Bool { reposted != nil }
    public func showsFollow(viewerID: Int?, authorID: Int) -> Bool {
        viewerFollowing == false && authorID > 0 && (viewerID ?? 0) > 0 && viewerID != authorID
    }

    public init(post: SquarePost) {
        let attachment = post.strava
        hasActivity = attachment.hasActivity
        title = Self.nonempty(post.referenceTitle)
        distanceText = Self.distance(attachment.distanceKilometers)
        paceText = Self.pace(done: attachment.nodeDone, total: attachment.nodeTotal, provided: attachment.nodesProvided)
        durationText = Self.duration(attachment.durationSeconds)
        cleared = post.completed || attachment.cleared
        route = attachment.route
        showsRoute = SquareStravaRouteMap.showsLine(attachment.route)
        kudosAvatars = attachment.kudosAvatars
        commentAuthor = Self.nonempty(attachment.commentAuthor)
        commentBody = Self.nonempty(attachment.commentBody)
        viewerFollowing = attachment.viewerFollowing
        reposted = attachment.reposted
        repostCountText = attachment.repostCount.map(String.init)
        likeText = SquareCountDisplay.text(post.likeCount)
        commentCountText = SquareCountDisplay.text(post.commentCount)
        liked = post.isLiked == 1
    }

    public init(club post: ClubCommunityPost) {
        let attachment = post.strava
        hasActivity = attachment.hasActivity
        title = Self.nonempty(post.sportName)
        distanceText = Self.distance(attachment.distanceKilometers)
        paceText = Self.pace(done: attachment.nodeDone, total: attachment.nodeTotal, provided: attachment.nodesProvided)
        durationText = Self.duration(attachment.durationSeconds)
        cleared = attachment.cleared
        route = attachment.route
        showsRoute = SquareStravaRouteMap.showsLine(attachment.route)
        kudosAvatars = attachment.kudosAvatars
        commentAuthor = Self.nonempty(attachment.commentAuthor)
        commentBody = Self.nonempty(attachment.commentBody)
        viewerFollowing = attachment.viewerFollowing
        reposted = attachment.reposted
        repostCountText = attachment.repostCount.map(String.init)
        likeText = post.likeCount >= 0 ? String(post.likeCount) : SquareCountDisplay.unknownMark
        commentCountText = post.commentCount >= 0 ? String(post.commentCount) : SquareCountDisplay.unknownMark
        liked = post.liked
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
    public static func distance(_ kilometers: Double?) -> String {
        guard let kilometers, kilometers.isFinite, kilometers >= 0 else { return SquareCountDisplay.unknownMark }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), kilometers)
    }
    public static func pace(done: Int?, total: Int?, provided: Bool) -> String {
        guard provided else { return SquareCountDisplay.unknownMark }
        let left = done.map(String.init) ?? SquareCountDisplay.unknownMark
        let right = total.map(String.init) ?? SquareCountDisplay.unknownMark
        return left + "/" + right
    }
    public static func duration(_ seconds: Int?) -> String {
        guard let seconds, seconds >= 0 else { return SquareCountDisplay.unknownMark }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remain = seconds % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, remain) }
        return String(format: "%d:%02d", minutes, remain)
    }
}

public enum SquareStravaRouteMap {
    public static func showsLine(_ points: [SquareRoutePoint]) -> Bool {
        guard let first = points.first, points.count >= 2 else { return false }
        return points.contains { $0.latitude != first.latitude || $0.longitude != first.longitude }
    }
    /// Unit square, north up. Empty when the points are not a line.
    public static func unitPoints(_ points: [SquareRoutePoint]) -> [(x: Double, y: Double)] {
        guard showsLine(points) else { return [] }
        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        let spanLat = max(maxLat - minLat, 1e-9)
        let spanLon = max(maxLon - minLon, 1e-9)
        return points.map { (x: ($0.longitude - minLon) / spanLon, y: 1 - ($0.latitude - minLat) / spanLat) }
    }
}

/// A completed activity the composer can attach. Rows without an id and a name are dropped.
public struct SquareStravaActivityChoice: Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let topicID: Int?
    public let doneCount: Int?
    public let total: Int?
    public let cover: String?
    public init(id: Int, name: String, topicID: Int?, doneCount: Int?, total: Int?, cover: String?) {
        self.id = id
        self.name = name
        self.topicID = topicID
        self.doneCount = doneCount
        self.total = total
        self.cover = cover
    }
    public static func choices(from rows: [GrowthCompletedActivity]) -> [SquareStravaActivityChoice] {
        rows.compactMap { row in
            guard let id = row.activityID, id > 0, let name = row.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            return .init(id: id, name: name, topicID: row.topicID.flatMap { $0 > 0 ? $0 : nil }, doneCount: row.doneCount, total: row.total, cover: row.cover)
        }
    }
}

public enum SquareStravaActivityIssue: Error, Equatable {
    case offline, permission, notConfigured, failed
}

public struct SquareStravaDraft: Equatable, Codable, Identifiable {
    public let id: String
    public let accountID: Int
    public var text: String
    public var activityID: Int?
    public var activityName: String?
    public var savedAt: TimeInterval
    public var summary: String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return activityName ?? "" }
        return trimmed.count > 80 ? String(trimmed.prefix(80)) : trimmed
    }
}

public struct SquareStravaDraftBox: Equatable, Codable {
    public private(set) var drafts: [SquareStravaDraft]
    public init(drafts: [SquareStravaDraft] = []) { self.drafts = drafts }
    /// Stores one draft for this account. An empty body with no activity is not stored.
    public mutating func save(accountID: Int, text: String, activityID: Int?, activityName: String?, now: TimeInterval, id: String = UUID().uuidString) -> SquareStravaDraft? {
        guard accountID > 0, !id.isEmpty else { return nil }
        let body = text
        let name = activityName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosen = activityID.flatMap { $0 > 0 ? $0 : nil }
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && chosen == nil { return nil }
        let draft = SquareStravaDraft(id: id, accountID: accountID, text: body, activityID: chosen, activityName: name?.isEmpty == false ? name : nil, savedAt: now)
        drafts.removeAll { $0.id == id || $0.accountID != accountID }
        drafts.insert(draft, at: 0)
        if drafts.count > 20 { drafts = Array(drafts.prefix(20)) }
        return draft
    }
    public mutating func delete(id: String, accountID: Int) -> Bool {
        guard let index = drafts.firstIndex(where: { $0.id == id && $0.accountID == accountID }) else { return false }
        drafts.remove(at: index)
        return true
    }
}

/// What the repost writer knows immediately. Success is not one of these; only a later re-read can confirm.
public enum SquareStravaRepostStart: Equatable {
    case notSent, unknown, rejected
}

/// Re-read of one saved request. A different id never counts as success.
public enum SquareStravaReread: Equatable {
    case stillUnknown
    case rejected
    case confirmedSameRequest
    case differentRequest
}

public enum SquareStravaWritePhase: Equatable {
    case idle
    case locked(requestID: String)
    case rejected(requestID: String)
    case confirmed(requestID: String)
    case notSent
}

/// Unknown writes stay on the saved request id until a re-read of that same id confirms them.
public struct SquareStravaWriteLedger: Equatable {
    public private(set) var phase: SquareStravaWritePhase
    public init(phase: SquareStravaWritePhase = .idle) { self.phase = phase }
    public var lockedRequestID: String? { if case .locked(let id) = phase { return id }; return nil }
    public var locks: Bool { if case .locked = phase { return true }; return false }

    public mutating func noteUnknown(requestID: String) {
        guard Self.valid(requestID) else { return }
        phase = .locked(requestID: requestID)
    }
    public mutating func noteRejected(requestID: String) {
        guard Self.valid(requestID) else { return }
        phase = .rejected(requestID: requestID)
    }
    /// A write that never left the device is not an unknown result and does not clear a lock.
    public mutating func noteNotSent() {
        if case .locked = phase { return }
        phase = .notSent
    }
    public mutating func apply(reread: SquareStravaReread, savedRequestID: String) {
        guard case .locked(let id) = phase, id == savedRequestID, Self.valid(id) else { return }
        switch reread {
        case .stillUnknown, .differentRequest: phase = .locked(requestID: id)
        case .rejected: phase = .rejected(requestID: id)
        case .confirmedSameRequest: phase = .confirmed(requestID: id)
        }
    }
    public static func valid(_ id: String) -> Bool {
        (16...64).contains(id.utf8.count) && id.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) || byte == 45 || byte == 95
        }
    }
}
