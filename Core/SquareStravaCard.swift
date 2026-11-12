import Foundation

/// Strava-style activity block for a square or club post.
/// Missing numbers stay nil. Callers render `SquareCountDisplay.unknownMark` and never a made-up 0.
public struct SquareStravaCard: Equatable, Sendable {
    public let activityID: Int?
    public let name: String?
    public let distanceKilometers: Double?
    public let durationSeconds: Int?
    public let nodeDone: Int?
    public let nodeTotal: Int?
    /// Nil when the payload did not say whether the activity was cleared.
    public let cleared: Bool?
    public let route: [SquareRoutePoint]
    public let routeSourceText: String?
    public let topicID: Int?
    public let kudosAvatars: [String]
    public let kudosText: String?
    public let commentAuthor: String?
    public let commentBody: String?
    /// Nil hides follow. False offers it. True means the viewer already follows.
    public let followed: Bool?
    public let reposted: Bool?
    public let repostCount: Int?
    public let reposterName: String?

    public static let none = SquareStravaCard(
        activityID: nil, name: nil, distanceKilometers: nil, durationSeconds: nil,
        nodeDone: nil, nodeTotal: nil, cleared: nil, route: [], routeSourceText: nil, topicID: nil,
        kudosAvatars: [], kudosText: nil, commentAuthor: nil, commentBody: nil,
        followed: nil, reposted: nil, repostCount: nil, reposterName: nil)

    /// An activity id, name, distance, duration, or route. Node counts alone stay on the text card.
    public var showsActivity: Bool {
        activityID != nil || name != nil || distanceKilometers != nil || durationSeconds != nil || !route.isEmpty
    }

    static func decode(root: SquareValue, post: SquareValue, dataType: Int, dataID: Int?) -> SquareStravaCard {
        let explicitID = first(root, post, "activityId", "activity_id").integer
        let activityID = explicitID ?? (dataType == 1 ? dataID : nil)
        let name = first(root, post, "activityName", "activity_name").nonempty
        let distance = optionalKilometers(first(root, post, "distance", "distanceKm", "distance_km"))
        let duration = optionalCount(first(root, post, "durationSeconds", "duration_seconds", "duration"))
        let done = optionalCount(first(root, post, "nodeDoneCount", "doneCount"))
        let total = optionalCount(first(root, post, "nodeTotal", "node_total"))
        let cleared = optionalBool(first(root, post, "completed"))
        let routeValue = first(root, post, "routePolyline", "route_polyline")
        let route = points(routeValue.array == nil ? routeValue.parsedJSON : routeValue)
        let routeSourceText = first(root, post, "routeSourceText", "route_source_text").nonempty
        let topic = first(root, post, "sportTopicId", "topicId", "topic_id").integer
        let topicID = (topic ?? 0) > 0 ? topic : nil
        let kudos = avatars(first(root, post, "kudosUsers", "kudosAvatars", "kudos_users"))
        let kudosText = first(root, post, "kudosText", "kudos_text").nonempty
        let comment = first(root, post, "latestComment", "inlineComment", "latest_comment")
        let commentAuthor = comment.first("nickname", "memberNickname", "authorNickname").nonempty
        let commentBody = comment.first("content", "contents", "body").nonempty
        let followed = optionalBool(first(root, post, "isFollowTheUser", "viewerFollowing"))
        let reposted = optionalBool(first(root, post, "reposted", "viewerReposted"))
        let repostCount = optionalCount(first(root, post, "repostCount", "repost_count"))
        let reposterName = first(root, post, "reposterNick", "reposterName").nonempty
        return SquareStravaCard(
            activityID: activityID, name: name, distanceKilometers: distance, durationSeconds: duration,
            nodeDone: done, nodeTotal: total, cleared: cleared, route: route, routeSourceText: routeSourceText,
            topicID: topicID, kudosAvatars: kudos, kudosText: kudosText, commentAuthor: commentAuthor,
            commentBody: commentBody, followed: followed, reposted: reposted, repostCount: repostCount,
            reposterName: reposterName)
    }

    public static func decode(json: [String: Any], dataType: Int, dataID: Int?) -> SquareStravaCard {
        guard JSONSerialization.isValidJSONObject(json),
              let data = try? JSONSerialization.data(withJSONObject: json),
              let value = try? JSONDecoder().decode(SquareValue.self, from: data) else { return .none }
        return decode(root: value, post: .null, dataType: dataType, dataID: dataID)
    }

    public static func distanceText(_ kilometers: Double?) -> String {
        guard let kilometers, kilometers.isFinite, kilometers >= 0 else { return SquareCountDisplay.unknownMark }
        if kilometers == 0 { return "0 km" }
        if kilometers >= 100 || kilometers == kilometers.rounded(.towardZero) {
            return "\(Int(kilometers.rounded(.towardZero))) km"
        }
        return String(format: "%.1f km", kilometers)
    }

    public static func nodeText(done: Int?, total: Int?) -> String {
        guard let done, let total, done >= 0, total >= 0 else { return SquareCountDisplay.unknownMark }
        return "\(done)/\(total)"
    }

    public static func durationText(_ seconds: Int?) -> String {
        guard let seconds, seconds >= 0 else { return SquareCountDisplay.unknownMark }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(seconds)s"
    }

    private static func first(_ root: SquareValue, _ post: SquareValue, _ keys: String...) -> SquareValue {
        let fromRoot = lookup(root, keys)
        if !fromRoot.isNull { return fromRoot }
        return lookup(post, keys)
    }

    private static func lookup(_ value: SquareValue, _ keys: [String]) -> SquareValue {
        keys.lazy.map { value[$0] }.first { !$0.isNull } ?? .null
    }

    private static func optionalCount(_ value: SquareValue) -> Int? {
        guard !value.isNull, let number = value.number, number >= 0 else { return nil }
        return number
    }

    private static func optionalKilometers(_ value: SquareValue) -> Double? {
        guard !value.isNull, let number = value.finiteDouble, number.isFinite, number >= 0 else { return nil }
        return number
    }

    private static func optionalBool(_ value: SquareValue) -> Bool? {
        if value.isNull { return nil }
        if case .bool(let flag) = value { return flag }
        if value.number == 1 || value.string == "1" || value.string == "true" { return true }
        if value.number == 0 || value.string == "0" || value.string == "false" { return false }
        return nil
    }

    private static func points(_ value: SquareValue) -> [SquareRoutePoint] {
        guard let rows = value.array else { return [] }
        return rows.compactMap { item in
            if let pair = item.array, pair.count >= 2,
               let latitude = pair[0].finiteDouble, let longitude = pair[1].finiteDouble,
               valid(latitude, longitude) {
                return SquareRoutePoint(latitude: latitude, longitude: longitude)
            }
            guard let latitude = item.first("latitude", "lat").finiteDouble,
                  let longitude = item.first("longitude", "lng", "lon").finiteDouble,
                  valid(latitude, longitude) else { return nil }
            return SquareRoutePoint(latitude: latitude, longitude: longitude)
        }
    }

    private static func valid(_ latitude: Double, _ longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
    }

    private static func avatars(_ value: SquareValue) -> [String] {
        guard let rows = value.array else { return [] }
        return rows.compactMap { row in
            row.first("avatar", "memberAvatar", "authorAvatar").nonempty ?? row.nonempty
        }
    }
}

public struct SquareRoutePoint: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct SquareRouteUnitPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public enum SquareRouteCanvas {
    /// Unit box, north at the top. Fewer than two points draws nothing.
    public static func unitPoints(_ points: [SquareRoutePoint]) -> [SquareRouteUnitPoint] {
        guard points.count >= 2 else { return [] }
        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLng = longitudes.min(), let maxLng = longitudes.max() else { return [] }
        let latSpan = max(maxLat - minLat, 0.000_01)
        let lngSpan = max(maxLng - minLng, 0.000_01)
        return points.map { point in
            SquareRouteUnitPoint(
                x: (point.longitude - minLng) / lngSpan,
                y: 1 - (point.latitude - minLat) / latSpan)
        }
    }
}

/// `pages/square/utils/square-share.js`. A post that is not public contributes no body and no image.
public struct SquareShareCard: Equatable, Sendable {
    public static let genericTitle = "城瘾Hub"
    public static let titleLimit = 28
    public static let detailPage = "pages/square/detail/index"
    public static let genericPage = "pages/talent/list/index"
    public let title: String
    public let path: String
    public let imageURL: String?
    public let includesPost: Bool

    public static func build(id: Int, audience: String, lifecycle: String, contents: String?, images: [String]) -> SquareShareCard {
        guard id > 0, isPublic(audience: audience, lifecycle: lifecycle) else {
            return SquareShareCard(title: genericTitle, path: genericPage + "?tab=feed", imageURL: nil, includesPost: false)
        }
        let image = images.first { $0.hasPrefix("https://") || $0.hasPrefix("http://") }
        return SquareShareCard(title: title(contents), path: detailPage + "?id=\(id)", imageURL: image, includesPost: true)
    }

    public static func isPublic(audience: String, lifecycle: String) -> Bool {
        let audienceText = audience.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let life = lifecycle.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let audienceOK = audienceText.isEmpty || audienceText == "PUBLIC"
        let lifeOK = life.isEmpty || life == "PUBLISHED" || life == "1"
        return audienceOK && lifeOK
    }

    public static func title(_ contents: String?) -> String {
        let text = (contents ?? "").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if text.isEmpty { return genericTitle }
        if text.count <= titleLimit { return text }
        return String(text.prefix(titleLimit)) + "…"
    }
}

public struct SquareComposeActivityOption: Equatable, Identifiable, Sendable {
    public var id: String { activityID }
    public let activityID: String
    public let name: String
    public let dataType: Int
    public let sourceLabel: String
    public init(activityID: String, name: String, dataType: Int = 1, sourceLabel: String) {
        self.activityID = activityID
        self.name = name
        self.dataType = dataType
        self.sourceLabel = sourceLabel
    }
}

public struct SquareCompletedActivity: Equatable, Identifiable, Sendable {
    public var id: String { activityID }
    public let activityID: String
    public let name: String
    public let cover: String?
    public let doneCount: Int?
    public let total: Int?
    public let topicID: String?
    public init(activityID: String, name: String, cover: String?, doneCount: Int?, total: Int?, topicID: String?) {
        self.activityID = activityID
        self.name = name
        self.cover = cover
        self.doneCount = doneCount
        self.total = total
        self.topicID = topicID
    }
}

/// Joined and hosted rows from `cy/post-compose`, plus the completed-activity picker rows.
public enum SquareComposeActivityParse {
    public static func joinedRows(_ data: Any?) -> [SquareComposeActivityOption] {
        rows(data).compactMap { row in
            if let owner = row["ownerType"] ?? row["owner_type"], number(owner) != 2 { return nil }
            let act = row["cmsActivity"] as? [String: Any] ?? [:]
            let activityID = id(act["id"] ?? act["activityId"] ?? row["activityId"] ?? row["id"] ?? row["ownerId"])
            let name = text(act["name"] ?? row["activityTitle"] ?? row["name"])
            guard let activityID, let name else { return nil }
            return SquareComposeActivityOption(activityID: activityID, name: name, sourceLabel: "我参加的")
        }
    }

    public static func hostedRows(_ data: Any?) -> [SquareComposeActivityOption] {
        rows(data).compactMap { row in
            let activityID = id(row["activityId"] ?? row["id"] ?? row["ownerId"])
            let name = text(row["name"] ?? row["title"])
            guard let activityID, let name else { return nil }
            return SquareComposeActivityOption(activityID: activityID, name: name, sourceLabel: "我主办的")
        }
    }

    /// Hosted rows win the first slot. The same id is not listed twice.
    public static func merge(hosted: [SquareComposeActivityOption], joined: [SquareComposeActivityOption]) -> [SquareComposeActivityOption] {
        var seen: Set<String> = []
        var output: [SquareComposeActivityOption] = []
        for item in hosted + joined where seen.insert(item.activityID).inserted {
            output.append(item)
        }
        return output
    }

    public static func completedRows(_ data: Any?) -> [SquareCompletedActivity] {
        rows(data).compactMap { row in
            let activityID = id(row["activityId"] ?? row["id"])
            let name = text(row["name"] ?? row["title"])
            guard let activityID, let name else { return nil }
            let topic = id(row["topicId"] ?? row["topic_id"])
            return SquareCompletedActivity(
                activityID: activityID, name: name, cover: text(row["cover"] ?? row["coverUrl"]),
                doneCount: count(row["doneCount"] ?? row["nodeDoneCount"]),
                total: count(row["total"] ?? row["nodeTotal"]),
                topicID: topic)
        }
    }

    private static func rows(_ data: Any?) -> [[String: Any]] {
        if let rows = data as? [[String: Any]] { return rows }
        if let object = data as? [String: Any], let rows = object["rows"] as? [[String: Any]] { return rows }
        return []
    }

    private static func text(_ value: Any?) -> String? {
        guard let raw = value else { return nil }
        let trimmed = String(describing: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || raw is NSNull { return nil }
        return trimmed
    }

    private static func id(_ value: Any?) -> String? {
        if value is NSNull { return nil }
        if let number = value as? Int, number > 0 { return String(number) }
        if let number = value as? Double, number.isFinite, number > 0, number == number.rounded() { return String(Int(number)) }
        guard let text = text(value), text != "0" else { return nil }
        return text
    }

    private static func number(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? Double, number.isFinite { return Int(number) }
        if let text = text(value) { return Int(text) }
        return nil
    }

    /// Missing stays nil. A literal 0 stays 0.
    private static func count(_ value: Any?) -> Int? {
        guard !(value is NSNull), value != nil else { return nil }
        guard let number = number(value), number >= 0 else { return nil }
        return number
    }
}

public enum SquareComposeRules {
    public static let maxLength = 8000
    public static let maxPictures = 6
    public static let clubMaxPictures = 9

    public static func topicID(memberID: String, clubID: String?) -> String? {
        let member = memberID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !member.isEmpty else { return nil }
        if let clubID, !clubID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "club_post_\(clubID)_\(member)"
        }
        return "square_post_\(member)"
    }

    public static func clip(_ text: String) -> String { String(text.prefix(maxLength)) }

    /// Square posts need text. A new club post may be pictures only.
    public static func submittable(text: String, pictureCount: Int, club: Bool, editing: Bool) -> Bool {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return club && !editing && pictureCount > 0
    }

    public static func placeLine(name: String, address: String) -> String {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let line = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty && !line.isEmpty && title != line { return title + " · " + line }
        return title.isEmpty ? line : title
    }

    public static func chinaMonthDay(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600) ?? .gmt
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return "" }
        return "\(month)月\(day)日"
    }
}

public struct SquareComposeDraftEnvelope: Equatable, Sendable {
    public let memberID: String
    public let savedAt: Date
    public let contents: String
    public init(memberID: String, savedAt: Date, contents: String) {
        self.memberID = memberID
        self.savedAt = savedAt
        self.contents = contents
    }
}

public enum SquareComposeDraftRules {
    public enum Load: Equatable {
        case missing
        case ready(String)
        case memberMismatch
    }

    public static func load(_ envelope: SquareComposeDraftEnvelope?, memberID: String) -> Load {
        guard let envelope else { return .missing }
        guard envelope.memberID == memberID else { return .memberMismatch }
        let text = envelope.contents
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .missing : .ready(text)
    }
}

/// Unknown stays unknown. Confirming re-reads this record and never promotes it to a published post.
public struct SquareComposeLock: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case idle, sending, receipt, rejected, unknown }
    public let requestID: String?
    public var phase: Phase
    public var locksComposer: Bool { phase == .sending || phase == .unknown }

    public init(requestID: String? = nil, phase: Phase = .idle) {
        self.requestID = requestID
        self.phase = phase
    }

    /// Re-read by the saved request id. A different id is ignored. Unknown stays unknown.
    public func confirmResult(currentRequestID: String?, observed: Phase) -> SquareComposeLock {
        guard phase == .unknown, let requestID, requestID == currentRequestID else { return self }
        switch observed {
        case .receipt: return SquareComposeLock(requestID: requestID, phase: .receipt)
        case .rejected: return SquareComposeLock(requestID: requestID, phase: .rejected)
        case .idle, .sending, .unknown: return self
        }
    }
}

public enum SquarePostExcerpt {
    public static func text(_ raw: String?, limit: Int = 12) -> String {
        let flat = (raw ?? "").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if flat.isEmpty { return "(仅图片动态)" }
        if flat.count <= limit { return flat }
        return String(flat.prefix(limit)) + "…"
    }
}

public struct SquarePopoverAnchor: Equatable, Sendable {
    public var left: Double
    public var top: Double
    public var bottom: Double
    public init(left: Double, top: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.bottom = bottom
    }
}

public struct SquarePopoverPlacement: Equatable, Sendable {
    public var visible: Bool
    public var left: Double
    public var top: Double
    public var maxHeight: Double
    public init(visible: Bool, left: Double = 0, top: Double = 0, maxHeight: Double = 0) {
        self.visible = visible
        self.left = left
        self.top = top
        self.maxHeight = maxHeight
    }
}

/// `cy/popover`: next to the anchor, never centered, never stretched to the screen width.
public enum SquarePopoverLayout {
    public static let gap = 6.0
    public static let edge = 8.0

    public static func place(anchor: SquarePopoverAnchor?, panelWidth: Double, panelHeight: Double, windowWidth: Double, windowHeight: Double, minTop: Double, safeBottom: Double?) -> SquarePopoverPlacement {
        guard let anchor, anchor.left.isFinite, anchor.top.isFinite, panelWidth > 0, panelHeight > 0,
              windowWidth > 0, windowHeight > 0 else {
            return SquarePopoverPlacement(visible: false)
        }
        let bottomLimit = min(windowHeight - edge, (safeBottom ?? 0) > minTop ? (safeBottom ?? windowHeight - edge) : windowHeight - edge)
        let maxHeight = max(0, bottomLimit - minTop)
        if maxHeight <= 0 { return SquarePopoverPlacement(visible: false) }
        let below = anchor.bottom + gap
        let above = anchor.top - gap - panelHeight
        let flipUp = below + panelHeight > bottomLimit && above >= minTop
        let top = min(max(minTop, flipUp ? above : below), bottomLimit - panelHeight)
        let left = min(max(edge, anchor.left), windowWidth - panelWidth - edge)
        return SquarePopoverPlacement(visible: true, left: left, top: top, maxHeight: maxHeight)
    }
}
