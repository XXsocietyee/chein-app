import Foundation

/// UG-01…UG-10 player facts from zip-v35.
/// The candidate pack is NOT_RUN. These types decode a server payload. They do not draw a screen,
/// store an answer, open a gem or coin wallet, or offer a skip control.
/// A feature stays hidden unless the caller grant is present. A named server key that the
/// declaration marks missing hides that feature. UNKNOWN, null, and a numeric string stay
/// `.unknown` and are never stored as 0. A literal JSON 0 stays 0.
public enum UGFeature: String, Equatable, Sendable, CaseIterable {
    case hangman = "UG-01"
    case imageOption = "UG-02"
    case accusation = "UG-03"
    case earlyClose = "UG-04"
    case hintLadder = "UG-05"
    case freeQuota = "UG-06"
    case helpReceipt = "UG-07"
    case skip = "UG-08"
    case receiptUnknown = "UG-09"
    case clueTransform = "UG-10"

    public static let displayOrder: [UGFeature] = [
        .hangman, .imageOption, .accusation, .earlyClose, .hintLadder,
        .freeQuota, .helpReceipt, .skip, .receiptUnknown, .clueTransform
    ]

    /// Keys named by content-schema.v1.json. Hint ladder, quota, receipt, skip, and clue
    /// transform produce none. Accusation reuses `game.qa` and has no key of its own.
    public var serverKeys: [String] {
        switch self {
        case .hangman: return ["game.hangman"]
        case .imageOption: return ["media.image"]
        case .accusation: return ["game.qa"]
        case .earlyClose, .hintLadder, .freeQuota, .helpReceipt, .skip, .receiptUnknown, .clueTransform:
            return []
        }
    }
}

public enum UGRefusal: Error, Equatable, Sendable {
    case productionEndpoint
    case invalidRequest
    case writesNotAvailable
}

public enum UGNumberFact: Equatable, Sendable {
    case unknown
    case value(Int)

    /// A server literal, including 0 when the server sent 0. Unknown is nil.
    public var literal: Int? {
        if case .value(let number) = self { return number }
        return nil
    }

    public static func parse(_ value: PlayWireValue) -> UGNumberFact {
        switch value {
        case .integer(let raw):
            guard let number = Int(exactly: raw) else { return .unknown }
            return .value(number)
        case .number(let raw):
            guard raw.isFinite, abs(raw) <= 9_007_199_254_740_991 else { return .unknown }
            let number = Int(raw)
            guard Double(number) == raw else { return .unknown }
            return .value(number)
        case .string, .bool, .array, .object, .null:
            return .unknown
        }
    }
}

public struct UGErrorFact: Equatable, Sendable {
    public let httpStatus: Int?
    public let businessCode: Int?
    public let message: String?

    public init(httpStatus: Int?, businessCode: Int?, message: String?) {
        self.httpStatus = httpStatus
        self.businessCode = businessCode
        self.message = message
    }
}

public enum UGServerFact<Ready: Equatable>: Equatable {
    case empty
    case error(UGErrorFact)
    case unknown
    case ready(Ready)
}

public struct UGPresentation<Ready: Equatable>: Equatable {
    public enum Phase: Equatable {
        case loading
        case empty
        case error(UGErrorFact)
        case unknown
        case ready(Ready)
    }

    public let clientCapabilityPresent: Bool
    public let serverFactPresent: Bool
    public let phase: Phase?
    public var hidden: Bool { !(clientCapabilityPresent && serverFactPresent) }

    public init(clientCapabilityPresent: Bool, serverFactPresent: Bool, phase: Phase?) {
        self.clientCapabilityPresent = clientCapabilityPresent
        self.serverFactPresent = serverFactPresent
        let revealed = clientCapabilityPresent && serverFactPresent
        if revealed {
            switch phase {
            case .loading, nil: self.phase = .unknown
            case .empty, .error, .unknown, .ready: self.phase = phase
            }
        } else if clientCapabilityPresent, case .loading? = phase {
            self.phase = .loading
        } else {
            self.phase = nil
        }
    }

    public static func loading(clientCapabilityPresent: Bool) -> Self {
        Self(clientCapabilityPresent: clientCapabilityPresent, serverFactPresent: false, phase: .loading)
    }
}

public struct UGCapability: Equatable, Sendable {
    public let granted: Set<UGFeature>
    /// Exact server keys this build can satisfy. Empty satisfies nothing.
    public let supportedServerKeys: Set<String>

    public init(granted: Set<UGFeature> = [], supportedServerKeys: Set<String> = []) {
        self.granted = granted
        self.supportedServerKeys = supportedServerKeys
    }

    public static let none = UGCapability()
    public func allows(_ feature: UGFeature) -> Bool { granted.contains(feature) }
}

public struct UGRequiredCapability: Equatable, Sendable {
    public let key: String
    public let minVersion: Int

    public init(key: String, minVersion: Int) {
        self.key = key
        self.minVersion = minVersion
    }
}

/// `supported == nil` is unconfirmed. It is not “unsupported”, and it does not block the read.
public struct UGCompatibility: Equatable, Sendable {
    public let declared: Bool
    public let supported: Bool?
    public let source: String
    public let missingKeys: [String]

    public init(declared: Bool, supported: Bool?, source: String, missingKeys: [String]) {
        self.declared = declared
        self.supported = supported
        self.source = source
        self.missingKeys = missingKeys
    }

    /// `key@version` comma list from `ContentCapabilityRequirements.Declaration`. An array is not accepted.
    public static func evaluate(required: [UGRequiredCapability], supportedCapabilities: String) -> UGCompatibility {
        let trimmed = supportedCapabilities.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return UGCompatibility(declared: false, supported: nil, source: "UNDECLARED", missingKeys: [])
        }
        var versions: [String: Int] = [:]
        var malformed = false
        for token in trimmed.split(separator: ",", omittingEmptySubsequences: false) {
            guard let parsed = parseEntry(String(token)) else {
                malformed = true
                continue
            }
            versions[parsed.key] = max(versions[parsed.key] ?? 0, parsed.version)
        }
        if versions.isEmpty {
            return UGCompatibility(declared: false, supported: nil, source: "MALFORMED", missingKeys: [])
        }
        let missing = required.filter { requirement in
            guard let version = versions[requirement.key] else { return true }
            return version < requirement.minVersion
        }.map(\.key)
        let supported = missing.isEmpty
        return UGCompatibility(declared: true, supported: supported,
                               source: malformed ? "DECLARED_MALFORMED" : "DECLARED", missingKeys: missing)
    }

    private static func parseEntry(_ token: String) -> (key: String, version: Int)? {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mark = token.lastIndex(of: "@") else { return nil }
        let key = String(token[..<mark])
        let versionText = String(token[token.index(after: mark)...])
        guard isCapabilityKey(key), versionText.allSatisfy(\.isNumber), !versionText.isEmpty,
              let version = Int(versionText), version >= 1, String(version) == versionText else { return nil }
        return (key, version)
    }

    static func isCapabilityKey(_ key: String) -> Bool {
        let parts = key.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, let head = parts.first, isHead(head), parts.dropFirst().allSatisfy(isTail) else { return false }
        return true
    }

    private static func isHead(_ part: Substring) -> Bool {
        guard let first = part.first, first.isASCII, first.isLetter, first.isLowercase else { return false }
        return part.dropFirst().allSatisfy(isKeyCharacter)
    }

    private static func isTail(_ part: Substring) -> Bool {
        !part.isEmpty && part.allSatisfy(isKeyCharacter)
    }

    private static func isKeyCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLowercase || character.isNumber || character == "-")
    }
}

public enum UGVisibility {
    /// Absent client grant hides the feature. A declared missing server key hides it.
    /// Unconfirmed compatibility (`supported == nil`) does not.
    public static func shown(_ feature: UGFeature, capability: UGCapability, compatibility: UGCompatibility?) -> Bool {
        guard capability.allows(feature) else { return false }
        let keys = feature.serverKeys
        guard keys.allSatisfy(capability.supportedServerKeys.contains) else { return false }
        guard let compatibility, compatibility.supported != nil else { return true }
        return keys.allSatisfy { !compatibility.missingKeys.contains($0) }
    }
}

public enum UGGate {
    public static func presentation<Ready>(feature: UGFeature, capability: UGCapability, compatibility: UGCompatibility?,
                                           fact: UGServerFact<Ready>) -> UGPresentation<Ready> {
        guard UGVisibility.shown(feature, capability: capability, compatibility: compatibility) else {
            return .loading(clientCapabilityPresent: false)
        }
        let phase: UGPresentation<Ready>.Phase
        switch fact {
        case .empty: phase = .empty
        case .error(let error): phase = .error(error)
        case .unknown: phase = .unknown
        case .ready(let value): phase = .ready(value)
        }
        return UGPresentation(clientCapabilityPresent: true, serverFactPresent: true, phase: phase)
    }
}

/// Paid workshop install has no server authority. The reason is shown. An install is not completed.
public enum UGPaidWorkshopInstall {
    public static let unavailableReason = "PAID_INSTALL_AUTHORITY_UNAVAILABLE"
    public static let completesInstall = false

    public static func unavailableReason(for contentUseStatus: String?) -> String { unavailableReason }
}

public enum UGGameplay {
    public static let contractExecution = "NOT_RUN"
    /// Runtime verification has not run. This slice does not offer a skip control.
    public static let offersSkipButton = false
    /// Points already redeemable on the member ledger. There is no second wallet.
    public static let recordsGemBalance = false
    public static let hasCoinWallet = false
    public static let accusationPublishable = false
    public static let catalogSynced = false
    public static let rendererSynced = false
}

enum UGEnvelope {
    enum Classified: Equatable {
        case error(UGErrorFact)
        case unknown
        case payload(PlayWireValue)
    }

    static func classify(data: Data, status: Int) -> Classified {
        guard (200..<300).contains(status) else {
            let root = try? JSONDecoder().decode(PlayWireValue.self, from: data)
            return .error(UGErrorFact(httpStatus: status, businessCode: businessCode(root?["code"] ?? .null),
                                      message: text(root?["msg"] ?? .null)))
        }
        guard let root = try? JSONDecoder().decode(PlayWireValue.self, from: data), root.object != nil else {
            return .error(UGErrorFact(httpStatus: status, businessCode: nil, message: nil))
        }
        guard let code = businessCode(root["code"]) else {
            return .error(UGErrorFact(httpStatus: status, businessCode: nil, message: text(root["msg"])))
        }
        guard code == 200 else {
            return .error(UGErrorFact(httpStatus: status, businessCode: code, message: text(root["msg"])))
        }
        let payload = root.object?["data"] ?? .null
        if case .null = payload { return .unknown }
        return .payload(payload)
    }

    static func businessCode(_ value: PlayWireValue) -> Int? {
        if let number = value.integer { return number }
        return value.tolerantInteger
    }

    static func text(_ value: PlayWireValue) -> String? {
        guard case .string(let raw) = value else { return nil }
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        return raw
    }
}

enum UGMediaRef {
    /// A player image is an https URL or a site path. A raw `media-asset:` reference is not shown.
    static func playerURL(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty, !raw.contains("\\") else { return nil }
        if raw.hasPrefix("media-asset:") || raw.hasPrefix("http://") || raw.hasPrefix("data:") || raw.hasPrefix("//") {
            return nil
        }
        if raw.hasPrefix("https://") || (raw.hasPrefix("/") && !raw.hasPrefix("//")) { return raw }
        return nil
    }
}

public struct UGHangmanSlot: Equatable {
    public let index: Int
    public let kind: String
    /// A blank slot does not keep a revealed character.
    public let character: String?
}

public struct UGHangmanProjection: Equatable {
    public let length: UGNumberFact
    public let blankCount: UGNumberFact
    /// Nil when the result omits the flag. A projection without it is not ready.
    public let caseSensitive: Bool?
    public let solved: Bool
    public let display: String
    public let slots: [UGHangmanSlot]
    public let answerText: String?
    public var storesAnswerLocally: Bool { false }
    public var catalogSynced: Bool { UGGameplay.catalogSynced }
    public var judgesLocally: Bool { false }
}

public enum UGHangman {
    static let privateKeys: Set<String> = ["answer", "aliases", "format"]
    static let kinds: Set<String> = ["SEPARATOR", "PREFILLED", "FILLED", "BLANK"]

    public static func decodeProjection(data: Data, status: Int) -> UGServerFact<UGHangmanProjection> {
        switch UGEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return projection(payload, result: false)
        }
    }

    public static func decodeResult(data: Data, status: Int) -> UGServerFact<UGHangmanProjection> {
        switch UGEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return projection(payload, result: true)
        }
    }

    /// The three submit shapes. The encoded object never carries the answer.
    public static func submitData(input: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["input": input], options: [.sortedKeys])
    }

    public static func submitData(slots: [Int: String]) throws -> Data {
        let body = Dictionary(uniqueKeysWithValues: slots.map { (String($0.key), $0.value) })
        try JSONSerialization.data(withJSONObject: ["slots": body], options: [.sortedKeys])
    }

    private static func projection(_ payload: PlayWireValue, result: Bool) -> UGServerFact<UGHangmanProjection> {
        guard let object = payload.object else { return .unknown }
        if !privateKeys.isDisjoint(with: object.keys) { return .unknown }
        guard let solved = object["solved"]?.bool, let display = UGEnvelope.text(object["display"] ?? .null) else { return .unknown }
        let length = UGNumberFact.parse(object["length"] ?? .null)
        let blankCount = UGNumberFact.parse(object["blankCount"] ?? .null)
        if !result {
            guard case .value = length, case .value = blankCount, object["caseSensitive"]?.bool != nil else { return .unknown }
        }
        let caseSensitive = object["caseSensitive"]?.bool
        if !result, object["slots"]?.array == nil { return .unknown }
        let slots = decodeSlots(object["slots"] ?? .null)
        guard let slots else { return .unknown }
        let verdict = UGEnvelope.text(object["verdict"] ?? .null)
        let answerText = UGEnvelope.text(object["answerText"] ?? .null)
        if result {
            guard verdict == "CORRECT" || verdict == "WRONG" else { return .unknown }
            if verdict == "WRONG" || solved == false {
                if answerText != nil { return .unknown }
            }
            if verdict == "CORRECT", solved == false { return .unknown }
            if verdict == "WRONG", solved { return .unknown }
        } else if answerText != nil {
            return .unknown
        }
        let revealed = (result && verdict == "CORRECT" && solved) ? answerText : nil
        return .ready(UGHangmanProjection(length: length, blankCount: blankCount, caseSensitive: caseSensitive,
                                          solved: solved, display: display, slots: slots, answerText: revealed))
    }

    private static func decodeSlots(_ value: PlayWireValue) -> [UGHangmanSlot]? {
        if case .null = value { return [] }
        guard let rows = value.array else { return nil }
        var slots: [UGHangmanSlot] = []
        for row in rows {
            guard let object = row.object, let index = object["i"]?.integer, let kind = UGEnvelope.text(object["kind"] ?? .null),
                  kinds.contains(kind) else { return nil }
            let raw = UGEnvelope.text(object["ch"] ?? .null)
            let character: String?
            if kind == "BLANK" {
                character = nil
            } else {
                character = raw
            }
            slots.append(UGHangmanSlot(index: index, kind: kind, character: character))
        }
        return slots
    }
}

public struct UGImageChoice: Equatable {
    public let optionID: String
    public let label: String
    public let alt: String?
    /// Nil when the server sent no deliverable image. The raw media reference is not kept.
    public let imageURL: String?
    public var showsImage: Bool { imageURL != nil }
    public var textOnly: Bool { imageURL == nil }
    public var submitsOptionID: Bool { true }
}

public struct UGImageOptionSet: Equatable {
    public let options: [UGImageChoice]
    public var storesCorrect: Bool { false }
    public var storesFeedback: Bool { false }
}

public enum UGImageOption {
    public static func decode(data: Data, status: Int) -> UGServerFact<UGImageOptionSet> {
        switch UGEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload):
            let rows = payload["options"].array ?? payload.array
            guard let rows else { return .unknown }
            var options: [UGImageChoice] = []
            for row in rows {
                guard let object = row.object, let id = UGEnvelope.text(object["id"] ?? .null),
                      let label = UGEnvelope.text(object["label"] ?? .null) else { return .unknown }
                let imageURL = UGMediaRef.playerURL(UGEnvelope.text(object["img"] ?? .null))
                let alt = imageURL == nil ? nil : UGEnvelope.text(object["alt"] ?? .null)
                options.append(UGImageChoice(optionID: id, label: label, alt: alt, imageURL: imageURL))
            }
            return .ready(UGImageOptionSet(options: options))
        }
    }
}

public struct UGTestimony: Equatable {
    public let key: String
    public let text: String
}

public struct UGAccusationCard: Equatable {
    public let id: String
    public let name: String
    public let identity: String?
    public let avatarURL: String?
    public let testimony: [UGTestimony]
}

public struct UGAccusationPublic: Equatable {
    public let enabled: Bool
    public let suspects: [UGAccusationCard]
    public let introScreens: [String]
    public let corkboardURL: String?
    public let corkboardAlt: String?
    public let earlyAllowed: Bool?
    public var publishable: Bool { false }
    public var authorStatus: String { "待运行验证" }
    public var selectingConsumesChance: Bool { false }
    public var countsAttemptsLocally: Bool { false }
    public var showsRecordAs: Bool { false }
}

public struct UGAccusationOutcome: Equatable {
    public enum Label: String, Equatable {
        case normal = "正常结案"
        case early = "提前结案"
        case failed = "指认失败"
        case progressPending = "待确认"
        case settlementPending = "结算确认中"
    }

    public let label: Label?
    public let endingCopy: String?
    public let consumesChance: Bool?
    public let isFailure: Bool
    public let isSuccessfulAccusation: Bool
    public let grantsSuccessReward: Bool
    public var showsRecordAs: Bool { false }
    public var showsInternalCode: Bool { false }
}

public enum UGAccusation {
    static let secretKeys: Set<String> = ["correct", "correctSuspectId", "winScreen", "loseScreen", "recordAs", "requires", "answer", "fb", "fbImgs"]

    public static func decodePublic(data: Data, status: Int) -> UGServerFact<UGAccusationPublic> {
        switch UGEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return publicView(payload)
        }
    }

    public static func decodeOutcome(data: Data, status: Int) -> UGServerFact<UGAccusationOutcome> {
        switch UGEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return outcome(payload)
        }
    }

    private static func publicView(_ payload: PlayWireValue) -> UGServerFact<UGAccusationPublic> {
        guard let object = payload.object, let enabled = object["enabled"]?.bool else { return .unknown }
        if !secretKeys.isDisjoint(with: object.keys) { return .unknown }
        if let early = object["earlyAccuse"]?.object, early["recordAs"] != nil { return .unknown }
        var cards: [UGAccusationCard] = []
        for row in object["suspects"]?.array ?? [] {
            guard let card = row.object, let id = UGEnvelope.text(card["id"] ?? .null),
                  let name = UGEnvelope.text(card["name"] ?? .null) else { return .unknown }
            var testimony: [UGTestimony] = []
            for item in card["testimony"]?.array ?? [] {
                guard let fact = item.object, let key = UGEnvelope.text(fact["key"] ?? .null),
                      let text = UGEnvelope.text(fact["text"] ?? .null) else { return .unknown }
                testimony.append(UGTestimony(key: key, text: text))
            }
            cards.append(UGAccusationCard(id: id, name: name, identity: UGEnvelope.text(card["identity"] ?? .null),
                                          avatarURL: UGMediaRef.playerURL(UGEnvelope.text(card["avatar"] ?? .null)),
                                          testimony: testimony))
        }
        let screens = (object["introScreens"]?.array ?? []).compactMap(canonical)
        let board = corkboard(object["corkboardImage"] ?? .null)
        let earlyAllowed = object["earlyAccuse"]?["allowed"].bool
        return .ready(UGAccusationPublic(enabled: enabled, suspects: cards, introScreens: screens,
                                         corkboardURL: board?.url, corkboardAlt: board?.alt, earlyAllowed: earlyAllowed))
    }

    private static func outcome(_ payload: PlayWireValue) -> UGServerFact<UGAccusationOutcome> {
        guard let object = payload.object else { return .unknown }
        let early = object["early"]
        let earlyBool = early?.bool
        let progressUnreadable = early == nil || earlyBool == nil
        let verdict = UGEnvelope.text(object["verdict"] ?? .null)
        if progressUnreadable {
            return .ready(UGAccusationOutcome(label: .progressPending, endingCopy: nil, consumesChance: nil,
                                              isFailure: false, isSuccessfulAccusation: false, grantsSuccessReward: false))
        }
        let refused = verdict == "REFUSED"
        let label: UGAccusationOutcome.Label?
        var copy: String?
        var failure = false
        var successAccusation = false
        if earlyBool == true {
            label = .early
            copy = UGEnvelope.text(object["winScreen"] ?? .null)
        } else if verdict == "CORRECT" {
            label = .normal
            copy = UGEnvelope.text(object["winScreen"] ?? .null)
            successAccusation = true
        } else if verdict == "FAILED" {
            label = .failed
            copy = UGEnvelope.text(object["loseScreen"] ?? .null)
            failure = true
        } else if verdict == nil {
            label = .settlementPending
        } else {
            label = nil
        }
        let consumes: Bool? = refused ? false : nil
        let reward = successAccusation && earlyBool != true
        return .ready(UGAccusationOutcome(label: label, endingCopy: copy, consumesChance: consumes, isFailure: failure,
                                          isSuccessfulAccusation: successAccusation, grantsSuccessReward: reward))
    }

    private static func corkboard(_ value: PlayWireValue) -> (url: String?, alt: String?)? {
        switch value {
        case .null: return nil
        case .string(let raw): return (UGMediaRef.playerURL(raw), nil)
        case .object(let fields):
            let url = UGMediaRef.playerURL(UGEnvelope.text(fields["img"] ?? .null))
            let alt = url == nil ? nil : UGEnvelope.text(fields["alt"] ?? .null)
            return (url, alt)
        default: return (nil, nil)
        }
    }

    private static func canonical(_ value: PlayWireValue) -> String? {
        guard let data = try? JSONEncoder().encode(value), let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}

public struct UGHelpLayer: Equatable {
    public let level: UGNumberFact
    public let type: String?
    public let serverUsable: Bool?
    public let unlocked: Bool?
    public let free: Bool?
    public let costPoints: UGNumberFact
    public let freeQuota: UGNumberFact
    public let reason: String?
    public let currencyRejected: Bool
    public let blockedUntilPrevious: Bool
    public var knownType: Bool {
        guard let type else { return false }
        return ["TEXT", "IMAGE", "LETTER", "DIGIT", "ANSWER", "SKIP"].contains(type)
    }
    public var available: Bool {
        knownType && serverUsable == true && unlocked != nil && free != nil && costPoints.literal != nil &&
        !currencyRejected && reason != "HELP_TYPE_UNSUPPORTED" && type != "LOCATION" && type != "SKIP" && !blockedUntilPrevious
    }
    /// Skip is never a control in this slice. Reveal is not skip.
    public var offersSkipButton: Bool { false }
    public var showsPerLayerFreeCount: Bool { false }
    public var renderedPerLayerFreeQuota: Int? { nil }
    public var serverMarksFirstUnlockFree: Bool { free == true && unlocked == false }
    /// Author price 0 is explicit and does not spend the shared run quota.
    public var spendsPointsOnFirstUnlock: Bool {
        guard free == false, unlocked == false, let points = costPoints.literal else { return false }
        return points > 0
    }
    public var playerLine: String? {
        if !knownType || currencyRejected || reason == "HELP_TYPE_UNSUPPORTED" || type == "LOCATION" || type == "SKIP" {
            return nil
        }
        if blockedUntilPrevious, unlocked != true { return "需先看上一层" }
        if unlocked == true { return "重看·免费" }
        if free == true { return "免费" }
        if let points = costPoints.literal { return "消耗 \(points) 积分" }
        return nil
    }
}

public struct UGHelpView: Equatable {
    public let runID: UGNumberFact
    public let nodeID: UGNumberFact
    public let keepsLegacyHintChain: Bool
    public let layers: [UGHelpLayer]
    /// Absent on the help-view schema. A missing key stays unknown and is not 0.
    public let remainingFreeUses: UGNumberFact
    public static let unavailableCopy = "提示暂不可用"

    /// The counter is hidden with the free-quota grant. Unknown stays nil, never 0.
    public func renderedRemaining(capability: UGCapability, compatibility: UGCompatibility? = nil) -> Int? {
        guard UGVisibility.shown(.freeQuota, capability: capability, compatibility: compatibility) else { return nil }
        return remainingFreeUses.literal
    }
    public static let insufficientCopy = "积分不足，本层未解锁"
    public var rendersRemainingAsZero: Bool { false }
    public var decrementsQuotaLocally: Bool { false }
    public var recordsGemBalance: Bool { false }
}

public struct UGHelpUseFact: Equatable {
    public let runID: UGNumberFact
    public let nodeID: UGNumberFact
    public let level: UGNumberFact
    public let type: String?
    public let content: String?
    public let applied: Bool?
    public let alreadyUnlocked: Bool?
    public let chargedPoints: UGNumberFact
    public let balanceAfter: UGNumberFact
    public let insufficient: Bool
    public var hasReplayedField: Bool { false }
    public var recordsGemBalance: Bool { false }
    public var cutsAnswerLocally: Bool { false }
    public var offersSkipButton: Bool { false }
}

public enum UGHelp {
    static let knownTypes: Set<String> = ["TEXT", "IMAGE", "LETTER", "DIGIT", "ANSWER", "SKIP"]

    public static func decodeView(data: Data, status: Int) -> UGServerFact<UGHelpView> {
        switch UGEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return view(payload)
        }
    }

    public static func decodeUse(data: Data, status: Int) -> UGServerFact<UGHelpUseFact> {
        switch UGEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return use(payload)
        }
    }

    private static func view(_ payload: PlayWireValue) -> UGServerFact<UGHelpView> {
        guard let object = payload.object, let enabled = object["enabled"]?.bool, let rows = object["layers"]?.array else {
            return .unknown
        }
        var layers: [UGHelpLayer] = []
        for row in rows {
            guard let layer = row.object else { return .unknown }
            layers.append(decodeLayer(layer))
        }
        // A locked earlier layer does not rewrite a later layer. The contract hint policy
        // reports that later layer usable and leaves its free/cost fields unchanged.
        let legacy = !enabled || layers.isEmpty
        let remaining = object.keys.contains("remainingFreeUses") ? UGNumberFact.parse(object["remainingFreeUses"] ?? .null) : .unknown
        return .ready(UGHelpView(runID: UGNumberFact.parse(object["runId"] ?? .null),
                                 nodeID: UGNumberFact.parse(object["nodeId"] ?? .null),
                                 keepsLegacyHintChain: legacy, layers: legacy ? [] : layers, remainingFreeUses: remaining))
    }

    private static func decodeLayer(_ object: [String: PlayWireValue]) -> UGHelpLayer {
        let type = UGEnvelope.text(object["type"] ?? .null)
        let rejected = rejectsCurrency(object)
        return UGHelpLayer(level: UGNumberFact.parse(object["level"] ?? .null), type: type,
                           serverUsable: object["usable"]?.bool, unlocked: object["unlocked"]?.bool, free: object["free"]?.bool,
                           costPoints: UGNumberFact.parse(object["costPoints"] ?? .null),
                           freeQuota: UGNumberFact.parse(object["freeQuota"] ?? .null),
                           reason: object["reason"] == nil || object["reason"] == .null ? nil : UGEnvelope.text(object["reason"] ?? .null),
                           currencyRejected: rejected, blockedUntilPrevious: false)
    }

    static func rejectsCurrency(_ object: [String: PlayWireValue]) -> Bool {
        if nonzero(object["gems"]) || nonzero(object["coins"]) { return true }
        if let cost = object["cost"]?.object, nonzero(cost["gems"]) || nonzero(cost["coins"]) { return true }
        return false
    }

    private static func nonzero(_ value: PlayWireValue?) -> Bool {
        guard let value else { return false }
        switch value {
        case .null: return false
        case .integer(let number): return number != 0
        case .number(let number): return number != 0
        default: return true
        }
    }

    private static func use(_ payload: PlayWireValue) -> UGServerFact<UGHelpUseFact> {
        guard let object = payload.object else { return .unknown }
        if object["replayed"] != nil { return .unknown }
        let type = UGEnvelope.text(object["type"] ?? .null)
        let insufficient = UGEnvelope.text(object["reason"] ?? .null) == "POINTS_INSUFFICIENT"
        var content = UGEnvelope.text(object["content"] ?? .null)
        if insufficient || type == nil || !knownTypes.contains(type ?? "") || type == "SKIP" {
            content = nil
        }
        if let type, (type == "LETTER" || type == "DIGIT"), let current = content, current.unicodeScalars.count != 1 {
            content = nil
        }
        return .ready(UGHelpUseFact(runID: UGNumberFact.parse(object["runId"] ?? .null),
                                    nodeID: UGNumberFact.parse(object["nodeId"] ?? .null),
                                    level: UGNumberFact.parse(object["level"] ?? .null), type: type, content: content,
                                    applied: object["applied"]?.bool, alreadyUnlocked: object["alreadyUnlocked"]?.bool,
                                    chargedPoints: UGNumberFact.parse(object["chargedPoints"] ?? .null),
                                    balanceAfter: UGNumberFact.parse(object["balanceAfter"] ?? .null),
                                    insufficient: insufficient))
    }
}

public enum UGQuotaFinding: Equatable {
    case legacyNull
    case value(Int)
    case conflict
    case invalid

    public var conflictReason: String? {
        if case .conflict = self { return "PLAY_HELP_RUN_QUOTA_DECLARED_CONFLICT" }
        return nil
    }

    public var invalidReason: String? {
        if case .invalid = self { return "PLAY_HELP_RUN_QUOTA_CONFIG_INVALID" }
        return nil
    }

    /// Root does not win a conflict. Unknown is not 0. Explicit 0 stays 0.
    public var literal: Int? {
        if case .value(let number) = self { return number }
        return nil
    }
}

public enum UGRunQuota {
    public static func read(data: Data) -> UGQuotaFinding {
        guard let value = try? JSONDecoder().decode(PlayWireValue.self, from: data) else { return .invalid }
        return read(value)
    }

    public static func read(_ value: PlayWireValue) -> UGQuotaFinding {
        var found = Found()
        walk(value, into: &found, depth: 0)
        if found.invalid { return .invalid }
        let unique = Set(found.numbers)
        if unique.count > 1 { return .conflict }
        if let only = unique.first { return .value(only) }
        if found.ladder { return .value(0) }
        return .legacyNull
    }

    private struct Found {
        var numbers: [Int] = []
        var invalid = false
        var ladder = false
    }

    private static func walk(_ value: PlayWireValue, into found: inout Found, depth: Int) {
        guard depth < 64 else { return }
        if case .array(let items) = value {
            for item in items { walk(item, into: &found, depth: depth + 1) }
            return
        }
        guard let fields = value.object else { return }
        for key in fields.keys.sorted() {
            let child = fields[key] ?? .null
            if key == "hintFreeUsesPerRun" {
                note(child, into: &found)
            } else if key == "hintLadder" {
                if case .array(let items) = child, !items.isEmpty { found.ladder = true }
                walk(child, into: &found, depth: depth + 1)
            } else if key == "advancedConfigJson", case .string(let raw) = child,
                      let data = raw.data(using: .utf8),
                      let nested = try? JSONDecoder().decode(PlayWireValue.self, from: data) {
                walk(nested, into: &found, depth: depth + 1)
            } else {
                walk(child, into: &found, depth: depth + 1)
            }
        }
    }

    private static func note(_ value: PlayWireValue, into found: inout Found) {
        switch value {
        case .null:
            return
        case .integer(let raw):
            guard let number = Int(exactly: raw), (0...1000).contains(number) else {
                found.invalid = true
                return
            }
            found.numbers.append(number)
        case .number:
            found.invalid = true
        default:
            found.invalid = true
        }
    }
}

public struct UGHelpUseDraft: Equatable {
    public let runID: Int
    public let nodeID: Int
    public let level: Int
    public let requestID: String
    public let costPoints: Int

    public init(runID: Int, nodeID: Int, level: Int, requestID: String, costPoints: Int) {
        self.runID = runID
        self.nodeID = nodeID
        self.level = level
        self.requestID = requestID
        self.costPoints = costPoints
    }
}

public enum UGHelpResend: Equatable {
    case same
    case differentRequest
    case conflict

    public var replacementRequestID: String? { nil }
    public var playerCopy: String? {
        if case .conflict = self { return "请求内容已变化，请刷新后重试" }
        return nil
    }
}

public enum UGHelpIdempotency {
    public static func resend(_ next: UGHelpUseDraft, original: UGHelpUseDraft) -> UGHelpResend {
        guard next.requestID == original.requestID else { return .differentRequest }
        return next == original ? .same : .conflict
    }

    public static let unknownCopy = "结果待确认"
}

public struct UGHelpReceiptLevel: Equatable {
    public let level: UGNumberFact
    public let type: String?
    public let free: Bool?
    public let pointsCharged: UGNumberFact
}

public struct UGHelpReceiptFact: Equatable {
    public let scoreState: String?
    public let baseScore: UGNumberFact
    public let bonus: UGNumberFact
    public let bonusSource: String?
    public let helpDeduction: UGNumberFact
    public let skipDeduction: UGNumberFact
    public let netScore: UGNumberFact
    public let pointsCharged: UGNumberFact
    public let skipped: Bool?
    public let assisted: Bool?
    public let reason: String?
    public let levels: [UGHelpReceiptLevel]?
    public let detailMissing: Bool
    public var renderedNetScore: Int? {
        guard scoreState == "SCORED" else { return nil }
        return netScore.literal
    }
    public var notScoredCopy: String? { scoreState == "NOT_SCORED" ? "本题不计分" : nil }
    public var detailMissingCopy: String? { detailMissing ? "明细待补" : nil }
    public static let unavailableCopy = "结算明细暂不可用"
    public var skippedLabel: String? { skipped == true ? "已跳过" : nil }
    public var skipPhrase: String? {
        guard skipped == true, scoreState == "SCORED", netScore.literal == 0 else { return nil }
        return "本题跳过 · 记 0 分 · 辅助完成"
    }
    public var revealPhrase: String? {
        guard assisted == true, skipped == false else { return nil }
        return "揭示答案，未自行解出"
    }
    public var revealIsSkip: Bool { false }
    public var pointsEnterNetScore: Bool { false }
    public var claimsGlobalRank: Bool { false }
    public var didComputeNet: Bool { false }
    public var didSynthesizeZeroRow: Bool { false }
    public var offersSkipButton: Bool { false }
    public var recordsGemBalance: Bool { false }
}

public enum UGHelpReceipt {
    public static func decode(data: Data, status: Int) -> UGServerFact<UGHelpReceiptFact> {
        switch UGEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return receipt(payload)
        }
    }

    private static func receipt(_ payload: PlayWireValue) -> UGServerFact<UGHelpReceiptFact> {
        guard let object = payload.object else { return .unknown }
        let state = UGEnvelope.text(object["scoreState"] ?? .null)
        guard state == "SCORED" || state == "NOT_SCORED" else { return .unknown }
        let levels: [UGHelpReceiptLevel]?
        let detailMissing: Bool
        if object["levels"] == nil || object["levels"] == .null {
            levels = nil
            detailMissing = true
        } else if let rows = object["levels"]?.array {
            levels = rows.compactMap(level)
            if levels?.count != rows.count { return .unknown }
            detailMissing = false
        } else {
            return .unknown
        }
        return .ready(UGHelpReceiptFact(scoreState: state,
                                        baseScore: UGNumberFact.parse(object["baseScore"] ?? .null),
                                        bonus: UGNumberFact.parse(object["bonus"] ?? .null),
                                        bonusSource: UGEnvelope.text(object["bonusSource"] ?? .null),
                                        helpDeduction: UGNumberFact.parse(object["helpDeduction"] ?? .null),
                                        skipDeduction: UGNumberFact.parse(object["skipDeduction"] ?? .null),
                                        netScore: UGNumberFact.parse(object["netScore"] ?? .null),
                                        pointsCharged: UGNumberFact.parse(object["pointsCharged"] ?? .null),
                                        skipped: object["skipped"]?.bool, assisted: object["assisted"]?.bool,
                                        reason: UGEnvelope.text(object["reason"] ?? .null), levels: levels,
                                        detailMissing: detailMissing))
    }

    private static func level(_ value: PlayWireValue) -> UGHelpReceiptLevel? {
        guard let object = value.object else { return nil }
        return UGHelpReceiptLevel(level: UGNumberFact.parse(object["level"] ?? .null),
                                  type: UGEnvelope.text(object["type"] ?? .null), free: object["free"]?.bool,
                                  pointsCharged: UGNumberFact.parse(object["pointsCharged"] ?? .null))
    }
}

public struct UGActionReceipt: Equatable {
    public enum Disposition: Equatable {
        case discarded
        case pendingConfirmation
        case refreshRequired
        case terminal
        case retrySameRequest
        case explicitFailure
    }

    public let disposition: Disposition
    public let allowsNewActionID: Bool
    public let keepsRequestID: Bool
    public let isFailure: Bool
    public let checksOriginalReceipt: Bool
    public var pendingCopy: String? {
        disposition == .pendingConfirmation ? "待确认" : nil
    }
}

public enum UGActionReceiptClassifier {
    /// New submits keep the original action id. Unknown stays 待确认 and is not failure.
    /// A changed account or run discards the body.
    public static func classify(data: Data, status: Int, scopeMatches: Bool) -> UGActionReceipt {
        if !scopeMatches {
            return UGActionReceipt(disposition: .discarded, allowsNewActionID: false, keepsRequestID: true,
                                   isFailure: false, checksOriginalReceipt: false)
        }
        let root = try? JSONDecoder().decode(PlayWireValue.self, from: data)
        let rootObject = root?.object ?? [:]
        let object = rootObject["data"]?.object ?? rootObject
        let receiptState = UGEnvelope.text(object["receiptState"] ?? rootObject["receiptState"] ?? .null)
        if status == 520, receiptState == "PENDING" || receiptState == "UNKNOWN" {
            return pending()
        }
        if let code = UGEnvelope.businessCode(rootObject["code"] ?? .null), code != 200 {
            return UGActionReceipt(disposition: .explicitFailure, allowsNewActionID: true, keepsRequestID: false,
                                   isFailure: true, checksOriginalReceipt: false)
        }
        let terminal = object["intentTerminal"]?.bool == true
        let newID = object["newActionIdRequired"]?.bool == true
        if terminal || newID {
            return UGActionReceipt(disposition: .terminal, allowsNewActionID: newID, keepsRequestID: !newID,
                                   isFailure: false, checksOriginalReceipt: false)
        }
        let terminalAbsent = !object.keys.contains("intentTerminal") || object["intentTerminal"] == .null
        let executedAbsent = !object.keys.contains("intentNotExecuted") || object["intentNotExecuted"] == .null
        if (200..<300).contains(status), terminalAbsent, executedAbsent {
            return pending()
        }
        if object["refreshRequired"]?.bool == true {
            return UGActionReceipt(disposition: .refreshRequired, allowsNewActionID: false, keepsRequestID: true,
                                   isFailure: false, checksOriginalReceipt: true)
        }
        if object["retryable"]?.bool == true {
            return UGActionReceipt(disposition: .retrySameRequest, allowsNewActionID: false, keepsRequestID: true,
                                   isFailure: false, checksOriginalReceipt: false)
        }
        if object["intentNotExecuted"]?.bool == true || !(200..<300).contains(status) ||
            (UGEnvelope.businessCode(object["code"] ?? .null).map { $0 != 200 } ?? false) {
            return UGActionReceipt(disposition: .explicitFailure, allowsNewActionID: true, keepsRequestID: false,
                                   isFailure: true, checksOriginalReceipt: false)
        }
        return pending()
    }

    private static func pending() -> UGActionReceipt {
        UGActionReceipt(disposition: .pendingConfirmation, allowsNewActionID: false, keepsRequestID: true,
                        isFailure: false, checksOriginalReceipt: true)
    }
}

public struct UGCluePresentation: Equatable {
    public enum Mode: Equatable {
        case standard
        case mirror
        case reverse
        case unrecognized
    }

    public let mode: Mode
    public let questionText: String
    public let textLayerScaleX: Int
    public let includesClueTransformKey: Bool
    public let reportsUnrecognized: Bool
    public let rejectedCipher: Bool
    public var reversesAgain: Bool { false }
    public var flipsPage: Bool { false }
    public var flipsControls: Bool { false }
    public var usesMirrorImage: Bool { false }
    public var exposesOriginalToVoiceOver: Bool { false }
    public var presentationName: String {
        switch mode {
        case .standard: return "原样"
        case .mirror: return "镜像"
        case .reverse: return "倒序"
        case .unrecognized: return "原样"
        }
    }
}

public enum UGClueTransform {
    public static func decode(data: Data, status: Int) -> UGServerFact<UGCluePresentation> {
        switch UGEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return clue(payload)
        }
    }

    private static func clue(_ payload: PlayWireValue) -> UGServerFact<UGCluePresentation> {
        guard let object = payload.object, let question = object["question"] else { return .unknown }
        guard case .string(let text) = question else { return .unknown }
        guard object.keys.contains("clueTransform"), object["clueTransform"] != .null else {
            return .ready(UGCluePresentation(mode: .standard, questionText: text, textLayerScaleX: 1,
                                             includesClueTransformKey: false, reportsUnrecognized: false, rejectedCipher: false))
        }
        guard let transform = object["clueTransform"]?.object, let raw = UGEnvelope.text(transform["mode"] ?? .null) else {
            return .ready(UGCluePresentation(mode: .unrecognized, questionText: text, textLayerScaleX: 1,
                                             includesClueTransformKey: true, reportsUnrecognized: true, rejectedCipher: false))
        }
        let extra = Set(transform.keys).subtracting(["mode"])
        let cipher = raw == "CYPHER" || raw == "FLIP" || !extra.isEmpty
        if cipher || (raw != "STANDARD" && raw != "MIRROR" && raw != "REVERSE") {
            return .ready(UGCluePresentation(mode: .unrecognized, questionText: text, textLayerScaleX: 1,
                                             includesClueTransformKey: true, reportsUnrecognized: true,
                                             rejectedCipher: raw == "CYPHER" || raw == "FLIP" || !extra.isEmpty))
        }
        switch raw {
        case "MIRROR":
            return .ready(UGCluePresentation(mode: .mirror, questionText: text, textLayerScaleX: -1,
                                             includesClueTransformKey: true, reportsUnrecognized: false, rejectedCipher: false))
        case "REVERSE":
            return .ready(UGCluePresentation(mode: .reverse, questionText: text, textLayerScaleX: 1,
                                             includesClueTransformKey: true, reportsUnrecognized: false, rejectedCipher: false))
        default:
            return .ready(UGCluePresentation(mode: .standard, questionText: text, textLayerScaleX: 1,
                                             includesClueTransformKey: true, reportsUnrecognized: false, rejectedCipher: false))
        }
    }
}
