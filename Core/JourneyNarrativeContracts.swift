import Foundation

/// Topic-only runs explicitly use activityId=0. Nil would invoke the server's legacy
/// unique-run lookup and may read another occurrence of the same topic.
public struct JourneyNarrativeScope: Equatable {
    public let topicID: Int
    public let activityID: Int
    public init(scope: PlaySessionScope, topicID: Int) throws {
        guard scope.isValid, topicID > 0 else { throw APIError.invalidRequest }
        switch scope {
        case .topic(let id): guard id == topicID else { throw APIError.invalidRequest }; activityID = 0
        case .activity(let id): activityID = id
        }
        self.topicID = topicID
    }
    public var query: [String: String] { ["topicId": String(topicID), "activityId": String(activityID)] }
    var json: [String: PlayWireValue] { ["topicId": .int(topicID), "activityId": .int(activityID)] }
    var key: String { "\(topicID):\(activityID)" }
}
public enum JourneyNarrativeQuery: Equatable, Hashable {
    case casebook, backpack, stage(chapterID: Int), ending, questions(nodeID: Int)
    public var key: String {
        switch self { case .casebook: return "casebook"; case .backpack: return "backpack"; case .stage(let id): return "stage:\(id)"; case .ending: return "ending"; case .questions(let id): return "questions:\(id)" }
    }
    public var titleKey: String {
        switch self { case .casebook: return "journey.record.casebook"; case .backpack: return "journey.record.backpack"; case .stage: return "journey.record.stage"; case .ending: return "journey.record.ending"; case .questions: return "journey.record.questions" }
    }
    var path: String {
        switch self { case .casebook: return "api/play/journey/casebook"; case .backpack: return "api/play/journey/backpack"; case .stage: return "api/play/journey/stage-end"; case .ending: return "api/play/journey/ending"; case .questions: return "api/play/encounter" }
    }
    func fields(_ scope: JourneyNarrativeScope) throws -> [String: String] {
        var fields = scope.query
        switch self {
        case .stage(let id): guard id > 0 else { throw APIError.invalidRequest }; fields["chapterId"] = String(id)
        case .questions(let id): guard id > 0 else { throw APIError.invalidRequest }; fields["nodeId"] = String(id)
        default: break
        }
        return fields
    }
}
public struct JourneyRecordLine: Equatable {
    public let title: String
    public let text: String?
}
public struct JourneyRecordRelation: Equatable {
    public let key: String?
    public let name: String?
    public let state: String
    public let value: Int?
    public let line: String?
    init(_ raw: PlayWireValue) throws {
        guard raw.object != nil, let state = raw["state"].text, ["ally", "neutral", "guarded"].contains(state) else { throw PlayExperienceError.malformed }
        key = try JourneyNarrativeDecoding.text(raw["key"])
        name = try JourneyNarrativeDecoding.text(raw["name"])
        self.state = state
        value = try JourneyNarrativeDecoding.optionalNumber(raw["value"])
        line = try JourneyNarrativeDecoding.text(raw["line"])
    }
}
public struct JourneyDialogueEffect: Equatable, Identifiable {
    public enum Kind: String, Equatable {
        case inc = "INC"
        case addTag = "ADD_TAG"
    }
    private static let forbiddenKeywords = ["reward", "badge", "item", "coin", "coupon", "answer", "clue"]
    public let id: String
    public let type: Kind
    public let key: String
    public let delta: Int?
    public let value: Int?
    public let label: String?
    public static func decodeList(_ raw: PlayWireValue) throws -> [JourneyDialogueEffect] {
        if raw == .null { return [] }
        return try JourneyNarrativeDecoding.rows(raw).map(Self.init)
    }
    init(_ raw: PlayWireValue) throws {
        guard raw.object != nil,
              let kindRaw = raw["type"].text,
              let type = Kind(rawValue: kindRaw),
              let key = raw["key"].text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty, key.count <= 64,
              key.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
            throw PlayExperienceError.malformed
        }
        let lowered = key.lowercased()
        guard !Self.forbiddenKeywords.contains(where: { lowered.contains($0) }) else {
            throw PlayExperienceError.malformed
        }
        let delta = try JourneyNarrativeDecoding.optionalNumber(raw["delta"])
        switch type {
        case .inc:
            guard key.hasPrefix("relation."), key.count > "relation.".count,
                  let delta, delta != 0, (-10...10).contains(delta) else {
                throw PlayExperienceError.malformed
            }
        case .addTag:
            guard key.hasPrefix("tag."), key.count > "tag.".count else {
                throw PlayExperienceError.malformed
            }
        }
        let value = try JourneyNarrativeDecoding.optionalNumber(raw["value"])
        let label = try JourneyNarrativeDecoding.text(raw["label"])
        self.type = type
        self.key = key
        self.delta = delta
        self.value = value
        self.label = label
        self.id = "\(type.rawValue):\(key):\(delta.map(String.init) ?? label ?? "")"
    }
}
public struct JourneyDialogueReceipt: Equatable {
    public let npcID: Int
    public let routeActionID: String
    public let reply: String
    public let effects: [JourneyDialogueEffect]
    public let relation: JourneyRecordRelation?
    public let stateVersion: Int
    /// MP `_onResponse`: only a SUCCEEDED + PASS reply for the same request id is shown; anything else is a failure.
    init(chat raw: PlayWireValue, requestID: String, npcID: Int, routeActionID: String) throws {
        guard raw.object != nil,
              raw["requestId"].text?.lowercased() == requestID,
              raw["outcomeStatus"].text == "SUCCEEDED",
              raw["safetyDecision"].text == "PASS",
              let reply = raw["safeText"].text, !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PlayExperienceError.malformed
        }
        self.npcID = npcID
        self.routeActionID = routeActionID
        self.reply = reply
        self.effects = try JourneyDialogueEffect.decodeList(raw["effects"])
        self.relation = raw["relation"] == .null ? nil : try JourneyRecordRelation(raw["relation"])
        self.stateVersion = raw["stateVersion"].integer ?? 0
    }
}
public struct JourneyRecordLog: Equatable {
    public let text: String
    public let kind: String
    public let at: Int64?
    public let hpDelta: Int
    public let luckDelta: Int
    init(_ raw: PlayWireValue) throws {
        guard raw.object != nil, let text = raw["text"].text, let kind = raw["kind"].text,
              ["node", "check", "reroll", "rest", "mistake"].contains(kind), let hp = raw["hpDelta"].integer,
              let luck = raw["luckDelta"].integer else { throw PlayExperienceError.malformed }
        self.text = text; self.kind = kind; hpDelta = hp; luckDelta = luck
        if raw["at"] == .null { at = nil } else { guard case .integer(let value) = raw["at"], value >= 0 else { throw PlayExperienceError.malformed }; at = value }
    }
}
public struct JourneyCasebookDocument: Equatable {
    public let facts: [String]
    public let costs: [String]
    public let relations: [JourneyRecordRelation]
    public let effects: [JourneyDialogueEffect]
    public let log: [JourneyRecordLog]
    public let found: Int
    public let total: Int
    init(_ raw: PlayWireValue) throws {
        facts = try JourneyNarrativeDecoding.labels(raw["facts"]); costs = try JourneyNarrativeDecoding.labels(raw["costs"])
        relations = try JourneyNarrativeDecoding.rows(raw["relations"]).map(JourneyRecordRelation.init)
        effects = try JourneyDialogueEffect.decodeList(raw["effects"])
        log = try JourneyNarrativeDecoding.rows(raw["log"]).map(JourneyRecordLog.init)
        let counts = try JourneyNarrativeDecoding.progress(raw); found = counts.0; total = counts.1
    }
}
public struct JourneyBackpackItem: Equatable, Identifiable {
    public let id: Int
    public let reward: String?
    public let status: String
    public let claimableAt: Int64?
    init(_ raw: PlayWireValue) throws {
        guard raw.object != nil, let id = raw["nodeId"].integer, id > 0, let status = raw["status"].text,
              ["claimed", "pending", "none"].contains(status) else { throw PlayExperienceError.malformed }
        self.id = id; self.status = status; reward = try JourneyNarrativeDecoding.text(raw["reward"])
        if raw["claimableAt"] == .null { claimableAt = nil }
        else { guard case .integer(let value) = raw["claimableAt"], value >= 0 else { throw PlayExperienceError.malformed }; claimableAt = value }
    }
}
public struct JourneyStageDocument: Equatable {
    public let changed: [String]
    public let open: String?
    public let costs: [String]
    public let hp: Int?
    public let luck: Int?
    public let stateVersion: Int
    init(_ raw: PlayWireValue) throws {
        changed = try JourneyNarrativeDecoding.strings(raw["changed"]); open = try JourneyNarrativeDecoding.text(raw["open"])
        costs = try JourneyNarrativeDecoding.labels(raw["costs"])
        hp = try JourneyNarrativeDecoding.optionalNumber(raw["hp"]); luck = try JourneyNarrativeDecoding.optionalNumber(raw["luck"])
        guard let version = raw["stateVersion"].integer, version >= 0 else { throw PlayExperienceError.malformed }; stateVersion = version
    }
}
public struct JourneyEndingDocument: Equatable {
    public let title: String?
    public let summary: String?
    public let epilogues: [JourneyRecordRelation]
    public let exhibits: [String]
    public let costs: [String]
    public let badgeTitle: String?
    public let found: Int
    public let total: Int
    public let identity: [JourneyRecordLine]
    public let notes: [JourneyRecordLine]
    public let photos: [JourneyRecordLine]
    public let chapter: PlayWireValue
    init(_ raw: PlayWireValue) throws {
        guard raw.object != nil else { throw PlayExperienceError.malformed }
        title = try JourneyNarrativeDecoding.text(raw["title"]); summary = try JourneyNarrativeDecoding.text(raw["summary"])
        epilogues = try JourneyNarrativeDecoding.rows(raw["epilogues"]).map(JourneyRecordRelation.init)
        exhibits = try JourneyNarrativeDecoding.strings(raw["exhibits"]); costs = try JourneyNarrativeDecoding.labels(raw["costs"])
        badgeTitle = try JourneyNarrativeDecoding.text(raw["badge"]["title"])
        let counts = try JourneyNarrativeDecoding.progress(raw); found = counts.0; total = counts.1
        func lines(_ key: String, title: String, text: String) throws -> [JourneyRecordLine] {
            guard raw["archive"] != .null else { return [] }
            return try JourneyNarrativeDecoding.rows(raw["archive"][key]).map { row in
                .init(title: try JourneyNarrativeDecoding.text(row[title]) ?? "", text: try JourneyNarrativeDecoding.text(row[text]))
            }
        }
        identity = try lines("identity", title: "label", text: "value")
        notes = try lines("notes", title: "title", text: "text")
        photos = try lines("photos", title: "title", text: "url")
        guard raw["chapter"] == .null || raw["chapter"].object != nil else { throw PlayExperienceError.malformed }
        chapter = raw["chapter"]
    }
}
public struct JourneyQuestion: Equatable, Identifiable {
    public let id: String
    public let question: String
    public let asked: Bool
    public let answer: String?
    init(_ raw: PlayWireValue) throws {
        guard let id = raw["id"].text, Self.validID(id), let question = raw["q"].text,
              let asked = raw["asked"].bool else { throw PlayExperienceError.malformed }
        self.id = id; self.question = question; self.asked = asked
        // Never display an answer which the current projection does not authorize.
        answer = asked ? try JourneyNarrativeDecoding.text(raw["a"]) : nil
    }
    static func validID(_ id: String) -> Bool { id.range(of: #"^[A-Za-z0-9_-]{1,32}$"#, options: .regularExpression) != nil }
}
public struct JourneyQuestionsDocument: Equatable {
    public let nodeID: Int
    public let runID: Int
    public let version: Int
    public let allowsAsking: Bool
    public let opener: String?
    public let aside: String?
    public let questions: [JourneyQuestion]
    init(_ raw: PlayWireValue, expectedNodeID: Int) throws {
        guard raw.object != nil, raw["nodeId"].integer == expectedNodeID, let run = raw["runId"].integer, run > 0,
              let version = raw["stateVersion"].integer, version >= 0 else { throw PlayExperienceError.malformed }
        nodeID = expectedNodeID; runID = run; self.version = version
        guard let arrived = raw["arrived"].bool, let locked = raw["locked"].bool else { throw PlayExperienceError.malformed }
        allowsAsking = arrived && !locked
        opener = try JourneyNarrativeDecoding.text(raw["enter"]["opener"]); aside = try JourneyNarrativeDecoding.text(raw["enter"]["aside"])
        if raw["enter"] == .null { questions = [] }
        else {
            questions = try JourneyNarrativeDecoding.rows(raw["enter"]["questions"]).map(JourneyQuestion.init)
            guard Set(questions.map(\.id)).count == questions.count else { throw PlayExperienceError.malformed }
        }
    }
}
public enum JourneyNarrativeDocument: Equatable {
    case casebook(JourneyCasebookDocument), backpack([JourneyBackpackItem]), stage(JourneyStageDocument), ending(JourneyEndingDocument), questions(JourneyQuestionsDocument)
    init(_ raw: PlayWireValue, query: JourneyNarrativeQuery) throws {
        switch query {
        case .casebook: self = .casebook(try .init(raw))
        case .backpack:
            let rows = try JourneyNarrativeDecoding.rows(raw["nodes"]).map(JourneyBackpackItem.init)
            guard Set(rows.map(\.id)).count == rows.count else { throw PlayExperienceError.malformed }; self = .backpack(rows)
        case .stage: self = .stage(try .init(raw))
        case .ending: self = .ending(try .init(raw))
        case .questions(let nodeID): self = .questions(try .init(raw, expectedNodeID: nodeID))
        }
    }
}
enum JourneyNarrativeDecoding {
    static func text(_ raw: PlayWireValue) throws -> String? {
        if raw == .null { return nil }; guard let value = raw.text else { throw PlayExperienceError.malformed }; return value
    }
    static func optionalNumber(_ raw: PlayWireValue) throws -> Int? {
        if raw == .null { return nil }; guard let value = raw.integer else { throw PlayExperienceError.malformed }; return value
    }
    static func rows(_ raw: PlayWireValue) throws -> [PlayWireValue] {
        guard let rows = raw.array, rows.allSatisfy({ $0.object != nil }) else { throw PlayExperienceError.malformed }; return rows
    }
    static func strings(_ raw: PlayWireValue) throws -> [String] {
        guard let rows = raw.array, rows.allSatisfy({ $0.text != nil }) else { throw PlayExperienceError.malformed }; return rows.compactMap(\.text)
    }
    static func labels(_ raw: PlayWireValue) throws -> [String] {
        try rows(raw).map { guard let label = $0["label"].text else { throw PlayExperienceError.malformed }; return label }
    }
    static func progress(_ raw: PlayWireValue) throws -> (Int, Int) {
        guard let found = raw["found"].integer, let total = raw["total"].integer, found >= 0, total >= found else { throw PlayExperienceError.malformed }; return (found, total)
    }
}
