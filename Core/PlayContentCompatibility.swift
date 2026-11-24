import Foundation

/// U04-03. Server verdict from `GET /api/play/nodes` `compatibility`
/// (`ContentCapabilityRequirements.compatibility`). `supported == nil` is unconfirmed:
/// UNDECLARED is not "unsupported" and MALFORMED is not "supported".
public struct PlayContentCompatibility: Equatable, Sendable {
    public struct Missing: Equatable, Sendable {
        public let key: String
        public let minVersion: Int
        /// Nil when this client did not declare the key at all. Never 0.
        public let declaredVersion: Int?
    }
    public enum Verdict: Equatable, Sendable {
        /// The server compared a declaration and every required capability is present.
        case supported
        /// The server compared a declaration and found required capabilities missing.
        case unsupported([Missing])
        /// No usable declaration (old client, dormant declaration, or malformed declaration).
        case unconfirmed(source: String)
    }
    public let requiredKeys: [String]
    public let declared: Bool
    public let supported: Bool?
    public let source: String
    public let missing: [Missing]

    /// Nil for an absent, null or malformed object: an older server sends nothing and
    /// that is not evidence about this client.
    public init?(raw: PlayWireValue) {
        guard raw.object != nil, let source = raw["source"].text, !source.isEmpty,
              let declared = raw["declared"].bool else { return nil }
        let supported: Bool?
        switch raw["supported"] {
        case .bool(let value): supported = value
        case .null: supported = nil
        default: return nil
        }
        var required: [String] = []
        for row in raw["requiredCapabilities"].array ?? [] {
            guard let key = row["key"].text, !key.isEmpty else { return nil }
            required.append(key)
        }
        var missing: [Missing] = []
        for row in raw["missingCapabilities"].array ?? [] {
            guard let key = row["key"].text, !key.isEmpty, let min = row["minVersion"].integer, min >= 1 else { return nil }
            missing.append(Missing(key: key, minVersion: min, declaredVersion: row["declaredVersion"].integer))
        }
        self.requiredKeys = required; self.declared = declared; self.supported = supported
        self.source = source; self.missing = missing
    }

    public var verdict: Verdict {
        // DECLARED_MALFORMED with supported=true is still not a clean confirmation.
        guard declared, let supported, source == "DECLARED" || (source == "DECLARED_MALFORMED" && !supported) else {
            return .unconfirmed(source: source)
        }
        return supported ? .supported : .unsupported(missing)
    }

    /// OWN-10.3 (C2): only a compared declaration with missing capabilities refuses a start, and only for this
    /// content. Unconfirmed (no or malformed declaration) never blocks, as `mp:pages/play/index.js:4431` plays
    /// with no declaration. There is no fallback content: the reason is the missing keys, never "degraded".
    public var blocksStart: Bool {
        if case .unsupported = verdict { return true }
        return false
    }
    /// The refusal reason shown to the player: the missing capability keys, in server order.
    public var missingKeys: [String] {
        if case .unsupported(let rows) = verdict { return rows.map(\.key) }
        return []
    }

    /// Start/first-entry refusal for a declared client lacking a required capability.
    /// orient/advanced start answer 409 `CONTENT_CAPABILITY_UNSUPPORTED`; the implicit run
    /// creation inside `/api/play/nodes` answers the same server sentence without a code.
    public static let unsupportedCode = "CONTENT_CAPABILITY_UNSUPPORTED"
    static let unsupportedSentence = "当前客户端缺少本局所需能力"
    public static func isUnsupportedRejection(_ error: PlayExperienceError?) -> Bool {
        guard case .rejected(_, let message?)? = error else { return false }
        return message.contains(unsupportedCode) || message.contains(unsupportedSentence)
    }
}

/// U04-03 / §27.2. What this native build actually renders, in the server's
/// `key@version,key@version` form. Only keys with a native renderer and submit path
/// are listed; a key missing here makes the server refuse to create a new run
/// before play instead of letting content silently disappear.
public enum PlayClientCapabilities {
    public static let platform = "ios-native"
    public static let version = 1
    /// Chapter flow blocks `ChapterStoryProjection` renders. `branch` is not listed:
    /// the player branch-choice sheet does not exist natively (the mini-program does not render it either).
    public static let storyBlocks = ["node", "text", "image", "audio", "dream", "mood", "reveal", "odd", "voice",
                                     "thought", "divider", "gallery", "cap"]
    /// `PlayNodeTask.resolve`: validationMethod 0–7.
    static let answers = ["answer.arrive", "answer.text", "answer.photo", "answer.choice", "answer.scan",
                          "answer.gps", "answer.preference", "answer.sensor"]
    /// `PlayCompletionEvidence.sensor` accepts exactly these sensor types.
    static let sensors = ["sensor.still", "sensor.steps", "sensor.audio_clip"]
    /// Kits this build finishes as node answers: estimate, price pair, hidden object.
    static let kitAnswers = ["answer.estimate", "answer.pricePair", "answer.hiddenObject"]
    /// Letter-pool input on the Questo hangman and on TYPE questions. Role cards stay with P1.
    static let features = ["hangman.pool", "qa.letterPool"]
    static let base = ["chapter.blocks", "station.list", "media.image", "media.audio", "media.photo",
                       "location.gps", "route.branch", "theme.runtime"]
    /// Advanced sections rendered by `PlayKitScreenKind` plus the Questo hangman in `PlayAdvancedView`.
    /// The list is not `PlayKitScreenKind` alone: hangman is not a second screen kind.
    static var gameSections: [String] {
        (PlayKitScreenKind.allCases.map(\.rawValue) + ["hangman"]).map { "game." + $0.lowercased() }
    }
    public static var keys: [String] {
        Array(Set(base + storyBlocks.map { "chapter.blocks." + $0 } + answers + kitAnswers + sensors + features + gameSections)).sorted()
    }
    /// `key@version` rows for `supportedCapabilities`.
    public static var tokens: [String] { keys.map { "\($0)@\(version)" } }
    public static func declaration(_ keys: [String]) -> String {
        keys.sorted().map { "\($0)@\(version)" }.joined(separator: ",")
    }
    /// Fields merged into `api/play/advanced/start`. The mini-program `declaration()` sends
    /// `supportedCapabilities` as one comma-joined `key@version` string (`declaration(_:)`).
    /// This build sends the same field name as an array and `clientPlatform` `ios-native`.
    public static func startFields(clientVersion: String? = bundleVersion) -> [String: PlayWireValue] {
        var fields: [String: PlayWireValue] = [
            "clientPlatform": .string(platform),
            "supportedCapabilities": .array(tokens.map { .string($0) }),
        ]
        if let clientVersion, clientVersion.range(of: #"^[0-9A-Za-z._-]{1,32}$"#, options: .regularExpression) != nil {
            fields["clientVersion"] = .string(clientVersion)
        }
        return fields
    }
    /// Query fields for `GET /api/play/nodes` (`clientPlatform`, `clientVersion`, `capabilities`).
    public static func nodesQuery(clientVersion: String?) -> [String: String] {
        var fields = ["clientPlatform": platform, "capabilities": tokens.joined(separator: ",")]
        if let clientVersion, clientVersion.range(of: #"^[0-9A-Za-z._-]{1,32}$"#, options: .regularExpression) != nil {
            fields["clientVersion"] = clientVersion
        }
        return fields
    }
    public static var bundleVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
