import Foundation

/// P7 `GET /api/play/player-journey/report`. Fields are only those named in zip-v35 §24.3.
/// Rank, when the server sent a number, is a completed-node rank and is not a puzzle net score.
/// There is no duration field: `elapsedSource == UNAVAILABLE_OTHER_RUN` is unknown, never 0.
/// `rewardsScope == TOPIC_ACTIVITY` is the theme/activity backpack, not a grant earned this run.

public struct PWaveBattleReportFact: Equatable, Sendable {
    public let scopeKind: String?
    public let runID: PWaveIdentifierFact
    public let playInstanceID: PWaveIdentifierFact
    public let progressScope: String?
    public let runState: String?
    public let score: PWaveNumberFact
    public let rank: PWaveNumberFact
    public let elapsedSource: String?
    public let rewardsScope: String?

    public var legacyTopicScope: Bool { scopeKind == "LEGACY_TOPIC_SCOPE" }
    public var unattributedRun: Bool { scopeKind == "UNATTRIBUTED_RUN" }
    /// The zip only defines the negative case. Other scope kinds do not become "fill current content".
    public var mayFillCurrentContent: Bool? { scopeKind == "UNATTRIBUTED_RUN" ? false : nil }
    /// The zip only defines that a legacy topic scope is not one run.
    public var isSingleRun: Bool? { scopeKind == "LEGACY_TOPIC_SCOPE" ? false : nil }
    public var elapsedIsUnknown: Bool { elapsedSource == "UNAVAILABLE_OTHER_RUN" }
    public var rewardsAreTopicOrActivityBackpack: Bool { rewardsScope == "TOPIC_ACTIVITY" }

    public static let showsSuccessSettlement = false
    public static let labelsRewardsAsThisRun = false
    public static let elapsedAmountIsKnown = false
    public static let rankIsPuzzleNetScore = false

    public init(scopeKind: String?, runID: PWaveIdentifierFact, playInstanceID: PWaveIdentifierFact,
                progressScope: String?, runState: String?, score: PWaveNumberFact, rank: PWaveNumberFact,
                elapsedSource: String?, rewardsScope: String?) {
        self.scopeKind = scopeKind
        self.runID = runID
        self.playInstanceID = playInstanceID
        self.progressScope = progressScope
        self.runState = runState
        self.score = score
        self.rank = rank
        self.elapsedSource = elapsedSource
        self.rewardsScope = rewardsScope
    }
}

public enum PWaveBattleReport {
    public static func decode(data: Data, status: Int) -> PWaveServerFact<PWaveBattleReportFact> {
        switch PWaveEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return fact(payload)
        }
    }

    static func fact(_ payload: PlayWireValue) -> PWaveServerFact<PWaveBattleReportFact> {
        guard let object = payload.object else { return .unknown }
        let scopeKind = PWaveEnvelope.text(object["scopeKind"] ?? .null)
        let runID = keyed(object, "runId", PWaveIdentifierFact.parse)
        let playInstanceID = keyed(object, "playInstanceId", PWaveIdentifierFact.parse)
        let progressScope = PWaveEnvelope.text(object["progressScope"] ?? .null)
        let runState = PWaveEnvelope.text(object["runState"] ?? .null)
        let score = keyedNumber(object, "score")
        let rank = keyedNumber(object, "rank")
        let elapsedSource = PWaveEnvelope.text(object["elapsedSource"] ?? .null)
        let rewardsScope = PWaveEnvelope.text(object["rewardsScope"] ?? .null)
        let decoded = PWaveBattleReportFact(scopeKind: scopeKind, runID: runID, playInstanceID: playInstanceID,
                                             progressScope: progressScope, runState: runState, score: score, rank: rank,
                                             elapsedSource: elapsedSource, rewardsScope: rewardsScope)
        guard hasClassifiedField(decoded) else { return .unknown }
        return .ready(decoded)
    }

    private static func keyedNumber(_ object: [String: PlayWireValue], _ key: String) -> PWaveNumberFact {
        guard let value = object[key] else { return .unknown }
        return PWaveNumberFact.parse(value)
    }

    private static func keyed(_ object: [String: PlayWireValue], _ key: String,
                              _ parse: (PlayWireValue) -> PWaveIdentifierFact) -> PWaveIdentifierFact {
        guard let value = object[key] else { return .unknown }
        return parse(value)
    }

    private static func hasClassifiedField(_ fact: PWaveBattleReportFact) -> Bool {
        if fact.scopeKind != nil || fact.progressScope != nil || fact.runState != nil
            || fact.elapsedSource != nil || fact.rewardsScope != nil { return true }
        if fact.runID.literalInteger != nil || fact.playInstanceID.literalInteger != nil { return true }
        if case .text = fact.runID { return true }
        if case .text = fact.playInstanceID { return true }
        if fact.score.literal != nil || fact.rank.literal != nil { return true }
        return false
    }
}
