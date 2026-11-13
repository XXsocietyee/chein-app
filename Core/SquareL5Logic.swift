import Foundation

/// `pages/square/utils/square-share.js`. A forward card is built only for a public published post.
/// Anything else falls back to the generic feed card, with no body and no image.
public enum SquareL5ShareCard {
    public static let genericTitle = "城瘾Hub"
    public static let genericPath = "/pages/talent/list/index?tab=feed"
    public static let titleLimit = 28

    public struct Card: Equatable {
        public let title: String
        public let path: String
        public let imageURL: String?
        public init(title: String, path: String, imageURL: String?) {
            self.title = title
            self.path = path
            self.imageURL = imageURL
        }
    }

    public struct Post: Equatable {
        public let id: String?
        /// Nil means the field is absent. Absent audience is treated as public.
        public let audience: String?
        /// Nil means the field is absent. Absent status is allowed. Any other value must be 1.
        public let status: String?
        public let contents: String?
        public let pics: String?
        public let picList: [String]?
        public init(id: String?, audience: String?, status: String?, contents: String?, pics: String?, picList: [String]?) {
            self.id = id
            self.audience = audience
            self.status = status
            self.contents = contents
            self.pics = pics
            self.picList = picList
        }
    }

    public static func isPubliclyShareable(_ post: Post?) -> Bool {
        guard let post, let id = post.id, !id.isEmpty else { return false }
        if let audience = post.audience, audience.uppercased() != "PUBLIC" { return false }
        if let status = post.status, Double(status.trimmingCharacters(in: .whitespacesAndNewlines)) != 1 { return false }
        return true
    }

    public static func build(_ post: Post?) -> Card {
        guard let post, isPubliclyShareable(post), let id = post.id else {
            return Card(title: genericTitle, path: genericPath, imageURL: nil)
        }
        let text = (post.contents ?? "").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let title: String
        if text.isEmpty { title = genericTitle }
        else if text.utf16.count > titleLimit {
            title = utf16Prefix(text, titleLimit) + "…"
        } else { title = text }
        let encoded = percentEncode(id)
        var card = Card(title: title, path: "/pages/square/detail/index?id=\(encoded)", imageURL: nil)
        if let image = firstPicture(post) { card = Card(title: card.title, path: card.path, imageURL: image) }
        return card
    }

    private static func firstPicture(_ post: Post) -> String? {
        let list = (post.picList?.isEmpty == false ? post.picList! : (post.pics ?? "").split(separator: ";").map(String.init))
        guard let pic = list.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              pic.hasPrefix("https://") || pic.hasPrefix("http://") else { return nil }
        return pic
    }

    private static func utf16Prefix(_ text: String, _ count: Int) -> String {
        var units = Array(text.utf16.prefix(count))
        if let last = units.last, Unicode.UTF16.isLeadSurrogate(last) { units.removeLast() }
        return String(decoding: units, as: Unicode.UTF16.self)
    }

    private static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.!~*'()")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

/// Square detail follow. The intended 0/1 is frozen before the request.
/// A comment-row follow only means "follow" (`follow: 1`) and is idempotent.
/// An in-flight request is not started again. Failure does not invert the shown state.
public struct SquareFollowWrite: Equatable {
    public static let path = "api/user/follow/action"
    public let memberID: Int
    public let follow: Int

    public init(memberID: Int, follow: Int) {
        self.memberID = memberID
        self.follow = follow
    }

    public static func toggle(memberID: Int, isFollowing: Bool, inFlight: Bool) -> SquareFollowWrite? {
        guard memberID > 0, !inFlight else { return nil }
        return SquareFollowWrite(memberID: memberID, follow: isFollowing ? 0 : 1)
    }

    public static func commentFollow(memberID: Int, inFlight: Bool) -> SquareFollowWrite? {
        guard memberID > 0, !inFlight else { return nil }
        return SquareFollowWrite(memberID: memberID, follow: 1)
    }

    /// The row becomes the frozen intent, never the opposite of whatever the server last showed.
    public static func displayedFollowing(intended: Int) -> Int { intended }

    public var fields: [String: String] {
        ["follow_member_id": String(memberID), "follow": String(follow)]
    }
}

/// `cy-post-drafts`. The sheet does not read storage. A bad index does nothing.
/// Delete is reported immediately; the page owns the undo window.
public enum SquareDraftSheet {
    public struct Row: Equatable {
        public let index: Int
        public let key: String
        public init(index: Int, key: String) {
            self.index = index
            self.key = key
        }
    }

    public static func row(keys: [String], index: Int?) -> Row? {
        guard let index, index >= 0, index < keys.count else { return nil }
        return Row(index: index, key: keys[index])
    }

    public static func select(keys: [String], index: Int?) -> Row? { row(keys: keys, index: index) }

    public static func delete(keys: [String], index: Int?) -> Row? { row(keys: keys, index: index) }
}

/// Activity picker (`pages/square/components/activity-picker`).
/// No topic selects immediately. A topic starts one preview; the first finish wins.
/// Closing or a newer selection retires the previous preview.
public struct SquareActivityPicker: Equatable {
    public struct Activity: Equatable {
        public let id: Int
        public let topicID: String?
        public init(id: Int, topicID: String?) {
            self.id = id
            self.topicID = topicID
        }
    }

    public enum Decision: Equatable {
        case immediate(Activity)
        case preview(Activity, generation: Int)
    }

    public private(set) var loading = false
    public private(set) var loaded = false
    public private(set) var error: String?
    public private(set) var activities: [Activity] = []
    public private(set) var generation = 0
    public private(set) var pending: Activity?
    private var snapshottedGeneration: Int?

    public init() {}

    public static let loadError = "活动列表加载失败，请重试"
    public static let completedPath = "api/play/my-completed"

    /// False when a fetch is already in flight, matching the source early return.
    public mutating func beginFetch() -> Bool {
        guard !loading else { return false }
        loading = true
        error = nil
        return true
    }

    public mutating func endFetch(activities: [Activity]?) {
        loading = false
        if let activities {
            self.activities = activities
            loaded = true
            error = nil
        } else {
            self.activities = []
            loaded = false
            error = Self.loadError
        }
    }

    public mutating func select(index: Int) -> Decision? {
        guard index >= 0, index < activities.count else { return nil }
        let activity = activities[index]
        guard let topic = activity.topicID, !topic.isEmpty else { return .immediate(activity) }
        generation += 1
        pending = activity
        return .preview(activity, generation: generation)
    }

    /// One snapshot per generation. A repeated ready event does not upload twice.
    public mutating func beginSnapshot(generation: Int) -> Bool {
        guard pending != nil, generation == self.generation, snapshottedGeneration != generation else { return false }
        snapshottedGeneration = generation
        return true
    }

    /// Timeout, empty route, or a finished upload. A stale generation or a second finish returns nil.
    public mutating func finish(generation: Int) -> Activity? {
        guard let pending, generation == self.generation else { return nil }
        self.pending = nil
        return pending
    }

    public mutating func close() {
        generation += 1
        pending = nil
    }

    /// Rows for the square picker. A missing name is an em dash. A missing count stays nil.
    /// An id that is missing or not positive is not a row.
    public struct PublicReferenceRow: Equatable, Sendable {
        public let id: Int
        public let name: String
        public let cover: String?
        public let doneCount: Int?
        public let total: Int?
        public let topicID: Int?
        public init(id: Int, name: String, cover: String?, doneCount: Int?, total: Int?, topicID: Int?) {
            self.id = id
            self.name = name
            self.cover = cover
            self.doneCount = doneCount
            self.total = total
            self.topicID = topicID
        }
    }

    public static func publicReferenceRows(_ records: [CompletedPlayRecord]) -> [PublicReferenceRow] {
        records.compactMap { record in
            guard let id = record.activityID, id > 0 else { return nil }
            let name = record.name ?? SquareCountDisplay.unknownMark
            let topic = record.topicID.flatMap { $0 > 0 ? $0 : nil }
            return PublicReferenceRow(id: id, name: name, cover: record.cover, doneCount: record.doneCount, total: record.total, topicID: topic)
        }
    }
}

/// `utils/topic-route-preview.js` `build`. Verified road geometry is drawn as a road.
/// Any invalid road point drops the whole chapter back to a straight node preview.
/// This does not compute distance, time, GPS validity, or rewards.
public enum SquareRouteMap {
    public enum Value: Equatable {
        case number(Double)
        case text(String)
        case other
    }

    public struct Node: Equatable {
        public var latitude: Value?
        public var lat: Value?
        public var longitude: Value?
        public var lng: Value?
        public var name: String?
        public var sortID: Double
        public init(latitude: Value? = nil, lat: Value? = nil, longitude: Value? = nil, lng: Value? = nil, name: String? = nil, sortID: Double = 0) {
            self.latitude = latitude
            self.lat = lat
            self.longitude = longitude
            self.lng = lng
            self.name = name
            self.sortID = sortID
        }
    }

    public struct Chapter: Equatable {
        public var nodes: [Node]
        public var routeGeometryAvailable: Bool
        public var routeGeometryError: Bool
        /// Nil means the geometry could not be parsed. An empty array is parsed and unused.
        public var routeGeometry: [Node]?
        public init(nodes: [Node], routeGeometryAvailable: Bool = false, routeGeometryError: Bool = false, routeGeometry: [Node]? = nil) {
            self.nodes = nodes
            self.routeGeometryAvailable = routeGeometryAvailable
            self.routeGeometryError = routeGeometryError
            self.routeGeometry = routeGeometry
        }
    }

    public struct Point: Equatable {
        public let latitude: Double
        public let longitude: Double
        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    public struct Line: Equatable {
        public let points: [Point]
        public let road: Bool
        public init(points: [Point], road: Bool) {
            self.points = points
            self.road = road
        }
    }

    public struct Marker: Equatable {
        public let id: Int
        public let point: Point
        public let callout: String
        public init(id: Int, point: Point, callout: String) {
            self.id = id
            self.point = point
            self.callout = callout
        }
    }

    public struct View: Equatable {
        public let routeReady: Bool
        public let routeIsRoad: Bool
        public let routeSourceText: String
        public let markers: [Marker]
        public let lines: [Line]
        public let include: [Point]
        public let latitude: Double
        public let longitude: Double
    }

    public static let topicPath = "api/topic/info-to-user"

    public static func coordinate(_ value: Value?, limit: Double) -> Double? {
        switch value {
        case .number(let number):
            return number.isFinite && abs(number) <= limit ? number : nil
        case .text(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.range(of: #"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$"#, options: .regularExpression) != nil,
                  let number = Double(trimmed), number.isFinite, abs(number) <= limit else { return nil }
            return number
        case .other, nil:
            return nil
        }
    }

    public static func point(_ node: Node) -> Point? {
        let latitude = coordinate(node.latitude ?? node.lat, limit: 90)
        let longitude = coordinate(node.longitude ?? node.lng, limit: 180)
        guard let latitude, let longitude else { return nil }
        return Point(latitude: latitude, longitude: longitude)
    }

    public static func build(_ chapters: [Chapter]) -> View {
        var valid: [Node] = []
        var lines: [Line] = []
        var roadSegments = 0
        var straightSegments = 0
        for chapter in chapters {
            let nodes = chapter.nodes.filter { point($0) != nil }.sorted { $0.sortID < $1.sortID }
            valid.append(contentsOf: nodes)
            var roadPoints: [Point] = []
            if chapter.routeGeometryAvailable && !chapter.routeGeometryError, let geometry = chapter.routeGeometry, geometry.count >= 2 {
                if geometry.allSatisfy({ point($0) != nil }) {
                    roadPoints = geometry.compactMap { point($0) }
                }
            }
            let road = roadPoints.count >= 2
            let points = road ? roadPoints : nodes.compactMap { point($0) }
            if road { roadSegments += 1 }
            if points.count >= 2 {
                if !road { straightSegments += 1 }
                lines.append(Line(points: points, road: road))
            }
        }
        let markers = valid.enumerated().compactMap { index, node -> Marker? in
            guard let markerPoint = point(node) else { return nil }
            let callout = "\(index + 1)" + (node.name.map { " \($0)" } ?? "")
            return Marker(id: index, point: markerPoint, callout: callout)
        }
        var include = markers.map(\.point)
        for line in lines { include.append(contentsOf: line.points) }
        let source: String
        if roadSegments > 0 {
            source = straightSegments > 0 ? "道路段参考 · 虚线为节点直线预览，章间未规划" : "道路段参考 · 按章节分段，章间未规划"
        } else if straightSegments > 0 {
            source = "节点直线预览 · 尚未规划步行路线，章间未规划"
        } else {
            source = "仅显示节点位置 · 尚未规划步行路线，章间未规划"
        }
        return View(
            routeReady: !include.isEmpty,
            routeIsRoad: roadSegments > 0 && straightSegments == 0,
            routeSourceText: include.isEmpty ? "" : source,
            markers: markers,
            lines: lines,
            include: include,
            latitude: include.first?.latitude ?? 0,
            longitude: include.first?.longitude ?? 0
        )
    }
}
