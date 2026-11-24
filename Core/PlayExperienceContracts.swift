import Foundation

/// JSON scalar fidelity for source-backed payloads. Never log these values: answers and
/// evidence can be private. Numeric strings are tolerated only by explicit accessors.
public indirect enum PlayWireValue: Codable, Equatable, Sendable {
    case object([String: PlayWireValue]), array([PlayWireValue]), string(String), integer(Int64), number(Double), bool(Bool), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int64.self) { self = .integer(v) }
        else if let v = try? c.decode(Double.self), v.isFinite { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: Self].self) { self = .object(v) }
        else { self = .array(try c.decode([Self].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .integer(let v): try c.encode(v)
        case .number(let v): guard v.isFinite else { throw APIError.invalidRequest }; try c.encode(v)
        case .bool(let v): try c.encode(v)
        }
    }
    public subscript(_ key: String) -> Self { object?[key] ?? .null }
    public var object: [String: Self]? { if case .object(let v) = self { return v }; return nil }
    public var array: [Self]? { if case .array(let v) = self { return v }; return nil }
    public var text: String? { if case .string(let v) = self { return v }; return nil }
    public var bool: Bool? { if case .bool(let v) = self { return v }; return nil }
    public var integer: Int? {
        if case .integer(let v) = self, abs(Double(v)) <= 9_007_199_254_740_991 { return Int(exactly: v) }
        return nil
    }
    public var tolerantInteger: Int? { integer ?? text.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } }
    public var double: Double? {
        switch self { case .integer(let v): return Double(v); case .number(let v): return v; default: return nil }
    }
    static func int(_ v: Int) -> Self { .integer(Int64(v)) }
    func decoded<T: Decodable>(_ type: T.Type = T.self) throws -> T { try JSONDecoder().decode(type, from: JSONEncoder().encode(self)) }
}

public struct PlayExperienceSession: Equatable {
    public let accountID: Int
    public let epoch: UInt64
    /// Supplied from RegionalSessionStorageScope.service, never from UI language.
    public let namespace: String
    public let role: String
    let token: String
    public init(accountID: Int, epoch: UInt64, namespace: String, token: String, role: String = "player") throws {
        guard accountID > 0, !namespace.isEmpty, !role.isEmpty, role.utf8.count <= 128, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        self.accountID = accountID; self.epoch = epoch; self.namespace = namespace; self.token = token; self.role = role
    }
}
extension PlayExperienceSession {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.accountID == rhs.accountID && lhs.epoch == rhs.epoch && lhs.namespace.utf8.elementsEqual(rhs.namespace.utf8) &&
        lhs.role.utf8.elementsEqual(rhs.role.utf8) && lhs.token.utf8.elementsEqual(rhs.token.utf8)
    }
}
public struct PlayRouteAdvance: Codable, Equatable {
    public let actionID: String
    public let expectedVersion: Int
    /// UG-09 / U05-03: original run identity from `GET /api/play/action-context`, journaled with the
    /// action id so an exact retry and a receipt read name the same run. Nil on journals written
    /// before this binding existed; those requests keep their original shape.
    public let routeSessionID: Int?
    public let runtimeInstance: String?
    public let authorityEpoch: Int?
    public init(actionID: String, expectedVersion: Int) throws {
        try self.init(actionID: actionID, expectedVersion: expectedVersion, routeSessionID: nil, runtimeInstance: nil, authorityEpoch: nil)
    }
    public init(actionID: String, expectedVersion: Int, routeSessionID: Int?, runtimeInstance: String?, authorityEpoch: Int?) throws {
        let id = actionID.trimmingCharacters(in: .whitespacesAndNewlines)
        // The backend accepts `[A-Za-z0-9:_-]{1,80}` action ids; UUID strings satisfy it.
        guard !id.isEmpty, id.count <= 96, expectedVersion >= 0, routeSessionID.map({ $0 >= 0 }) ?? true,
              (runtimeInstance == nil) == (authorityEpoch == nil) else { throw APIError.invalidRequest }
        self.actionID = id; self.expectedVersion = expectedVersion
        self.routeSessionID = routeSessionID; self.runtimeInstance = runtimeInstance; self.authorityEpoch = authorityEpoch
    }
    /// Bound from the server's action context (not minted from a local route snapshot).
    public var isContextBound: Bool { routeSessionID != nil }
    var fields: [String: String] {
        var fields = ["routeActionId": actionID, "expectedRouteVersion": String(expectedVersion)]
        if let routeSessionID { fields["routeSessionId"] = String(routeSessionID) }
        if let runtimeInstance, let authorityEpoch { fields["runtimeInstance"] = runtimeInstance; fields["authorityEpoch"] = String(authorityEpoch) }
        return fields
    }
}
public enum PlayExperienceError: Error, Equatable {
    case disabled, staleSession, busy, invalidAction, unknownResult, unsupported, malformed, persistenceUnavailable
    case rejected(Int, String?), unauthorized
}
public struct PlayExperienceDocument: Decodable, Equatable {
    public let base: PlayNodesResult
    public let extras: [Int: PlayNodeExtras]
    public let chapterStories: [Int: ChapterStoryDocument]
    public let storyVariables: [String: PlayWireValue]
    public let storyVoices: [String: PlayWireValue]
    public let storyThoughts: [PlayWireValue]
    /// U04-03 server verdict; nil when the server sends none.
    public let compatibility: PlayContentCompatibility?
    /// Content identity (frozen run snapshot version, else published config version). Nil is unknown, never 0.
    public let contentVersion: String?
    /// Cast fields from this nodes read. `.null` when the route has no cast.
    public let castPayload: PlayWireValue
    public init(from decoder: Decoder) throws {
        base = try PlayNodesResult(from: decoder)
        let raw = try PlayWireValue(from: decoder)
        var rows: [Int: PlayNodeExtras] = [:]
        for row in raw["nodes"].array ?? [] {
            guard let id = row["nodeId"].tolerantInteger, id > 0 else { throw APIError.malformedResponse }
            rows[id] = PlayNodeExtras(raw: row)
        }
        extras = rows
        var chapters: [Int: ChapterStoryDocument] = [:]
        for rawChapter in raw["chapters"].array ?? [] {
            let chapter = try ChapterStoryDocument(raw: rawChapter)
            guard chapters[chapter.chapterID] == nil else { throw APIError.malformedResponse }
            chapters[chapter.chapterID] = chapter
        }
        chapterStories = chapters
        storyVariables = raw["vars"].object ?? [:]
        storyVoices = raw["storyVoices"].object ?? [:]
        storyThoughts = raw["routeState"]["thoughts"].array ?? []
        compatibility = PlayContentCompatibility(raw: raw["compatibility"])
        if let frozen = raw["contentSnapshotVersion"].tolerantInteger, frozen > 0 { contentVersion = "s\(frozen)" }
        else if let published = raw["publishedConfigVersion"].tolerantInteger, published > 0 { contentVersion = "p\(published)" }
        else { contentVersion = nil }
        castPayload = CastRuntimeFacts.payload(from: raw)
    }
}
public struct PlayNodeExtras: Equatable {
    public let merchantID: Int?
    public let hint1: String?
    public let hint2: String?
    public let hintCost: Int?
    public let hintLocked: Bool?
    public let hintCount: Int?
    public let puzzleScoring: Bool?
    public let puzzleHintLevel: Int?
    public let puzzleScoreCap: Int?
    public let usedHints: [String]
    public let sensorConfig: PlayWireValue
    public let uploadedImage: String?
    public let storyImage: String?
    public let audioURL: String?
    public let medalName: String?
    public let medalImage: String?
    public let couponID: Int?
    public let dispatchedTask: PlayRandomDispatchedTask?
    /// `photoCheck.mode`. `"RECORD"` is the skippable photo record; anything else is an ordinary photo.
    public let photoCheckMode: String?
    init(raw: PlayWireValue) {
        merchantID = raw["merchantId"].tolerantInteger
        hint1 = raw["hint1"].text; hint2 = raw["hint2"].text; hintCost = raw["hintCost"].tolerantInteger
        hintLocked = raw["hintLocked"].bool; hintCount = raw["hintCount"].tolerantInteger
        puzzleScoring = raw["puzzleScoring"].bool; puzzleHintLevel = raw["puzzleHintLevel"].tolerantInteger
        puzzleScoreCap = raw["puzzleScoreCap"].tolerantInteger
        usedHints = raw["usedHints"].array?.compactMap(\.text) ?? []
        sensorConfig = raw["sensorConfig"]; uploadedImage = raw["imgUrl"].text; storyImage = raw["storyImg"].text; audioURL = raw["audioUrl"].text
        medalName = raw["medalName"].text; medalImage = raw["medalImg"].text; couponID = raw["couponId"].tolerantInteger
        dispatchedTask = PlayRandomDispatchedTask(wire: raw["dispatchedTask"])
        photoCheckMode = raw["photoCheck"]["mode"].text
    }
}

/// Photo-record body for a station whose `photoCheck.mode` is `RECORD`.
/// The kit submit that posts this body belongs to P4 (`PlayKitInputContract`); this only decides what is legal.
public enum PlayPhotoRecordError: Error, Equatable {
    case submitPhotoCheckOnRecord
    case textConfirmedOnOrdinary
    case imageURL
    case missing
}

public enum PlayPhotoRecordSubmission: Equatable {
    case image(String)
    case textConfirmed
    /// `submitPhotoCheck` is the ordinary photo-check write. RECORD rejects it.
    /// `textConfirmed` is legal only on RECORD. An image must be https and at most 512 characters.
    public static func validate(mode: String?, imageURL: String?, textConfirmed: Bool, submitPhotoCheck: Bool) -> Result<PlayPhotoRecordSubmission, PlayPhotoRecordError> {
        if mode == "RECORD" {
            if submitPhotoCheck { return .failure(.submitPhotoCheckOnRecord) }
            if textConfirmed {
                guard imageURL == nil else { return .failure(.missing) }
                return .success(.textConfirmed)
            }
            guard let imageURL, imageURL.count <= 512, let url = URL(string: imageURL), url.scheme == "https" else { return .failure(.imageURL) }
            return .success(.image(imageURL))
        }
        if textConfirmed { return .failure(.textConfirmedOnOrdinary) }
        return .failure(.missing)
    }
}

public struct PlayEvidenceCard: Equatable, Identifiable {
    public let id: Int
    public let title: String?
    public let text: String
}

public struct PlayRunPhoto: Equatable, Identifiable {
    public let id: Int
    public let title: String?
    public let url: String
}

/// Finished unlocked nodes' `feedbackText`, and finished stations' `picUrl`.
public enum PlayRunKeepsakes {
    public static func evidence(in snapshot: PlaySnapshot) -> [PlayEvidenceCard] {
        snapshot.visibleNodes.compactMap { node in
            guard node.done == true, !snapshot.isStoryLocked(node) else { return nil }
            guard let text = node.feedbackText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return PlayEvidenceCard(id: node.id, title: node.name, text: String(text.prefix(4_000)))
        }
    }
    public static func photos(in snapshot: PlaySnapshot) -> [PlayRunPhoto] {
        snapshot.visibleNodes.compactMap { node in
            guard node.done == true, let url = node.photoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else { return nil }
            return PlayRunPhoto(id: node.id, title: node.name, url: url)
        }
    }
}
public enum PlayNodeTask: String, CaseIterable {
    case answer, photo, scan, arrive, preference, sensor, merchantScan, merchantPhoto, merchantVerify, unsupported
    public static func resolve(mode: Int?, node: PlayNode) -> Self {
        if mode == 2 {
            if node.arrived != true { return .merchantScan }
            if node.selfReported != true { return .merchantPhoto }
            return .merchantVerify
        }
        guard mode == 1 else { return .unsupported }
        switch node.validationMethod {
        case 0, 5: return .arrive
        case 1, 3: return .answer
        case 2: return .photo
        case 4: return .scan
        case 6: return .preference
        case 7: return .sensor
        case nil:
            if node.needAnswer == true { return .answer }
            if node.needScan == true { return .scan }
            return .arrive
        default: return .unsupported
        }
    }
}
public struct PlayHintReceipt: Equatable {
    public let hints: [String]
    public let cost: Int?
    public let level: Int?
    public let hintCount: Int?
    public let scoreCap: Int?
    init(_ raw: PlayWireValue) throws {
        guard raw.object != nil else { throw PlayExperienceError.malformed }
        let hints = raw["hints"].array?.compactMap(\.text) ?? [raw["hint1"].text, raw["hint2"].text, raw["hint"].text].compactMap { $0 }
        self.hints = hints.filter { !$0.isEmpty }; cost = raw["cost"].tolerantInteger
        level = raw["level"].tolerantInteger; hintCount = raw["hintCount"].tolerantInteger; scoreCap = raw["scoreCap"].tolerantInteger
        guard !self.hints.isEmpty, [cost, level, hintCount, scoreCap].compactMap({ $0 }).allSatisfy({ $0 >= 0 }) else { throw PlayExperienceError.malformed }
    }
}
public struct PlayEndingDocument: Decodable, Equatable {
    public struct Fragment: Decodable, Equatable, Identifiable {
        public let step: Int; public let name: String; public let nodeId: Int?; public let text: String?
        public var id: Int { step }
    }
    public let opener: String
    public let fragments: [Fragment]
    public var hasStory: Bool { !fragments.isEmpty }
}
public struct PlayCompanionLeaderboard: Equatable {
    public struct Row: Equatable, Identifiable {
        public let id: Int; public let rank: Int?; public let name: String?; public let score: Int; public let rankPercentage: String?
        init(_ raw: PlayWireValue) throws {
            guard let id = raw["memberId"].integer, id > 0, let score = raw["score"].integer, score >= 0 else { throw PlayExperienceError.malformed }
            self.id = id; self.score = score; rank = raw["rank"].integer; name = raw["nickname"].text; rankPercentage = raw["rankPercentage"].text
            guard raw["rank"] == .null || (rank ?? 0) > 0 else { throw PlayExperienceError.malformed }
        }
    }
    public let entries: [Row]
    public let me: Row
    init(_ raw: PlayWireValue) throws {
        guard let list = raw["list"].array, list.count <= 50 else { throw PlayExperienceError.malformed }
        entries = try list.map(Row.init); me = try Row(raw["me"])
        guard Set(entries.map(\.id)).count == entries.count,
              entries.enumerated().allSatisfy({ $0.element.rank == $0.offset + 1 }) else { throw PlayExperienceError.malformed }
        if let ranked = entries.first(where: { $0.id == me.id }) {
            guard ranked.rank == me.rank, ranked.score == me.score else { throw PlayExperienceError.malformed }
        } else if me.rank != nil { throw PlayExperienceError.malformed }
    }
}
public struct PlayLeadProgress: Equatable {
    public struct Member: Equatable, Identifiable {
        public let id: Int; public let name: String?; public let done: Int?; public let arrived: Bool; public let isLeader: Bool
    }
    public let exists: Bool
    public let isLeader: Bool
    public let leaderMemberID: Int?
    public let status: Int?
    public let chapterName: String?
    public let broadcast: String?
    public let arrived: Int?
    public let meArrived: Bool
    public let members: [Member]
    /// WP-02 (`leadUnlock` / `_leadSkipRequests`): current and next chapter ids; nil current means none released yet.
    public let currentChapterID: Int?
    public let nextChapterID: Int?
    /// Members stuck at a sensor station who asked to skip it. At most eight, as the mini-program shows.
    public let skipRequests: [SkipRequest]
    public struct SkipRequest: Equatable, Identifiable {
        public var id: String { "\(memberID):\(nodeID)" }
        public let memberID: Int; public let nodeID: Int; public let nickname: String?
    }
    public var allArrived: Bool { !members.isEmpty && (arrived ?? -1) >= members.count }
    init(_ raw: PlayWireValue) throws {
        guard let exists = raw["exists"].bool else { throw PlayExperienceError.malformed }
        self.exists = exists; isLeader = raw["isLeader"].bool == true; leaderMemberID = raw["leaderMemberId"].integer
        status = raw["status"].integer; chapterName = raw["chapterName"].text; broadcast = raw["broadcast"].text
        arrived = raw["arrived"].integer; meArrived = raw["meArrived"].bool == true || raw["meArrived"].integer == 1
        members = try (raw["members"].array ?? []).map { item in
            guard let id = item["memberId"].integer, id > 0 else { throw PlayExperienceError.malformed }
            return Member(id: id, name: item["nickname"].text, done: item["done"].integer, arrived: item["arrived"].bool == true, isLeader: item["isLeader"].bool == true)
        }
        guard Set(members.map(\.id)).count == members.count else { throw PlayExperienceError.malformed }
        currentChapterID = raw["currentChapterId"].integer.flatMap { $0 > 0 ? $0 : nil }
        nextChapterID = raw["nextChapterId"].integer.flatMap { $0 > 0 ? $0 : nil }
        skipRequests = Array((raw["skipRequests"].array ?? []).compactMap { row -> SkipRequest? in
            guard let member = row["memberId"].integer, member > 0, let node = row["nodeId"].integer, node > 0 else { return nil }
            return SkipRequest(memberID: member, nodeID: node, nickname: row["nickname"].text.flatMap { $0.isEmpty ? nil : $0 })
        }.prefix(8))
    }
    public func allows(_ action: PlayLeadAction, accountID: Int) -> Bool {
        if action == .arrive { return exists && !meArrived }
        guard isLeader, leaderMemberID == accountID else { return false }
        if action == .start { return !exists }
        guard exists else { return false }
        return action != .unlockChapter || allArrived
    }
}
public enum PlayLeadAction: String, CaseIterable {
    case start, arrive, broadcast, unlockChapter = "unlock-chapter", settle, editTime = "edit-ops"
}
/// WP-02 `leadUnlock`: one frozen chapter command. The same `commandId` is resent or read back, never replaced
/// while its outcome is unknown. `expectedChapterID` 0 means no chapter has been released yet.
public struct PlayLeadUnlockCommand: Codable, Equatable {
    public let commandID: String
    public let activityID: Int
    public let expectedChapterID: Int
    public let targetChapterID: Int
    public var receiptOnly = false
    public init?(commandID: String = UUID().uuidString.lowercased(), activityID: Int, expectedChapterID: Int?, targetChapterID: Int?) {
        guard activityID > 0, let targetChapterID, targetChapterID > 0, (expectedChapterID ?? 0) >= 0,
              commandID.range(of: "^[A-Za-z0-9:_-]{1,80}$", options: .regularExpression) != nil else { return nil }
        self.commandID = commandID; self.activityID = activityID; self.expectedChapterID = expectedChapterID ?? 0; self.targetChapterID = targetChapterID
    }
    var fields: [String: String] {
        ["activityId": String(activityID), "commandId": commandID,
         "expectedChapterId": String(expectedChapterID), "targetChapterId": String(targetChapterID)]
    }
    /// The server's replayed receipt names this command and its chapters.
    public func confirms(_ data: PlayWireValue) -> Bool {
        data["commandId"].text == commandID && data["expectedChapterId"].tolerantInteger == expectedChapterID
            && data["targetChapterId"].tolerantInteger == targetChapterID
    }
}

/// Dispatched mystery task revealed on store entry / check-in (`node_task_pool`).
public struct PlayRandomDispatchedTask: Equatable, Decodable, Sendable {
    public let poolID: Int?
    public let poolName: String?
    public let nodeID: Int
    public let nodeName: String?
    public let dispatchDate: String?
    public let ruleInstructions: String?
    public let randomReceiptID: String?

    enum CodingKeys: String, CodingKey {
        case poolID = "poolId"
        case poolName
        case nodeID = "nodeId"
        case nodeName
        case dispatchDate
        case ruleInstructions = "rule"
        case randomReceiptID = "randomReceiptId"
    }

    public init(
        poolID: Int? = nil,
        poolName: String? = nil,
        nodeID: Int,
        nodeName: String? = nil,
        dispatchDate: String? = nil,
        ruleInstructions: String? = nil,
        randomReceiptID: String? = nil
    ) {
        self.poolID = poolID
        self.poolName = poolName
        self.nodeID = nodeID
        self.nodeName = nodeName
        self.dispatchDate = dispatchDate
        self.ruleInstructions = ruleInstructions
        self.randomReceiptID = randomReceiptID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func intOrString(_ key: CodingKeys) -> Int? {
            if let value = try? c.decode(Int.self, forKey: key) { return value > 0 ? value : nil }
            if let text = try? c.decode(String.self, forKey: key),
               let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 {
                return value
            }
            return nil
        }
        guard let nodeID = intOrString(.nodeID) else {
            throw DecodingError.dataCorruptedError(forKey: .nodeID, in: c, debugDescription: "Missing positive nodeId")
        }
        self.poolID = intOrString(.poolID)
        self.poolName = (try? c.decodeIfPresent(String.self, forKey: .poolName))?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.nodeID = nodeID
        self.nodeName = (try? c.decodeIfPresent(String.self, forKey: .nodeName))?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dispatchDate = (try? c.decodeIfPresent(String.self, forKey: .dispatchDate))?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ruleInstructions = (try? c.decodeIfPresent(String.self, forKey: .ruleInstructions))?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.randomReceiptID = (try? c.decodeIfPresent(String.self, forKey: .randomReceiptID))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init?(wire: PlayWireValue) {
        guard wire.object != nil, let nodeID = wire["nodeId"].tolerantInteger, nodeID > 0 else { return nil }
        self.init(
            poolID: wire["poolId"].tolerantInteger.flatMap { $0 > 0 ? $0 : nil },
            poolName: Self.nonEmpty(wire["poolName"].text),
            nodeID: nodeID,
            nodeName: Self.nonEmpty(wire["nodeName"].text ?? wire["title"].text ?? wire["name"].text),
            dispatchDate: Self.nonEmpty(wire["dispatchDate"].text),
            ruleInstructions: Self.nonEmpty(wire["rule"].text ?? wire["ruleInstructions"].text),
            randomReceiptID: Self.nonEmpty(wire["randomReceiptId"].text)
        )
    }

    public static func fromResponse(_ response: PlayWireValue) -> PlayRandomDispatchedTask? {
        PlayRandomDispatchedTask(wire: response["dispatchedTask"])
    }

    public var displayName: String {
        if let nodeName, !nodeName.isEmpty { return nodeName }
        return "#\(nodeID)"
    }

    public func revealTitle(locale: Locale = .current) -> String {
        Self.isEnglish(locale) ? "Today's Mystery Task: \(displayName)" : "今日盲盒任务：\(displayName)"
    }

    private static func nonEmpty(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    fileprivate static func isEnglish(_ locale: Locale) -> Bool {
        locale.identifier.lowercased().hasPrefix("en")
    }
}

/// Reward drop receipt attached to completion responses (`reward["drop"]`).
public struct PlayRewardDrop: Equatable, Sendable {
    public let dropType: Int
    public let label: String
    public let extraXp: Int?
    public let mult: Int?
    public let badgeCode: String?
    public let couponTemplateID: Int?
    public let randomReceiptID: String?

    public init(
        dropType: Int,
        label: String,
        extraXp: Int? = nil,
        mult: Int? = nil,
        badgeCode: String? = nil,
        couponTemplateID: Int? = nil,
        randomReceiptID: String? = nil
    ) {
        self.dropType = dropType
        self.label = label
        self.extraXp = extraXp
        self.mult = mult
        self.badgeCode = badgeCode
        self.couponTemplateID = couponTemplateID
        self.randomReceiptID = randomReceiptID
    }

    public init?(wire: PlayWireValue) {
        guard wire.object != nil else { return nil }
        let type = wire["dropType"].tolerantInteger ?? 0
        let rawLabel = wire["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard type > 0 || (rawLabel?.isEmpty == false) else { return nil }
        let fallbackLabel: String
        switch type {
        case 1: fallbackLabel = "探索值加倍"
        case 2: fallbackLabel = "徽章碎片"
        case 3: fallbackLabel = "商家彩蛋券"
        default: fallbackLabel = "神秘奖励"
        }
        self.dropType = type
        self.label = (rawLabel?.isEmpty == false ? rawLabel! : fallbackLabel)
        self.extraXp = wire["extraXp"].tolerantInteger
        self.mult = wire["mult"].tolerantInteger
        self.badgeCode = wire["badgeCode"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.couponTemplateID = wire["couponTemplateId"].tolerantInteger
        self.randomReceiptID = wire["randomReceiptId"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func fromReward(_ reward: PlayWireValue) -> PlayRewardDrop? {
        PlayRewardDrop(wire: reward["drop"])
    }

    public func toastMessage(locale: Locale = .current) -> String {
        let en = PlayRandomDispatchedTask.isEnglish(locale)
        let summary = detailText(locale: locale)
        return en ? "Bonus drop: \(summary)" : "随机掉落：\(summary)"
    }

    public func detailText(locale: Locale = .current) -> String {
        let en = PlayRandomDispatchedTask.isEnglish(locale)
        var parts = [label]
        if let extraXp, extraXp > 0 {
            parts.append(en ? "+\(extraXp) XP" : "+\(extraXp) 探索值")
        }
        return parts.joined(separator: " ")
    }
}
