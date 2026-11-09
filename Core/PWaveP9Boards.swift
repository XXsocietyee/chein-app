import Foundation

/// P9 boards. The quest board is completed-node count for `scope=quest`, `period=all`,
/// `scoreBasis=COMPLETED_NODES`. It is not a puzzle-net board and it does not rank by row index.
/// The between-teams board is `teamDoneCount`. It is not a member rank.
/// Member rank stays hidden until the server sends `doneTaskCount`, `rank`, `ranked`, `mine`,
/// and `memberRankBasis=COMPLETED_TASK_COUNT`, with the team board switch on.
/// `doneTaskIds` are not turned into a rank, and an unfinished member is not given first place.
/// Unknown rank is an em dash. There is no friend board.

public struct PWaveRankRow: Equatable, Sendable {
    public let rank: PWaveNumberFact
    public let mine: Bool?
    public var rankText: String { rank.displayText }
    public var unranked: Bool { rank.literal == nil }
    public var assignedFromIndex: Bool { false }

    public init(rank: PWaveNumberFact, mine: Bool?) {
        self.rank = rank
        self.mine = mine
    }
}

public struct PWaveQuestBoardFact: Equatable, Sendable {
    public static let completedNodesLabel = "完成节点数"

    public let scope: String?
    public let period: String?
    public let scoreBasis: String?
    public let rows: [PWaveRankRow]
    public let periodStart: String?
    public let periodEnd: String?
    public let unattributedRuns: PWaveNumberFact
    public let attributionBasis: String?

    public var label: String? {
        scoreBasis == "COMPLETED_NODES" ? Self.completedNodesLabel : nil
    }
    public var matchesQuestBasis: Bool {
        scope == "quest" && period == "all" && scoreBasis == "COMPLETED_NODES"
    }
    public var netScoreBoard: Bool { false }
    public var friendBoardShown: Bool { false }
    public var filledGeographyFromDevice: Bool { false }
    public var unattributedRunsText: String { unattributedRuns.displayText }

    public init(scope: String?, period: String?, scoreBasis: String?, rows: [PWaveRankRow],
                periodStart: String?, periodEnd: String?, unattributedRuns: PWaveNumberFact, attributionBasis: String?) {
        self.scope = scope
        self.period = period
        self.scoreBasis = scoreBasis
        self.rows = rows
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.unattributedRuns = unattributedRuns
        self.attributionBasis = attributionBasis
    }
}

public struct PWaveTeamBoardRow: Equatable, Sendable {
    public let rank: PWaveNumberFact
    public let teamID: String?
    public let title: String?
    public let activeCount: PWaveNumberFact
    public let teamDoneCount: PWaveNumberFact
    public let totalTasks: PWaveNumberFact
    public let mine: Bool?

    public var rankText: String { rank.displayText }
    public var teamDoneCountText: String { teamDoneCount.displayText }
    public var isMemberRank: Bool { false }
    public var teamDoneCountIsPerMember: Bool { false }

    public init(rank: PWaveNumberFact, teamID: String?, title: String?, activeCount: PWaveNumberFact,
                teamDoneCount: PWaveNumberFact, totalTasks: PWaveNumberFact, mine: Bool?) {
        self.rank = rank
        self.teamID = teamID
        self.title = title
        self.activeCount = activeCount
        self.teamDoneCount = teamDoneCount
        self.totalTasks = totalTasks
        self.mine = mine
    }
}

public struct PWaveTeamBoardFact: Equatable, Sendable {
    public static let switchKey = "orient.team.board.enabled"

    public let rows: [PWaveTeamBoardRow]
    public let boardEnabled: Bool
    public var memberRankShown: Bool { false }

    public init(rows: [PWaveTeamBoardRow], boardEnabled: Bool) {
        self.rows = rows
        self.boardEnabled = boardEnabled
    }
}

public struct PWaveMemberRankRow: Equatable, Sendable {
    public let doneTaskCount: PWaveNumberFact
    public let rank: PWaveNumberFact
    public let ranked: Bool
    public let mine: Bool
    public var rankText: String { rank.displayText }
    public var doneTaskCountText: String { doneTaskCount.displayText }
    public var promotedToFirst: Bool { false }

    public init(doneTaskCount: PWaveNumberFact, rank: PWaveNumberFact, ranked: Bool, mine: Bool) {
        self.doneTaskCount = doneTaskCount
        self.rank = rank
        self.ranked = ranked
        self.mine = mine
    }
}

public struct PWaveMemberRankFact: Equatable, Sendable {
    public static let basisToken = "COMPLETED_TASK_COUNT"

    public let basis: String?
    public let rows: [PWaveMemberRankRow]
    public let boardEnabled: Bool
    public var available: Bool { boardEnabled && basis == Self.basisToken }
    public var friendBoardShown: Bool { false }

    public init(basis: String?, rows: [PWaveMemberRankRow], boardEnabled: Bool) {
        self.basis = basis
        self.rows = rows
        self.boardEnabled = boardEnabled
    }
}

public enum PWaveBoards {
    public static func decodeQuest(data: Data, status: Int, supported: Set<String>) -> PWavePresentation<PWaveQuestBoardFact> {
        let presented = PWaveServerCapability.presentation(data: data, status: status, supported: supported) { root, payload in
            quest(root: root, payload: payload)
        }
        if presented.hidden { return presented }
        switch presented.phase {
        case .ready(let fact) where fact.matchesQuestBasis:
            return presented
        case .empty:
            return presented
        case .error:
            return presented
        default:
            return PWaveServerCapability.conceal(.unknown, outcome: PWaveServerCapability.Outcome(satisfied: false, declared: presented.serverCapabilitiesDeclared, missing: presented.unsatisfiedServerCapabilities))
        }
    }

    public static func decodeTeams(data: Data, status: Int, supported: Set<String>) -> PWavePresentation<PWaveTeamBoardFact> {
        let presented = PWaveServerCapability.presentation(data: data, status: status, supported: supported) { root, payload in
            teams(root: root, payload: payload)
        }
        return gate(presented) { $0.boardEnabled }
    }

    public static func decodeMembers(data: Data, status: Int, supported: Set<String>) -> PWavePresentation<PWaveMemberRankFact> {
        let presented = PWaveServerCapability.presentation(data: data, status: status, supported: supported) { root, payload in
            members(root: root, payload: payload)
        }
        return gate(presented) { $0.available }
    }

    private static func gate<Ready>(_ presented: PWavePresentation<Ready>, available: (Ready) -> Bool) -> PWavePresentation<Ready> {
        if presented.hidden { return presented }
        switch presented.phase {
        case .ready(let fact) where available(fact):
            return presented
        case .empty:
            return presented
        case .error:
            return presented
        default:
            return PWaveServerCapability.conceal(.unknown, outcome: PWaveServerCapability.Outcome(
                satisfied: false, declared: presented.serverCapabilitiesDeclared, missing: presented.unsatisfiedServerCapabilities))
        }
    }

    static func quest(root: PlayWireValue, payload: PlayWireValue) -> PWaveServerFact<PWaveQuestBoardFact> {
        let items: [PlayWireValue]
        let rows: [PWaveRankRow]
        if case .array(let array) = payload {
            items = array
            if !array.isEmpty {
                guard let parsed = rankRows(array), !parsed.isEmpty else { return .unknown }
                rows = parsed
            } else {
                rows = []
            }
        } else if let object = payload.object {
            items = [payload]
            let hasRow = object.keys.contains("rank") || object.keys.contains("me") || object.keys.contains("mine")
            let hasNestedArray = object.values.contains { if case .array = $0 { return true }; return false }
            if hasRow {
                rows = rankRows([payload]) ?? []
            } else if hasNestedArray {
                return .unknown
            } else {
                rows = []
            }
        } else {
            return .unknown
        }
        let built = board(payload: payload, root: root, items: items, rows: rows)
        guard built.matchesQuestBasis else { return .ready(built) }
        return rows.isEmpty ? .empty : .ready(built)
    }

    private static func board(payload: PlayWireValue, root: PlayWireValue, items: [PlayWireValue], rows: [PWaveRankRow]) -> PWaveQuestBoardFact {
        let coverage = object(payload, root, items, "coverage")?.object
        let runs: PWaveNumberFact
        if let coverage, coverage.keys.contains("unattributedRuns") {
            runs = PWaveNumberFact.parse(coverage["unattributedRuns"] ?? .null)
        } else {
            runs = .unknown
        }
        return PWaveQuestBoardFact(
            scope: field(payload, root, items, "scope"), period: field(payload, root, items, "period"),
            scoreBasis: field(payload, root, items, "scoreBasis"), rows: rows,
            periodStart: field(payload, root, items, "periodStart"), periodEnd: field(payload, root, items, "periodEnd"),
            unattributedRuns: runs, attributionBasis: PWaveEnvelope.text(coverage?["attributionBasis"] ?? .null))
    }

    private static func rankRows(_ items: [PlayWireValue]) -> [PWaveRankRow]? {
        var rows: [PWaveRankRow] = []
        for item in items {
            guard let object = item.object else { return nil }
            guard object.keys.contains("rank") || object.keys.contains("me") || object.keys.contains("mine") else { return nil }
            let rank = object.keys.contains("rank") ? PWaveNumberFact.parse(object["rank"] ?? .null) : .unknown
            rows.append(PWaveRankRow(rank: rank, mine: object["mine"]?.bool ?? object["me"]?.bool))
        }
        return rows
    }

    private static func field(_ payload: PlayWireValue, _ root: PlayWireValue, _ items: [PlayWireValue], _ key: String) -> String? {
        PWaveEnvelope.text(object(payload, root, items, key) ?? .null)
    }

    private static func object(_ payload: PlayWireValue, _ root: PlayWireValue, _ items: [PlayWireValue], _ key: String) -> PlayWireValue? {
        for candidate in [payload.object?[key], root.object?[key], items.first?.object?[key]] {
            if let candidate, case .null = candidate { continue }
            if let candidate { return candidate }
        }
        return nil
    }

    static func teams(root: PlayWireValue, payload: PlayWireValue) -> PWaveServerFact<PWaveTeamBoardFact> {
        let enabled = enabled(root, payload)
        let items: [PlayWireValue]
        if case .array(let rows) = payload {
            items = rows
        } else if payload.object != nil {
            items = [payload]
        } else {
            return .unknown
        }
        if items.isEmpty { return enabled ? .empty : .unknown }
        var rows: [PWaveTeamBoardRow] = []
        for item in items {
            guard let row = teamRow(item) else { return .unknown }
            rows.append(row)
        }
        if !enabled { return .ready(PWaveTeamBoardFact(rows: rows, boardEnabled: false)) }
        return .ready(PWaveTeamBoardFact(rows: rows, boardEnabled: true))
    }

    private static func teamRow(_ value: PlayWireValue) -> PWaveTeamBoardRow? {
        guard let object = value.object else { return nil }
        let keys = ["rank", "teamId", "title", "activeCount", "teamDoneCount", "totalTasks", "mine"]
        guard keys.contains(where: { object.keys.contains($0) }) else { return nil }
        return PWaveTeamBoardRow(
            rank: number(object, "rank"), teamID: identifier(object["teamId"]),
            title: PWaveEnvelope.text(object["title"] ?? .null),
            activeCount: number(object, "activeCount"), teamDoneCount: number(object, "teamDoneCount"),
            totalTasks: number(object, "totalTasks"), mine: object["mine"]?.bool)
    }

    static func members(root: PlayWireValue, payload: PlayWireValue) -> PWaveServerFact<PWaveMemberRankFact> {
        guard let object = payload.object else { return .unknown }
        let enabled = enabled(root, payload)
        let basis = PWaveEnvelope.text(object["memberRankBasis"] ?? .null)
        guard object.keys.contains("members"), let members = object["members"]?.array else {
            return .ready(PWaveMemberRankFact(basis: basis, rows: [], boardEnabled: false))
        }
        if members.isEmpty {
            let ready = PWaveMemberRankFact(basis: basis, rows: [], boardEnabled: enabled)
            return ready.available ? .empty : .ready(ready)
        }
        var rows: [PWaveMemberRankRow] = []
        for member in members {
            guard let row = memberRow(member) else {
                return .ready(PWaveMemberRankFact(basis: basis, rows: [], boardEnabled: false))
            }
            rows.append(row)
        }
        return .ready(PWaveMemberRankFact(basis: basis, rows: rows, boardEnabled: enabled))
    }

    private static func memberRow(_ value: PlayWireValue) -> PWaveMemberRankRow? {
        guard let object = value.object else { return nil }
        let keys = ["doneTaskCount", "rank", "ranked", "mine"]
        guard keys.allSatisfy({ object.keys.contains($0) }) else { return nil }
        guard let ranked = object["ranked"]?.bool, let mine = object["mine"]?.bool else { return nil }
        return PWaveMemberRankRow(doneTaskCount: PWaveNumberFact.parse(object["doneTaskCount"] ?? .null),
                                  rank: PWaveNumberFact.parse(object["rank"] ?? .null), ranked: ranked, mine: mine)
    }

    private static func enabled(_ root: PlayWireValue, _ payload: PlayWireValue) -> Bool {
        let key = PWaveTeamBoardFact.switchKey
        if root.object?[key]?.bool == true { return true }
        if payload.object?[key]?.bool == true { return true }
        return false
    }

    private static func number(_ object: [String: PlayWireValue], _ key: String) -> PWaveNumberFact {
        guard object.keys.contains(key) else { return .unknown }
        return PWaveNumberFact.parse(object[key] ?? .null)
    }

    private static func identifier(_ value: PlayWireValue?) -> String? {
        guard let value else { return nil }
        switch PWaveIdentifierFact.parse(value) {
        case .text(let raw): return raw
        case .integer(let number): return String(number)
        case .unknown: return nil
        }
    }
}
