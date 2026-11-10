import Foundation

/// The viewer's own place on `api/growth/leaderboard`. The source fills an unranked `me` with
/// score 0 and "TOP100%" (no rank row, or no ranked members yet); neither is evidence, so only a
/// ranked row keeps its score and bucket. Outside the returned Top N keeps the real rank/score.
public enum GrowthLeaderboardStanding: Equatable {
    case listed(rank: Int, score: Int?)
    case outsideList(rank: Int, score: Int?)
    case unknown
    public init(board: GrowthLeaderboard) {
        guard let rank = board.me.rank, rank > 0 else { self = .unknown; return }
        self = rank <= board.list.count ? .listed(rank: rank, score: board.me.score) : .outsideList(rank: rank, score: board.me.score)
    }
    public var rank: Int? {
        switch self { case .listed(let rank, _), .outsideList(let rank, _): return rank; case .unknown: return nil }
    }
    public var score: Int? {
        switch self { case .listed(_, let score), .outsideList(_, let score): return score; case .unknown: return nil }
    }
}

public extension GrowthLeaderboard {
    var standing: GrowthLeaderboardStanding { .init(board: self) }
}

extension GrowthLeaderboard {
    /// Normalize the service's unranked presentation, not the raw wire decoder.
    /// Nil and nonpositive ranks must also omit the personal rank row; otherwise
    /// optional-only UI consumers display a synthetic zero/negative place.
    func withoutUnrankedPlaceholders() -> GrowthLeaderboard {
        guard me.rank.map({ $0 <= 0 }) ?? true else { return self }
        return GrowthLeaderboard(metric: metric, period: period, list: list,
            me: GrowthLeaderboardEntry(rank: nil, memberID: me.memberID, nickname: me.nickname, avatar: me.avatar, score: nil, rankPercentage: nil))
    }
}

extension GrowthLeaderboardEntry {
    init(rank: Int?, memberID: Int?, nickname: String?, avatar: String?, score: Int?, rankPercentage: String?) {
        self.rank = rank; self.memberID = memberID; self.nickname = nickname; self.avatar = avatar
        self.score = score; self.rankPercentage = rankPercentage
    }
}

/// Page states for `subpackageP3/pages/growthcenter/leaderboard/index`.
/// The live read is the existing `GrowthCenterReading.leaderboard` call.
/// Anonymous, season, world, and team boards stay hidden: this type does not open them.
public enum GrowthLeaderboardPageCapability: Equatable {
    case productionBoard
    case anonymousBoard
    case seasonBoard
    case worldBoard
    case teamBoard

    public var isLive: Bool {
        switch self {
        case .productionBoard: return true
        case .anonymousBoard, .seasonBoard, .worldBoard, .teamBoard: return false
        }
    }

    /// Nil means this build has no route. The anonymous value is the existing unserved
    /// constant, and `isLive` stays false for it.
    public var path: String? {
        switch self {
        case .productionBoard: return RePoint04GrowthLeaderboard.productionPath
        case .anonymousBoard: return RePoint04GrowthLeaderboard.unservedPath
        case .seasonBoard, .worldBoard, .teamBoard: return nil
        }
    }
}

/// Unknown numbers use an em dash. A missing number is never stored or shown as 0.
public enum GrowthLeaderboardPageNumber: Equatable {
    case unknown
    case value(Int)

    public static let unknownDisplay = "—"

    public var literal: Int? {
        if case .value(let number) = self { return number }
        return nil
    }

    public var displayText: String {
        switch self {
        case .unknown: return Self.unknownDisplay
        case .value(let number): return String(number)
        }
    }

    /// Non-positive ranks are the source's unranked sentinel, not a place.
    public static func rank(_ raw: Int?) -> Self {
        guard let raw, raw > 0 else { return .unknown }
        return .value(raw)
    }

    /// Nil stays unknown. A literal 0 stays 0.
    public static func score(_ raw: Int?) -> Self {
        guard let raw else { return .unknown }
        return .value(raw)
    }
}

public struct GrowthLeaderboardViewerFact: Equatable {
    public let rank: Int
    public let score: Int?
    public let rankText: String
    public let scoreText: String

    public init(rank: Int, score: Int?, rankText: String, scoreText: String) {
        self.rank = rank
        self.score = score
        self.rankText = rankText
        self.scoreText = scoreText
    }
}

public enum GrowthLeaderboardPageState: Equatable {
    case loading
    case empty(viewer: GrowthLeaderboardViewerFact?)
    case error(GrowthCenterIssue)
    case unknown
    case ready(GrowthLeaderboard)
}

public struct GrowthLeaderboardPageModel: Equatable {
    public let state: GrowthLeaderboardPageState?
    public let hidden: Bool

    public init(state: GrowthLeaderboardPageState?, hidden: Bool) {
        self.state = state
        self.hidden = hidden
    }

    public static func rankText(_ entry: GrowthLeaderboardEntry) -> String {
        GrowthLeaderboardPageNumber.rank(entry.rank).displayText
    }

    public static func scoreText(_ entry: GrowthLeaderboardEntry) -> String {
        GrowthLeaderboardPageNumber.score(entry.score).displayText
    }

    /// A missing capability stays hidden. A settled board with no numeric fact is unknown,
    /// not an empty list and not a zero score.
    public static func project(capability: GrowthLeaderboardPageCapability, isLoading: Bool, settled: Bool, issue: GrowthCenterIssue?, board: GrowthLeaderboard?) -> Self {
        guard capability.isLive else { return Self(state: nil, hidden: true) }
        if isLoading || !settled { return Self(state: .loading, hidden: false) }
        if let issue { return Self(state: .error(issue), hidden: false) }
        guard let board else { return Self(state: .unknown, hidden: false) }
        if board.list.isEmpty { return Self(state: .empty(viewer: viewerFact(board)), hidden: false) }
        if !hasDisplayableFact(board) { return Self(state: .unknown, hidden: false) }
        return Self(state: .ready(board), hidden: false)
    }

    private static func viewerFact(_ board: GrowthLeaderboard) -> GrowthLeaderboardViewerFact? {
        guard let rank = GrowthLeaderboardPageNumber.rank(board.me.rank).literal else { return nil }
        let score = GrowthLeaderboardPageNumber.score(board.me.score)
        return GrowthLeaderboardViewerFact(rank: rank, score: score.literal, rankText: String(rank), scoreText: score.displayText)
    }

    private static func hasDisplayableFact(_ board: GrowthLeaderboard) -> Bool {
        if GrowthLeaderboardPageNumber.rank(board.me.rank).literal != nil { return true }
        if board.me.score != nil { return true }
        return board.list.contains { entry in
            GrowthLeaderboardPageNumber.rank(entry.rank).literal != nil || entry.score != nil
        }
    }
}

@MainActor public final class GrowthLeaderboardPageCoordinator {
    public let query: GrowthBoardQuery
    public let capability: GrowthLeaderboardPageCapability
    private let reader: any GrowthCenterReading
    private let store: GrowthCenterReadModel<GrowthLeaderboard>
    public private(set) var model: GrowthLeaderboardPageModel

    public init(reader: any GrowthCenterReading, query: GrowthBoardQuery = GrowthBoardQuery(), capability: GrowthLeaderboardPageCapability = .productionBoard) {
        self.reader = reader
        self.query = query
        self.capability = capability
        self.store = GrowthCenterReadModel<GrowthLeaderboard>()
        self.model = GrowthLeaderboardPageModel.project(capability: capability, isLoading: capability.isLive, settled: !capability.isLive, issue: nil, board: nil)
    }

    /// Loads through the reader that already exists. Hidden capabilities do not call it.
    public func refresh() async {
        let selected = capability
        guard selected.isLive else {
            model = GrowthLeaderboardPageModel.project(capability: selected, isLoading: false, settled: true, issue: nil, board: nil)
            return
        }
        if !reader.isAuthenticated {
            store.invalidate()
            model = GrowthLeaderboardPageModel.project(capability: selected, isLoading: false, settled: true, issue: .login, board: nil)
            return
        }
        if !reader.isConfigured {
            store.invalidate()
            model = GrowthLeaderboardPageModel.project(capability: selected, isLoading: false, settled: true, issue: .notConfigured, board: nil)
            return
        }
        let key = GrowthCenterLoadKey(scope: reader.scope, query: query)
        let requested = query
        model = GrowthLeaderboardPageModel.project(capability: selected, isLoading: true, settled: false, issue: nil, board: nil)
        await store.load(key: key, currentKey: { key }) { try await self.reader.leaderboard(query: requested) }
        let settled = store.loadedKey == key
        model = GrowthLeaderboardPageModel.project(capability: selected, isLoading: store.isLoading, settled: settled, issue: store.visibleIssue(key: key), board: store.visibleValue(key: key))
    }
}
