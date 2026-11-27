import Foundation

/// Source: play_api.dart `_exactSession`. Never send both IDs or substitute a topic ID
/// for an activity ID. Public cases are validated before any transport operation.
public enum PlaySessionScope: Hashable {
    case activity(Int), topic(Int)
    public var id: Int { switch self { case .activity(let id), .topic(let id): return id } }
    public var isValid: Bool { id > 0 }
    public var fields: [String: String] {
        switch self { case .activity(let id): return ["activityId": String(id)]
        case .topic(let id): return ["topicId": String(id)] }
    }
}

public struct PlayNodeExternalGameBinding: Decodable, Equatable, Sendable {
    public let gameID: String
    public let gameName: String?
    public let version: String?
    public let minScore: Int?
    public let requirePass: Bool?

    private enum CodingKeys: String, CodingKey {
        case gameID = "gameId", gameName, version, minScore, requirePass
    }
}

/// Optional facts stay optional: missing completion, arrival, XP or duration is not zero.
/// Strings are plain server text, never Markdown/HTML, instructions or navigation.
public struct PlayNode: Decodable, Equatable, Identifiable {
    public let id: Int
    public let name: String?
    public let npc: PlayNPCBrief?
    public let address: String?
    public let latitude: Double?
    public let longitude: Double?
    public let sortID: Int?
    public let done: Bool?
    public let arrived: Bool?
    public let selfReported: Bool?
    public let hasGame: Bool?
    public let gameDone: Bool?
    public let locked: Bool?
    public let validationMethod: Int?
    public let needScan: Bool?
    public let needAnswer: Bool?
    public let needGPS: Bool?
    public let question: String?
    /// Station success line. Shown on hangman only after the server says solved, and only when the kit sent none.
    public let passText: String?
    public let questionImage: String?
    public let questionAudio: String?
    public let options: [String: String]?
    public let description: String?
    public let hookText: String?
    public let storyText: String?
    public let gameTitle: String?
    public let ruleInstructions: String?
    public let requiredMaterials: String?
    public let durationMinutes: Int?
    public let difficulty: String?
    public let players: String?
    public let photoRequirement: String?
    public let businessTime: String?
    public let openStatus: String?
    public let crowded: Bool?
    public let inStoreLoad: Int?
    public let servicePerHour: Double?
    public let expectedWaitMinutes: Int?
    public let quantityUnavailable: Bool?
    public let routeNodeState: String?
    public let lockReason: String?
    public let weatherLocked: Bool?
    public let unlockAfterNodeID: Int?
    public let chapterID: Int?
    public let xp: Int?
    public let puzzleScore: Int?
    public let completionMode: String?
    public let sensorType: String?
    /// Retain unknown configuration rather than silently bypassing its prerequisite.
    public let advancedConfig: PlayJSONValue?
    public let externalGame: PlayNodeExternalGameBinding?
    /// Station photo. Nil when absent. `imgHidden` suppresses it even if a URL arrived (F07).
    public let imageURL: String?
    public let imgHidden: Bool?
    /// Game / template cover (`storyImg`). Distinct from the station photo.
    public let storyImage: String?
    public let visited: Bool?
    public let visitTime: PlayVisitTime?
    public let visitCheck: PlayVisitCheck?
    public let visitRadius: Int?
    /// Missing is not locked unless `PlayRuntimePortRouteGate.storyLockMissingIsLocked` is on.
    public let storyLocked: Bool?
    public let visitedByTeam: Bool?
    public let fragmentText: String?
    public let cardHookLong: String?
    /// When true the server hid the address; do not show `address` even if a stale value arrived.
    public let addressHidden: Bool?
    public let perk: PlayNodePerk?
    /// Finished-node evidence card (`feedbackText`). Kept beside the station image chain.
    public let feedbackText: String?
    /// Player photo of a finished station (`picUrl`). Not the station `imgUrl`.
    public let photoURL: String?

    private enum CodingKeys: String, CodingKey {
        case nodeId, name, npc, address, latitude, longitude, sortId, done, arrived, selfReported, hasGame, gameDone, locked, validationMethod
        case needScan, needAnswer, needGps, question, passText, questionImg, questionAudio, options, description
        case hookText, storyText, gameTitle, ruleInstructions, rule, requiredMaterials, duration, difficulty
        case players, photoRequireDesc, photoDesc, businessTime, openStatus, crowded, inStoreLoad, serviceCapacity, expectedWaitMinutes, quantityUnavailable, routeNodeState, lockReason, weatherLocked
        case unlockAfterNodeId, chapterId, xp, puzzleScore, completionMode, sensorType, advancedConfigJson, externalGame
        case imgUrl, imgHidden, storyImg, visited, visitTime, visitCheck, visitRadius, storyLocked, visitedByTeam
        case fragmentText, cardHookLong, addressHidden, perk, feedbackText, picUrl
    }
    private enum ServiceCapacityKeys: String, CodingKey { case perHour }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let nodeID = try c.playInt(.nodeId), nodeID > 0 else { throw APIError.malformedResponse }
        id = nodeID
        // Malformed or unnamed NPC data offers no entrance; never infer from merchantId.
        npc = try? c.decode(PlayNPCBrief.self, forKey: .npc)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        latitude = c.playCoordinate(.latitude); longitude = c.playCoordinate(.longitude)
        sortID = try c.playInt(.sortId)
        done = try c.playBool(.done); arrived = try c.playBool(.arrived)
        selfReported = try c.playBool(.selfReported); locked = try c.playBool(.locked)
        hasGame = try c.playBool(.hasGame); gameDone = try c.playBool(.gameDone)
        validationMethod = try c.playInt(.validationMethod)
        needScan = try c.playBool(.needScan); needAnswer = try c.playBool(.needAnswer); needGPS = try c.playBool(.needGps)
        question = try c.decodeIfPresent(String.self, forKey: .question)
        passText = try c.decodeIfPresent(String.self, forKey: .passText)
        questionImage = try c.decodeIfPresent(String.self, forKey: .questionImg)
        questionAudio = try c.decodeIfPresent(String.self, forKey: .questionAudio)
        // E2E-20261113b: the server sends a null text for an unused option ({"C": null}); drop it, and treat an
        // all-null map as no options, instead of failing the whole journey read.
        let rawOptions = try c.decodeIfPresent([String: String?].self, forKey: .options)?.compactMapValues { $0 }
        options = rawOptions?.isEmpty == false ? rawOptions : nil
        description = try c.decodeIfPresent(String.self, forKey: .description)
        hookText = try c.decodeIfPresent(String.self, forKey: .hookText)
        storyText = try c.decodeIfPresent(String.self, forKey: .storyText)
        gameTitle = try c.decodeIfPresent(String.self, forKey: .gameTitle)
        ruleInstructions = try c.decodeIfPresent(String.self, forKey: .ruleInstructions) ?? c.decodeIfPresent(String.self, forKey: .rule)
        requiredMaterials = try c.decodeIfPresent(String.self, forKey: .requiredMaterials)
        durationMinutes = try c.playInt(.duration)
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty)
        players = try c.decodeIfPresent(String.self, forKey: .players)
        photoRequirement = try c.decodeIfPresent(String.self, forKey: .photoRequireDesc) ?? c.decodeIfPresent(String.self, forKey: .photoDesc)
        businessTime = try c.decodeIfPresent(String.self, forKey: .businessTime)
        openStatus = try c.decodeIfPresent(String.self, forKey: .openStatus)
        crowded = try? c.playBool(.crowded)
        inStoreLoad = Self.sanitizeQueueCount(try? c.playInt(.inStoreLoad))
        if let cap = try? c.nestedContainer(keyedBy: ServiceCapacityKeys.self, forKey: .serviceCapacity) {
            let rawRate: Double?
            if let value = try? cap.decodeIfPresent(Double.self, forKey: .perHour) { rawRate = value }
            else if let raw = try? cap.decodeIfPresent(String.self, forKey: .perHour) { rawRate = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) }
            else { rawRate = nil }
            servicePerHour = Self.sanitizeQueueRate(rawRate)
        } else { servicePerHour = nil }
        expectedWaitMinutes = Self.sanitizeQueueCount(try? c.playInt(.expectedWaitMinutes))
        quantityUnavailable = try? c.playBool(.quantityUnavailable)
        routeNodeState = try c.decodeIfPresent(String.self, forKey: .routeNodeState)
        lockReason = try c.decodeIfPresent(String.self, forKey: .lockReason)
        weatherLocked = try? c.playBool(.weatherLocked)
        unlockAfterNodeID = try c.playInt(.unlockAfterNodeId)
        chapterID = try c.playInt(.chapterId)
        xp = try c.playInt(.xp); puzzleScore = try c.playInt(.puzzleScore)
        completionMode = try c.decodeIfPresent(String.self, forKey: .completionMode)
        sensorType = try c.decodeIfPresent(String.self, forKey: .sensorType)
        advancedConfig = try c.decodeIfPresent(PlayJSONValue.self, forKey: .advancedConfigJson)
        externalGame = try? c.decodeIfPresent(PlayNodeExternalGameBinding.self, forKey: .externalGame)
        // Additive: a bad optional must not fail the node the rest of the route already decoded.
        imageURL = (try? c.decodeIfPresent(String.self, forKey: .imgUrl)) ?? nil
        imgHidden = (try? c.decodeIfPresent(Bool.self, forKey: .imgHidden)) ?? nil
        storyImage = (try? c.decodeIfPresent(String.self, forKey: .storyImg)) ?? nil
        visited = (try? c.decodeIfPresent(Bool.self, forKey: .visited)) ?? nil
        visitTime = (try? c.decodeIfPresent(PlayVisitTime.self, forKey: .visitTime)) ?? nil
        visitCheck = ((try? c.decodeIfPresent(String.self, forKey: .visitCheck)) ?? nil).flatMap { PlayVisitCheck(rawValue: $0.uppercased()) }
        visitRadius = (try? c.playInt(.visitRadius)) ?? nil
        storyLocked = (try? c.decodeIfPresent(Bool.self, forKey: .storyLocked)) ?? nil
        visitedByTeam = (try? c.decodeIfPresent(Bool.self, forKey: .visitedByTeam)) ?? nil
        fragmentText = (try? c.decodeIfPresent(String.self, forKey: .fragmentText)) ?? nil
        cardHookLong = (try? c.decodeIfPresent(String.self, forKey: .cardHookLong)) ?? nil
        addressHidden = (try? c.decodeIfPresent(Bool.self, forKey: .addressHidden)) ?? nil
        perk = (try? c.decodeIfPresent(PlayNodePerk.self, forKey: .perk)) ?? nil
        feedbackText = (try? c.decodeIfPresent(String.self, forKey: .feedbackText)) ?? nil
        photoURL = (try? c.decodeIfPresent(String.self, forKey: .picUrl)) ?? nil
    }
    public var hasAdvancedPrerequisite: Bool {
        guard let advancedConfig else { return false }
        let value: PlayJSONValue
        if case .string(let encoded) = advancedConfig {
            guard let decoded = try? JSONDecoder().decode(PlayJSONValue.self, from: Data(encoded.utf8)) else { return true }
            value = decoded
        } else { value = advancedConfig }
        guard case .object(let fields) = value else { return true }
        // Recognized disabled sections do not prevent a basic task. Unknown sections do.
        let known: Set<String> = ["timer", "random", "branch", "leaderboard", "multiplayer"]
        for (key, section) in fields {
            guard known.contains(key), case .object(let config) = section,
                  case .bool(false)? = config["enabled"] else { return true }
        }
        return false
    }
    public static let maxQueueMetricValue = 100_000
    public static func sanitizeQueueCount(_ value: Int?) -> Int? {
        guard let value, value >= 0, value <= maxQueueMetricValue else { return nil }
        return value
    }
    public static func sanitizeQueueRate(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0, value <= Double(maxQueueMetricValue) else { return nil }
        return value == 0 ? 0 : value
    }
    public static func formatQueueCount(_ value: Int?) -> String {
        sanitizeQueueCount(value).map(String.init) ?? "—"
    }
    public static func formatQueueRate(_ value: Double?) -> String {
        guard let valid = sanitizeQueueRate(value) else { return "—" }
        if valid.rounded() == valid, let exact = Int(exactly: valid) {
            return String(exact)
        }
        return String(valid)
    }
}

public struct PlayChapter: Decodable, Equatable, Identifiable {
    public let id: Int
    public let name: String?
    public let description: String?
    /// Narration from the same authorized /api/play/nodes response.
    public let audioURL: String?
    /// Nil when the server omitted it. A missing flag stays locked unless a visited place belongs to the chapter.
    public let chapterLocked: Bool?
    /// `img_arr` / `imgArr`, split by `PlayStationImageResolver`. Malformed input is an empty list.
    public let images: [String]
    /// VIDEO-r11-1: chapter film and its poster (MP pages/play/index.js:4911). Raw; the player gates the host.
    public let videoURL: String?
    public let videoPosterURL: String?
    private enum CodingKeys: String, CodingKey { case chapterId, name, description, audioUrl, chapterLocked, imgArr, videoUrl, videoPosterUrl }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = try c.playInt(.chapterId), id > 0 else { throw APIError.malformedResponse }
        self.id = id; name = try c.decodeIfPresent(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        audioURL = try c.decodeIfPresent(String.self, forKey: .audioUrl)
        if let value = try? c.decodeIfPresent(Bool.self, forKey: .chapterLocked) { chapterLocked = value }
        else { chapterLocked = nil }
        images = PlayStationImageResolver.list((try? c.decodeIfPresent(PlayWireValue.self, forKey: .imgArr)) ?? nil)
        videoURL = (try? c.decodeIfPresent(String.self, forKey: .videoUrl)) ?? nil
        videoPosterURL = (try? c.decodeIfPresent(String.self, forKey: .videoPosterUrl)) ?? nil
    }
}

public struct PlayRouteState: Decodable, Equatable {
    public let mode: String?
    public let sessionID: Int?
    public let status: String?
    public let version: Int?
    public let currentNodeID: Int?
    public let recommendedNodeID: Int?
    public let nodeStates: [Int: String]
    public let lockReasons: [Int: String]
    public let thoughts: [PlayWireValue]
    /// Nil covers absent, null, malformed or oversized optional history.
    public let decisionLog: PlayBranchHistoryLog?
    /// Journey opening chapter state; nil when absent or malformed (mini-program `isRecord` check).
    public let opening: PlayJourneyOpening?
    public var isBranch: Bool { mode == "BRANCH_GRAPH" }
    private enum CodingKeys: String, CodingKey {
        case routeMode, sessionId, status, version, currentNodeId, recommendedNodeId, nodeStates, lockReasons, thoughts, decisionLog, opening
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        decisionLog = try? c.decode(PlayBranchHistoryLog.self, forKey: .decisionLog)
        opening = try? c.decode(PlayJourneyOpening.self, forKey: .opening)
        mode = try c.decodeIfPresent(String.self, forKey: .routeMode)
        sessionID = try c.playInt(.sessionId); status = try c.decodeIfPresent(String.self, forKey: .status)
        version = try c.playInt(.version); currentNodeID = try c.playInt(.currentNodeId)
        recommendedNodeID = try c.playInt(.recommendedNodeId)
        thoughts = try c.decodeIfPresent([PlayWireValue].self, forKey: .thoughts) ?? []
        func map(_ key: CodingKeys) throws -> [Int: String] {
            let raw = try c.decodeIfPresent([String: String].self, forKey: key) ?? [:]
            var result: [Int: String] = [:]
            for (key, value) in raw {
                guard let id = Int(key), id > 0, result[id] == nil else { throw APIError.malformedResponse }
                result[id] = value
            }
            return result
        }
        nodeStates = try map(.nodeStates); lockReasons = try map(.lockReasons)
        guard version.map({ $0 >= 0 }) ?? true else { throw APIError.malformedResponse }
        if isBranch {
            guard (sessionID ?? 0) > 0, version != nil, status?.isEmpty == false,
                  !nodeStates.isEmpty else { throw APIError.malformedResponse }
        }
    }
}

public struct PlayNodesResult: Decodable, Equatable {
    public let eggs: [JourneyEgg]
    public let topicID: Int?
    public let topicName: String?
    public let topicDescription: String?
    public let mode: Int?
    public let playable: Bool?
    public let registered: Bool?
    /// Server-owned operational spectator fact; never implies registration or player rewards.
    public let leadSpectator: Bool?
    public let selfPlay: Bool?
    public let total: Int?
    public let doneCount: Int?
    public let timeNote: String?
    /// Kept verbatim. No server timezone contract: never infer expiry from local parsing.
    public let expiresAt: String?
    public let nodes: [PlayNode]
    public let chapters: [PlayChapter]
    public let routeState: PlayRouteState?
    /// Optional theme facts from the same `/api/play/nodes` object. Missing keys stay empty.
    /// A bad `look_json` or cover does not fail the route.
    public let themeFacts: PlayThemeServerFacts
    /// The viewer's `play_team` id for a team run (channels contract §5, item 17). Nil when absent or malformed;
    /// a bad value never fails the route.
    public let teamID: Int?
    /// Raw `topicCover` for the station image chain. `themeFacts.coverURL` is the https URL the title card already uses.
    public let topicCover: String?
    /// PLAY-r11-1: theme music (`topicAudioUrl`, MP pages/play/index.js:4642). Raw; the player gates the host.
    public let topicAudioURL: String?
    /// Both counts or neither. A mismatched pair fails the route; a missing pair stays nil.
    public let storyUnlocked: Int?
    public let storyTotal: Int?
    public let runStartMode: PlayRunStartMode?
    public let altStations: [PlayAltStation]
    /// Only an explicit `true` hides chapter progress. Missing or a non-bool stays nil.
    public let perkOnly: Bool?
    private enum CodingKeys: String, CodingKey {
        case topicId, topicName, topicDesc, mode, playable, registered, leadSpectator, selfPlay, total, doneCount, teamId
        case timeNote, expiresAt, nodes, chapters, routeState, eggs
        case topicAiGenerated, productType, topicCover, topicAudioUrl
        case lookJSON = "look_json"
        case storyUnlocked, storyTotal, runStartMode, altStations, perkOnly
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eggs = JourneyEgg.project((try? c.decode(PlayWireValue.self, forKey: .eggs)) ?? .null)
        topicID = try c.playInt(.topicId); topicName = try c.decodeIfPresent(String.self, forKey: .topicName)
        topicDescription = try c.decodeIfPresent(String.self, forKey: .topicDesc)
        mode = try c.playInt(.mode); playable = try c.playBool(.playable)
        registered = try? c.decode(Bool.self, forKey: .registered); selfPlay = try c.playBool(.selfPlay)
        leadSpectator = try c.decodeIfPresent(Bool.self, forKey: .leadSpectator)
        total = try c.playInt(.total); doneCount = try c.playInt(.doneCount)
        timeNote = try c.decodeIfPresent(String.self, forKey: .timeNote)
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
        // Required array: missing/null/non-object rows are errors, never an empty route.
        nodes = try c.decode([PlayNode].self, forKey: .nodes)
        chapters = try c.decodeIfPresent([PlayChapter].self, forKey: .chapters) ?? []
        routeState = try c.decodeIfPresent(PlayRouteState.self, forKey: .routeState)
        teamID = (try? c.playInt(.teamId)).flatMap { $0 }.flatMap { $0 > 0 ? $0 : nil }
        let coverRaw = (try? c.decodeIfPresent(String.self, forKey: .topicCover)) ?? nil
        topicCover = coverRaw
        topicAudioURL = (try? c.decodeIfPresent(String.self, forKey: .topicAudioUrl)) ?? nil
        themeFacts = PlayThemeServerFacts(
            aiGenerated: (try? c.decode(Bool.self, forKey: .topicAiGenerated)) == true,
            productType: PlayThemeServerFacts.lenientInt(c, .productType),
            coverURL: PlayThemeServerFacts.coverURL(coverRaw),
            look: PlayThemeLookTokens.read(c, .lookJSON))
        let unlocked = try c.playInt(.storyUnlocked)
        let stories = try c.playInt(.storyTotal)
        if let unlocked, let stories, stories >= 0, (0...stories).contains(unlocked) {
            storyUnlocked = unlocked; storyTotal = stories
        } else if unlocked == nil, stories == nil {
            storyUnlocked = nil; storyTotal = nil
        } else { throw APIError.malformedResponse }
        runStartMode = (try? c.decodeIfPresent(PlayRunStartMode.self, forKey: .runStartMode)) ?? nil
        altStations = PlayAltStation.unique(from: (try? c.decodeIfPresent(PlayWireValue.self, forKey: .altStations)) ?? nil)
        perkOnly = (try? c.decodeIfPresent(Bool.self, forKey: .perkOnly)) ?? nil
        guard Set(nodes.map(\.id)).count == nodes.count, Set(chapters.map(\.id)).count == chapters.count,
              total.map({ $0 >= 0 }) ?? true, doneCount.map({ $0 >= 0 }) ?? true else { throw APIError.malformedResponse }
    }
    public var allDone: Bool { if let total, let doneCount { return total > 0 && doneCount >= total }; return false }
}

public struct PlayAnswerReceipt: Decodable, Equatable {
    public let nodeID: Int
    public let firstTime: Bool?
    public let doneCount: Int?
    public let total: Int?
    public let completed: Bool?
    public let xp: Int?
    public let puzzleScore: Int?
    private enum CodingKeys: String, CodingKey { case nodeId, firstTime, done, total, completed, xp, score, puzzleScore }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = try c.playInt(.nodeId), id > 0 else { throw APIError.malformedResponse }
        nodeID = id; firstTime = try c.playBool(.firstTime)
        doneCount = try c.playInt(.done); total = try c.playInt(.total); completed = try c.playBool(.completed)
        xp = try c.playInt(.xp) ?? c.playInt(.score); puzzleScore = try c.playInt(.puzzleScore)
    }
}

public indirect enum PlayJSONValue: Decodable, Equatable {
    case object([String: PlayJSONValue]), array([PlayJSONValue]), string(String), bool(Bool), number(Double), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(String.self) { self = .string(value) }
        else if let value = try? c.decode([String: PlayJSONValue].self) { self = .object(value) }
        else if let value = try? c.decode([PlayJSONValue].self) { self = .array(value) }
        else { self = .number(try c.decode(Double.self)) }
    }
}

extension KeyedDecodingContainer {
    func playCoordinate(_ key: Key) -> Double? {
        let value = (try? decode(Double.self, forKey: key)) ?? (try? decode(String.self, forKey: key)).flatMap(Double.init)
        return value.flatMap { $0.isFinite ? $0 : nil }
    }
    func playInt(_ key: Key) throws -> Int? {
        if !contains(key) { return nil }
        if try decodeNil(forKey: key) { return nil }
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let string = try? decode(String.self, forKey: key), let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) { return value }
        throw APIError.malformedResponse
    }
    func playBool(_ key: Key) throws -> Bool? {
        if !contains(key) { return nil }
        if try decodeNil(forKey: key) { return nil }
        if let value = try? decode(Bool.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key), value == 0 || value == 1 { return value == 1 }
        if let value = try? decode(String.self, forKey: key) {
            if value == "true" || value == "1" { return true }
            if value == "false" || value == "0" { return false }
        }
        throw APIError.malformedResponse
    }
}

/// Free-exploration visit method. Unknown values stay nil; they are never guessed as GPS.
public enum PlayVisitCheck: String, Codable, Equatable, Sendable {
    case gps = "GPS"
    case scan = "SCAN"
    case online = "ONLINE"
}

/// Server visit time: epoch milliseconds, or a display string when that is all the payload carries.
public enum PlayVisitTime: Codable, Equatable, Sendable {
    case epochMilliseconds(Int64)
    case text(String)
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { throw DecodingError.valueNotFound(PlayVisitTime.self, .init(codingPath: c.codingPath, debugDescription: "visitTime")) }
        if let millis = try? c.decode(Int64.self), millis > 0 { self = .epochMilliseconds(millis); return }
        if let number = try? c.decode(Double.self), number.isFinite, number > 0, let millis = Int64(exactly: number.rounded(.towardZero)) {
            self = .epochMilliseconds(millis); return
        }
        if let text = try? c.decode(String.self) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let millis = Int64(trimmed), millis > 0 { self = .epochMilliseconds(millis); return }
            if !trimmed.isEmpty { self = .text(trimmed); return }
        }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "visitTime")
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .epochMilliseconds(let value): try c.encode(value)
        case .text(let value): try c.encode(value)
        }
    }
}

/// hengyin #866. DESK and ALT are how a run starts, not a node's completion mode.
public enum PlayRunStartMode: String, Codable, Equatable, Sendable {
    case desk = "DESK"
    case alt = "ALT"
}

public struct PlayAltStation: Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String?
    public let longitude: Double?
    public let latitude: Double?
    public init(id: Int, name: String?, longitude: Double?, latitude: Double?) {
        self.id = id; self.name = name; self.longitude = longitude; self.latitude = latitude
    }
    /// Keeps the first row for each positive id. A bad row is dropped; it does not fail the route.
    static func unique(from raw: PlayWireValue?) -> [PlayAltStation] {
        guard let rows = raw?.array else { return [] }
        var seen = Set<Int>()
        var result: [PlayAltStation] = []
        for row in rows {
            guard let id = row["id"].tolerantInteger, id > 0, seen.insert(id).inserted else { continue }
            let longitude = row["longitude"].double
            let latitude = row["latitude"].double
            result.append(PlayAltStation(
                id: id,
                name: row["name"].text,
                longitude: longitude?.isFinite == true ? longitude : nil,
                latitude: latitude?.isFinite == true ? latitude : nil))
        }
        return result
    }
}

/// Optional start fields for `/api/play/arrive`. START-r11-1: journaled on `PlayCompletionIntent.startFields` and
/// merged into the run's first arrive (MP pages/play/utils/run-start-mode.js:33-37).
public struct PlayRunStartRequest: Equatable {
    public let mode: PlayRunStartMode
    public let altStationID: Int?
    public init(mode: PlayRunStartMode, altStationID: Int? = nil, offered: [PlayAltStation] = []) throws {
        switch mode {
        case .desk:
            guard altStationID == nil else { throw APIError.invalidRequest }
        case .alt:
            guard let altStationID, offered.contains(where: { $0.id == altStationID }) else { throw APIError.invalidRequest }
        }
        self.mode = mode
        self.altStationID = mode == .alt ? altStationID : nil
    }
    public var fields: [String: String] {
        var result = ["startMode": mode.rawValue]
        if let altStationID { result["altStationId"] = String(altStationID) }
        return result
    }
}

/// hengyin #866 perk terms. A non-bool `included` fails this object so the node keeps `perk == nil`.
public struct PlayNodePerk: Decodable, Equatable, Sendable {
    public let included: Bool?
    public let extraSpendText: String?
    public let reserveRequired: Bool?
    /// mp-journey r3: MP hero 本店权益 (`perk.name`, `perk.redeemRule`; the MP falls back to 到店出示核销).
    public let name: String?
    public let redeemRule: String?
}

/// Node `completionMode`. DESK / ALT are run-level (`PlayRunStartMode`) and do not map here.
public enum PlayCompletionModePresentation: Equatable, Sendable {
    case solved, assisted, revealed, skipped
    public init?(raw: String?) {
        switch raw {
        case "SOLVED": self = .solved
        case "ASSISTED": self = .assisted
        case "REVEALED": self = .revealed
        case "SKIPPED": self = .skipped
        default: return nil
        }
    }
    public var titleKey: String {
        switch self {
        case .solved: return "playx.completion.solved"
        case .assisted: return "playx.completion.assisted"
        case .revealed: return "playx.completion.revealed"
        case .skipped: return "playx.completion.skipped"
        }
    }
}
