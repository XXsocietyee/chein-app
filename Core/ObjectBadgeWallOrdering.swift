import Foundation

/// Mini-program badge wall (subpackageP3/pages/badge-wall/index) lists 已点亮 before 未解锁
/// (`BADGE_SECTIONS`). Identity cards are the only badges that can be locked, so the native list
/// shows lit identity cards first and keeps the server order inside each group. Nothing is
/// dropped, duplicated or re-labelled.
public enum ObjectBadgeWallOrdering {
    public static func litFirst(_ identities: [ProfileIdentityBadge]) -> [ProfileIdentityBadge] {
        identities.filter(\.unlocked) + identities.filter { !$0.unlocked }
    }
}

/// Page state for the badge wall. Counts that the server did not return stay an em dash.
/// A literal zero stays "0". This type does not open a route; it only classifies
/// `ProfileReading.profileBadges()`, the existing wall read.
public struct ObjectBadgeWallPageCounts: Equatable {
    public static let unknownMark = "—"
    public let unlocked: String
    public let total: String
    public let waiting: String
    public static let unknown = ObjectBadgeWallPageCounts(unlocked: unknownMark, total: unknownMark, waiting: unknownMark)
    public var isUnknown: Bool { self == .unknown }
    public var accessibilityIdentifier: String { isUnknown ? "badgeWall.count.unknown" : "badgeWall.count.known" }
    private init(unlocked: String, total: String, waiting: String) {
        self.unlocked = unlocked
        self.total = total
        self.waiting = waiting
    }
    /// Rejects a negative or inconsistent triple. Callers must not replace that with 0.
    public static func known(unlocked: Int, total: Int, waiting: Int) -> ObjectBadgeWallPageCounts? {
        guard unlocked >= 0, total >= 0, waiting >= 0, total >= unlocked, waiting == total - unlocked else { return nil }
        return ObjectBadgeWallPageCounts(unlocked: String(unlocked), total: String(total), waiting: String(waiting))
    }
}

public enum ObjectBadgeWallPageFailure: Equatable {
    case unauthorized, denied, malformed, unavailable
    public var titleKey: String {
        switch self {
        case .unauthorized: return "badgeWall.state.signIn"
        case .denied: return "badgeWall.state.denied"
        case .malformed: return "badgeWall.state.malformed"
        case .unavailable: return "badgeWall.state.error"
        }
    }
    public var canRetry: Bool { self != .unauthorized }
    public var retryKey: String? { canRetry ? "badgeWall.state.retry" : nil }
    public static func classify(_ error: Error) -> ObjectBadgeWallPageFailure {
        if let failure = error as? ProfileReadFailure {
            if failure.isUnauthorized { return .unauthorized }
            if failure.isDenied { return .denied }
            return .unavailable
        }
        guard let api = error as? APIError else { return .unavailable }
        switch api {
        case .unauthorized: return .unauthorized
        case .httpStatus(403), .businessCode(403): return .denied
        case .malformedResponse: return .malformed
        default: return .unavailable
        }
    }
}

public enum ObjectBadgeWallPageState: Equatable {
    case hidden
    case loading
    case empty(ObjectBadgeWallPageCounts)
    case error(ObjectBadgeWallPageFailure)
    case unknown(ObjectBadgeWallPageCounts, identities: [ProfileIdentityBadge])
    case ready(ObjectBadgeWallPageCounts, identities: [ProfileIdentityBadge], medals: [ProfileMedal])

    /// A missing session or an unconfigured reader stays hidden. A medal collection that
    /// never arrived is unknown, including when no identity card arrived either.
    public static func project(_ wall: ProfileBadgeWall) -> ObjectBadgeWallPageState {
        let identities = ObjectBadgeWallOrdering.litFirst(wall.identities)
        guard let medals = wall.medals else { return .unknown(.unknown, identities: identities) }
        let unlocked = identities.filter(\.unlocked).count + medals.count
        let total = identities.count + medals.count
        guard let counts = ObjectBadgeWallPageCounts.known(unlocked: unlocked, total: total, waiting: total - unlocked) else {
            return .unknown(.unknown, identities: identities)
        }
        if identities.isEmpty && medals.isEmpty { return .empty(counts) }
        return .ready(counts, identities: identities, medals: medals)
    }

    public var counts: ObjectBadgeWallPageCounts {
        switch self {
        case .empty(let counts), .unknown(let counts, _), .ready(let counts, _, _): return counts
        case .hidden, .loading, .error: return .unknown
        }
    }
    public var titleKey: String? {
        switch self {
        case .hidden: return nil
        case .loading: return "badgeWall.state.loading"
        case .empty: return "badgeWall.state.empty"
        case .error(let failure): return failure.titleKey
        case .unknown: return "badgeWall.state.unknown"
        case .ready: return "profile.badges.title"
        }
    }
    public var detailKey: String? {
        if case .unknown = self { return "badgeWall.state.unknownDetail" }
        return nil
    }
    public var accessibilityIdentifier: String {
        switch self {
        case .hidden: return "badgeWall.state.hidden"
        case .loading: return "badgeWall.state.loading"
        case .empty: return "badgeWall.state.empty"
        case .error: return "badgeWall.state.error"
        case .unknown: return "badgeWall.state.unknown"
        case .ready: return "badgeWall.state.ready"
        }
    }
    public var orderedIdentityCodes: [String] {
        switch self {
        case .unknown(_, let identities): return identities.map(\.badgeCode)
        case .ready(_, let identities, _): return identities.map(\.badgeCode)
        case .hidden, .loading, .empty, .error: return []
        }
    }
}

/// Loads the existing badge-wall read. Signed-out and unconfigured readers stay hidden
/// and do not start that read. A late result from another account is discarded.
@MainActor public final class ObjectBadgeWallPageCoordinator {
    public private(set) var state: ObjectBadgeWallPageState = .hidden
    private var generation: UInt64 = 0
    public init() {}
    public func load(reader: any ProfileReading) async {
        generation &+= 1
        let ticket = generation
        guard reader.isConfigured, let identity = reader.identity else {
            state = .hidden
            return
        }
        state = .loading
        do {
            let wall = try await reader.profileBadges()
            guard ticket == generation, !Task.isCancelled else { return }
            guard reader.isConfigured, reader.identity == identity else {
                state = .hidden
                return
            }
            state = ObjectBadgeWallPageState.project(wall)
        } catch is CancellationError {
            return
        } catch {
            guard ticket == generation, !Task.isCancelled else { return }
            guard reader.isConfigured, reader.identity == identity else {
                state = .hidden
                return
            }
            if error as? APIError == .notConfigured {
                state = .hidden
                return
            }
            state = .error(.classify(error))
        }
    }
}

#if DEBUG
/// Offline badge-wall payloads. Release builds omit this type. Nothing here is a route.
public enum ObjectBadgeWallFixtureData {
    public static let readyIdentityJSON = #"[{"badgeCode":"FIXTURE-LOCKED","badgeName":"Fixture locked","category":"CREATE","statement":"Synthetic identity card","unlockHint":"Synthetic unlock condition","unlocked":false},{"badgeCode":"FIXTURE-LIT","badgeName":"Fixture lit","category":"EXPLORE","unlocked":true,"unlockTime":"2026-10-01 09:00:00"}]"#
    public static let readyMedalJSON = #"[{"templateId":921,"medalName":"Fixture city medal","style":"enamel","condition":"Synthetic city condition","getTime":"2026-10-01 10:00:00","kind":"city","badgeCode":"FIXTURE-CITY"},{"templateId":922,"medalName":"Fixture achievement","kind":"achievement","getTime":"2026-10-01 10:00:00","badgeCode":"FIXTURE-ACH"}]"#
    public static func readyWall() throws -> ProfileBadgeWall {
        ProfileBadgeWall(identities: try decode([ProfileIdentityBadge].self, readyIdentityJSON),
                         medals: try decode([ProfileMedal].self, readyMedalJSON))
    }
    public static func emptyWall() -> ProfileBadgeWall {
        ProfileBadgeWall(identities: [], medals: [])
    }
    public static func unknownWall() throws -> ProfileBadgeWall {
        ProfileBadgeWall(identities: try decode([ProfileIdentityBadge].self, readyIdentityJSON), medals: nil,
                         medalReadRestriction: .unavailable)
    }
    private static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
#endif
