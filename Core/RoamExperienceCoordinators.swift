import Foundation

public enum RoamRecoveryPhase: Equatable {
    case idle, loading, active, finished, incomplete, notFound, failed
}
@MainActor public final class RoamRecoveryCoordinator {
    public private(set) var phase: RoamRecoveryPhase = .idle
    public private(set) var fact: RoamSessionFact?
    public private(set) var error: Error?
    private let reader: any RoamExperienceReading
    private var generation = 0
    public init(reader: any RoamExperienceReading) { self.reader = reader }
    public func reset() { generation += 1; phase = .idle; fact = nil; error = nil }
    public func recover(_ query: RoamRecoveryQuery) async {
        generation += 1; let ticket = generation; let identity = reader.identity
        phase = .loading; fact = nil; error = nil
        do {
            try query.validate()
            guard identity != nil else { throw APIError.unauthorized }
            let value = try await reader.sessionFact(query)
            guard !Task.isCancelled, ticket == generation, reader.identity == identity else { return }
            guard query.matches(value) else { throw APIError.malformedResponse }
            fact = value
            switch value.state {
            case .active: phase = .active
            case .notFound: phase = .notFound
            case .finished: phase = value.hasCompleteSettlement ? .finished : .incomplete
            }
        } catch {
            guard !Task.isCancelled, ticket == generation, reader.identity == identity else { return }
            self.error = error; phase = .failed
        }
    }
}
/// Pagination advances on successful responses only, deduplicates by stamp identity, and keeps
/// prior rows on retryable page errors. Refresh and account changes invalidate all older completions.
@MainActor public final class RoamAlbumPager {
    public private(set) var stamps: [RoamAlbumStamp] = []
    public private(set) var hasMore = true
    public private(set) var loading = false
    public private(set) var error: Error?
    public private(set) var loaded = false
    /// Server total from the latest successful page; nil until a page is actually read.
    public private(set) var total: Int?
    private let reader: any RoamExperienceReading
    private var identity: RoamExperienceIdentity?
    private var nextPage = 1
    private var generation = 0
    private let pageSize: Int
    public init(reader: any RoamExperienceReading, pageSize: Int = 20) { self.reader = reader; self.pageSize = pageSize }
    public func reset() {
        generation += 1; identity = reader.identity; nextPage = 1
        stamps = []; hasMore = true; loading = false; error = nil; loaded = false; total = nil
    }
    /// Preserve rows when a detail is pushed; invalidate only unfinished work.
    public func cancelPending() { generation += 1; loading = false }
    public func loadNext() async {
        if identity != reader.identity { reset() }
        guard !loading, hasMore else { return }
        let ticket = generation, snapshot = reader.identity, page = nextPage
        loading = true; error = nil
        defer { if generation == ticket { loading = false } }
        do {
            guard snapshot != nil else { throw APIError.unauthorized }
            let result = try await reader.album(page: page, pageSize: pageSize)
            guard !Task.isCancelled, generation == ticket, reader.identity == snapshot else { return }
            guard result.pageNum == page, result.pageSize == pageSize else { throw APIError.malformedResponse }
            for stamp in result.list {
                stamps.removeAll { $0.id == stamp.id }
                if stamp.isVisible { stamps.append(stamp) }
            }
            hasMore = result.hasMore; nextPage += 1; loaded = true; total = result.total
        } catch {
            guard !Task.isCancelled, generation == ticket, reader.identity == snapshot else { return }
            if CollectionReadAccess(error) != nil {
                // A current login/permission refusal cannot keep private rows or
                // continue its old page. Explicit refresh starts over at page one.
                reset(); hasMore = false
            }
            self.error = error
        }
    }
}
/// Device integration boundary only. There is no concrete GPS implementation or permission prompt.
/// Search-area coordinates are deliberately a different type from a device fix.
public struct RoamDeviceFix: Equatable {
    public enum Datum: String { case wgs84, gcj02 }
    public let coordinate: RoamCoordinate
    public let accuracyMeters: Double
    public let measuredAt: Date
    public let datum: Datum
    public init(coordinate: RoamCoordinate, accuracyMeters: Double, measuredAt: Date, datum: Datum) throws {
        guard accuracyMeters.isFinite, accuracyMeters >= 0 else { throw APIError.invalidRequest }
        self.coordinate = coordinate; self.accuracyMeters = accuracyMeters; self.measuredAt = measuredAt; self.datum = datum
    }
}
@MainActor public protocol RoamDeviceLocationProviding: AnyObject {
    func currentFix() async throws -> RoamDeviceFix
    func stop()
    /// OWN-D-07.c: true only while this provider holds a session background hold (`SessionLocationHoldLedger`).
    var continuesInBackground: Bool { get }
}
public extension RoamDeviceLocationProviding {
    var continuesInBackground: Bool { false }
}
@MainActor public final class RoamLiveCoordinator {
    public enum Phase: Equatable { case ready, unavailable }
    public private(set) var phase: Phase = .ready
    public init() {}
    /// Purpose consent is necessary but insufficient; no sample or manual coordinate bypass exists.
    public func start(purposeAccepted: Bool) throws {
        guard purposeAccepted else { throw APIError.invalidRequest }
        phase = .unavailable
        throw RoamExperienceFailure.capabilityUnavailable
    }
}
/// Ephemeral draft only: never creates a stamp, assigns a serial or implies an exchange succeeded.
public struct RoamCityStampDraft: Equatable {
    public var caption = ""
    public init() {}
    public var remaining: Int { 30 - caption.utf16.count }
    public var canReview: Bool { RoamExperienceMath.validCaption(caption) }
}

/// Owner-scoped exploration memory only; never presence, visit evidence or territory ownership.
/// Retry the same cursor on failure; overlapping pages merge as a set. Refresh starts at zero
/// so another device's server-confirmed tiles can be recovered without a local journal.
@MainActor public final class RoamTileMemoryPager {
    public private(set) var tiles: Set<String> = []
    public private(set) var hasMore = true
    public private(set) var loading = false
    public private(set) var loaded = false
    public private(set) var error: Error?
    private let reader: any RoamExperienceReading
    private var identity: RoamExperienceIdentity?
    private var cursor = 0
    private var generation = 0
    private let limit = 1000
    public init(reader: any RoamExperienceReading) { self.reader = reader; identity = reader.identity }
    public func reset() {
        generation += 1; identity = reader.identity; cursor = 0
        tiles = []; hasMore = true; loading = false; loaded = false; error = nil
    }
    public func cancelPending() { generation += 1; loading = false }
    public func loadNext() async {
        if identity != reader.identity { reset() }
        guard !loading, hasMore else { return }
        let ticket = generation, snapshot = identity, afterID = cursor
        loading = true; error = nil
        defer { if generation == ticket { loading = false } }
        do {
            guard snapshot != nil else { throw APIError.unauthorized }
            guard reader.isConfigured else { throw APIError.notConfigured }
            let page = try await reader.tilePage(afterID: afterID, limit: limit)
            guard generation == ticket else { return }
            guard reader.identity == snapshot else { reset(); return }
            guard !Task.isCancelled else { return }
            guard page.tiles.count <= limit, page.nextAfterId >= afterID,
                  !page.hasMore || page.nextAfterId > afterID else { throw APIError.malformedResponse }
            tiles.formUnion(page.tiles); cursor = page.nextAfterId; hasMore = page.hasMore; loaded = true
        } catch {
            guard generation == ticket else { return }
            guard reader.identity == snapshot else { reset(); return }
            guard !Task.isCancelled else { return }
            if CollectionReadAccess(error) != nil {
                // A current access refusal cannot retain private exploration memory.
                // A later explicit refresh starts from the original zero cursor.
                reset(); hasMore = false
            }
            self.error = error
        }
    }
}

/// WP-09 / CT05.e: mileage counts only measured, accepted fixes. Interpolated (tolerance/gap-fill)
/// points are display-only and add no distance; jump-flagged fixes are dropped, not accumulated.
public struct RoamMileageAccumulator: Equatable {
    public enum Point: Equatable {
        case measured(MapCoordinateObservation)
        case interpolated(MapCoordinateObservation)
    }
    public private(set) var totalMeters: Double = 0
    public private(set) var flaggedCount = 0
    private var last: MapCoordinateObservation?
    public init() {}
    public mutating func add(_ point: Point) {
        guard case .measured(let next) = point else { return }
        if let previous = last {
            guard MapCoordinateJumpGuard.evaluate(previous: previous, next: next) == .accepted,
                  let d = try? MapCoordinateObservation.distanceMeters(previous, next) else { flaggedCount += 1; return }
            totalMeters += d
        }
        last = next
    }
}

/// Stamp-album page projection for the existing `api/roam/stamp/list` read.
///
/// Loading, empty, error, and unknown stay distinct. Unknown and empty totals are an em dash
/// (U+2014). A literal integer, including 0, is kept only when that integer is the server total
/// on a non-empty album. A numeric string is not a total and is never shown as 0. The visible
/// row count never replaces a missing total. This value does not register a route, mark a route
/// live, open a host, or reveal capture. Capture stays hidden while media upload is off.
public enum StampAlbumIndexPhase: String, Equatable, Sendable {
    case loading
    case empty
    case error
    case unknown
    case ready
}

public struct StampAlbumIndexPageState: Equatable, Sendable {
    public static let unknownText = "\u{2014}"
    public static let emptyText = "\u{2014}"

    public let phase: StampAlbumIndexPhase
    /// Headline count. Empty and unknown are an em dash. Loading is blank. Ready keeps a literal total.
    public let totalText: String
    /// Visible collage rows. Unknown and empty are an em dash, never a guessed 0.
    public let visibleText: String
    public let failure: String?
    /// `login` or `denied` when the existing read-access contract says so.
    public let access: String?
    public let continuationFailed: Bool
    public let slots: [StampAlbumCollageSlot]

    public var showsCapture: Bool { false }
    public var showsMerchantChoice: Bool { false }
    public var registersRoute: Bool { false }
    public var marksRouteLive: Bool { false }
    public var opensHost: Bool { false }

    init(phase: StampAlbumIndexPhase, totalText: String, visibleText: String, failure: String?,
         access: String?, continuationFailed: Bool, slots: [StampAlbumCollageSlot]) {
        self.phase = phase
        self.totalText = totalText
        self.visibleText = visibleText
        self.failure = failure
        self.access = access
        self.continuationFailed = continuationFailed
        self.slots = slots
    }
}

public enum StampAlbumIndexPageModel {
    public static let routePath = RoamAlbumMetadataReadRoute.path
    public static let registersRoute = false
    public static let marksRouteLive = false
    public static let opensHost = false
    public static let showsCapture = false
    public static let showsMerchantChoice = false
    public static let sourcePageSize = StampAlbumCollageSlot.sourcePageSize
    public static let fixturePageSize = StampAlbumCollageSlot.fixturePageSize
    public static let accessibilityIdentifiers = [
        "roam.experience.album",
        "roam.experience.album.total",
        "roam.experience.album.denied",
        "roam.experience.album.empty",
        "roam.experience.album.openCamera",
        "roam.experience.album.stamp",
        "roam.experience.album.more",
        "roam.experience.album.continuationRetry",
        "roam.experience.album.scopeExpired",
        "roam.experience.album.open",
        "roam.experience.error",
        "roam.experience.retry",
        "roam.experience.notice"
    ]

    /// Pager fields only. Does not start a read and does not invent a route.
    @MainActor public static func project(_ pager: RoamAlbumPager) -> StampAlbumIndexPageState {
        let failure = pager.error.map { failureToken($0) }
        let retains = pager.loaded && pager.error != nil && !pager.stamps.isEmpty
        return project(loading: pager.loading, loaded: pager.loaded, failure: failure,
                       serverTotal: pager.loaded ? pager.total : nil,
                       visibleCount: pager.loaded ? pager.stamps.count : nil, retainsRows: retains)
    }

    public static func project(data: Data, loading: Bool = false, failure: String? = nil) -> StampAlbumIndexPageState {
        if loading {
            return project(loading: true, loaded: false, failure: nil, serverTotal: nil, visibleCount: nil, retainsRows: false)
        }
        switch payload(data) {
        case .malformed:
            return project(loading: false, loaded: false, failure: failure ?? "malformed",
                           serverTotal: nil, visibleCount: nil, retainsRows: false)
        case .unreadable:
            return project(loading: false, loaded: false, failure: failure,
                           serverTotal: nil, visibleCount: nil, retainsRows: false)
        case .failed(let token):
            return project(loading: false, loaded: false, failure: failure ?? token,
                           serverTotal: nil, visibleCount: nil, retainsRows: false)
        case .page(let total, let visible):
            return project(loading: false, loaded: true, failure: failure, serverTotal: total,
                           visibleCount: visible, retainsRows: false)
        }
    }

    /// `loaded` is false until a page was actually read. A nil total on a loaded page is unknown.
    public static func project(loading: Bool, loaded: Bool, failure: String?, serverTotal: Int?,
                               visibleCount: Int?, retainsRows: Bool) -> StampAlbumIndexPageState {
        if loading { return make(.loading, "", "", nil, nil, false, []) }
        let total: AlbumTotal
        if loaded, let serverTotal, serverTotal >= 0 { total = .value(serverTotal) }
        else { total = .unknown }
        let visible = loaded ? visibleCount : nil
        return finish(failure: failure, total: total, visible: visible, retainsRows: retainsRows && loaded)
    }

    public static func failureToken(_ error: Error) -> String {
        switch error {
        case APIError.unauthorized: return "unauthorized"
        case APIError.notConfigured: return "notConfigured"
        case APIError.malformedResponse: return "malformed"
        case APIError.invalidRequest: return "invalidRequest"
        case APIError.invalidConfiguration: return "invalidConfiguration"
        case APIError.httpStatus(let code): return code == 403 ? "403" : "http.\(code)"
        case APIError.businessCode(let code): return code == 403 ? "403" : "business.\(code)"
        default: return "readFailed"
        }
    }

    private enum AlbumTotal: Equatable { case unknown, value(Int) }
    private enum Payload { case malformed, unreadable, failed(String), page(total: Int?, visible: Int?) }

    private static func finish(failure: String?, total: AlbumTotal, visible: Int?, retainsRows: Bool) -> StampAlbumIndexPageState {
        let dash = StampAlbumIndexPageState.unknownText
        if let failure {
            let classified = classify(failure)
            if classified.phase == .unknown { return make(.unknown, dash, dash, nil, nil, false, []) }
            if retainsRows, case .value(let number) = total, number > 0 {
                return make(.ready, String(number), visible.map(String.init) ?? dash, classified.text,
                            classified.access, true, slots(visible))
            }
            return make(.error, classified.text, dash, classified.text, classified.access, false, [])
        }
        switch total {
        case .unknown:
            return make(.unknown, dash, dash, nil, nil, false, [])
        case .value(let number):
            if number == 0 {
                guard visible == 0 else { return make(.unknown, dash, dash, nil, nil, false, []) }
                return make(.empty, dash, dash, nil, nil, false, [])
            }
            if let visible, visible > number { return make(.unknown, dash, dash, nil, nil, false, []) }
            return make(.ready, String(number), visible.map(String.init) ?? dash, nil, nil, false, slots(visible))
        }
    }

    private static func classify(_ token: String) -> (phase: StampAlbumIndexPhase, text: String, access: String?) {
        let dash = StampAlbumIndexPageState.unknownText
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.caseInsensitiveCompare("UNKNOWN") == .orderedSame || trimmed == dash || trimmed == "0" {
            return (.unknown, dash, nil)
        }
        let access: String?
        if trimmed == "unauthorized" || trimmed == "401" { access = "login" }
        else if trimmed == "403" { access = "denied" }
        else { access = nil }
        return (.error, trimmed, access)
    }

    private static func payload(_ data: Data) -> Payload {
        guard let wire = try? JSONDecoder().decode(PlayWireValue.self, from: data), case .object(let root) = wire else {
            return .malformed
        }
        guard root.keys.contains("code") else { return page(root) }
        guard case .integer(let code) = root["code"] ?? .null else { return .unreadable }
        if code == 200 {
            guard case .object(let body) = root["data"] ?? .null else { return .page(total: nil, visible: nil) }
            return page(body)
        }
        if code == 401 { return .failed("unauthorized") }
        if code == 403 { return .failed("403") }
        return .failed("business.\(code)")
    }

    private static func page(_ body: [String: PlayWireValue]) -> Payload {
        .page(total: literalTotal(body["total"] ?? .null), visible: visibleCount(body["list"] ?? .null))
    }

    /// Exact non-negative integer only. Strings, null, fractions, and negatives stay unknown.
    private static func literalTotal(_ value: PlayWireValue) -> Int? {
        switch value {
        case .integer(let raw):
            guard let number = Int(exactly: raw), number >= 0 else { return nil }
            return number
        case .number(let raw):
            guard raw.isFinite, raw >= 0, raw <= 9_007_199_254_740_991 else { return nil }
            let number = Int(raw)
            guard Double(number) == raw else { return nil }
            return number
        case .string, .bool, .array, .object, .null:
            return nil
        }
    }

    /// A present array yields a count of visible stamps. Any other list shape is unknown, not 0.
    /// Duplicate visible ids withhold the count. Unknown moderation states stay hidden via `isVisible`.
    private static func visibleCount(_ value: PlayWireValue) -> Int? {
        guard case .array(let rows) = value else { return nil }
        var seen: [Int] = []
        for row in rows {
            guard case .object(let fields) = row, let stamp = stamp(fields), stamp.isVisible else { continue }
            if seen.contains(stamp.id) { return nil }
            seen.append(stamp.id)
        }
        return seen.count
    }

    private static func stamp(_ fields: [String: PlayWireValue]) -> RoamAlbumStamp? {
        guard let data = try? JSONEncoder().encode(PlayWireValue.object(fields)) else { return nil }
        return try? JSONDecoder().decode(RoamAlbumStamp.self, from: data)
    }

    private static func slots(_ count: Int?) -> [StampAlbumCollageSlot] {
        guard let count, (0...100).contains(count) else { return [] }
        return (0..<count).map { StampAlbumCollageSlot(index: $0) }
    }

    private static func make(_ phase: StampAlbumIndexPhase, _ total: String, _ visible: String, _ failure: String?,
                             _ access: String?, _ continuation: Bool, _ slots: [StampAlbumCollageSlot]) -> StampAlbumIndexPageState {
        StampAlbumIndexPageState(phase: phase, totalText: total, visibleText: visible, failure: failure,
                                 access: access, continuationFailed: continuation, slots: slots)
    }
}

#if DEBUG
/// Synthetic album bytes for the existing list contract. No account, photo, host, or route.
public enum StampAlbumIndexFixtureData {
    public static let content = Data(RoamExperienceSyntheticFixtures.album.utf8)
    public static let empty = Data(#"{"list":[],"total":0,"pageNum":1,"pageSize":20}"#.utf8)
    public static let unknownTotal = Data(#"{"list":[{"id":901,"picUrl":"","checkState":0}],"total":"UNKNOWN","pageNum":1,"pageSize":20}"#.utf8)
    public static let numericStringZero = Data(#"{"list":[],"total":"0","pageNum":1,"pageSize":20}"#.utf8)
    public static let missingTotal = Data(#"{"list":[{"id":901,"picUrl":"","checkState":0}],"pageNum":1,"pageSize":20}"#.utf8)
    public static let denied = Data(#"{"code":403,"data":null}"#.utf8)
}
#endif
