import Foundation

/// Node IDs belong to play nodes. Merchant-row IDs are deliberately a different type.
public struct ShopNPCNodeID: Equatable, Hashable {
    public let rawValue: Int
    public init?(_ value: Int) { guard value > 0 else { return nil }; rawValue = value }
}
public struct ShopNPCScope: Equatable {
    public let sessionID: String
    public let accountID: String
    public let roleID: String
    public let accessRevision: UInt64
    public let nodeID: ShopNPCNodeID
    public init(sessionID: String, accountID: String, roleID: String, accessRevision: UInt64, nodeID: ShopNPCNodeID) {
        self.sessionID = sessionID; self.accountID = accountID; self.roleID = roleID
        self.accessRevision = accessRevision; self.nodeID = nodeID
    }
    public var valid: Bool { !sessionID.isEmpty && !accountID.isEmpty && !roleID.isEmpty }
}
public struct ShopNPCGrants: Equatable, Sendable {
    public var server = false
    public var provider = false
    public var legal = false
    public var access = false
    public var voiceTransmission = false
    public var voiceFormatVerified = false
    public var microphone = false
    public var playback = false
    public init() {}
    public var textAllowed: Bool { server && provider && legal && access }
    public var voiceAllowed: Bool { textAllowed && voiceTransmission && voiceFormatVerified }
}
public enum ShopNPCFailure: Error, Equatable {
    case disabled, stale, busy, invalid, rateLimited, unknownOutcome, malformed
    case replyProcessing, replyRetryable, replyRejected, replyFailed, replyUnresolved
    case server(code: Int, message: String?)
    public var key: String {
        switch self {
        case .disabled: return "shopNPC.disabled"
        case .stale: return "shopNPC.stale"
        case .busy: return "shopNPC.busy"
        case .invalid: return "shopNPC.invalid"
        case .rateLimited: return "shopNPC.rateLimited"
        case .unknownOutcome: return "shopNPC.unknownOutcome"
        case .malformed: return "shopNPC.malformed"
        case .replyProcessing: return "shopNPCOutcome.processing"
        case .replyRetryable: return "shopNPCOutcome.retryable"
        case .replyRejected: return "shopNPCOutcome.rejected"
        case .replyFailed: return "shopNPCOutcome.failed"
        // Reuse the existing neutral notice; the transport-unknown copy invites
        // retry and must not describe a server response that forbids it.
        case .replyUnresolved: return "merchantNPC.unavailable"
        case .server: return "shopNPC.server"
        }
    }
}
public enum ShopNPCRelationState: String, Decodable, Equatable {
    case ally, neutral, guarded
}
public struct ShopNPCRelationBadge: Equatable {
    public let name: String?
    public let state: ShopNPCRelationState
    public let value: Int?
    public let line: String?
    public init(name: String? = nil, state: ShopNPCRelationState, value: Int? = nil, line: String? = nil) {
        self.name = name; self.state = state; self.value = value; self.line = line
    }
    fileprivate struct Wire: Decodable {
        var name: String?; var state: String?; var value: Int?; var line: String?
    }
    fileprivate init(wire: Wire) throws {
        guard let rawState = wire.state, let state = ShopNPCRelationState(rawValue: rawState) else {
            throw ShopNPCFailure.malformed
        }
        self.init(name: wire.name, state: state, value: wire.value, line: wire.line)
    }
}
public struct ShopNPCDialogueEffect: Equatable, Identifiable {
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
    public init(type: Kind, key: String, delta: Int? = nil, value: Int? = nil, label: String? = nil) throws {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 64,
              normalized.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
            throw ShopNPCFailure.malformed
        }
        let lowered = normalized.lowercased()
        guard !Self.forbiddenKeywords.contains(where: { lowered.contains($0) }) else {
            throw ShopNPCFailure.malformed
        }
        switch type {
        case .inc:
            guard normalized.hasPrefix("relation."), normalized.count > "relation.".count,
                  let delta, delta != 0, (-10...10).contains(delta) else {
                throw ShopNPCFailure.malformed
            }
        case .addTag:
            guard normalized.hasPrefix("tag."), normalized.count > "tag.".count else {
                throw ShopNPCFailure.malformed
            }
        }
        self.type = type; self.key = normalized; self.delta = delta; self.value = value; self.label = label
        self.id = "\(type.rawValue):\(normalized):\(delta.map(String.init) ?? label ?? "")"
    }
    fileprivate struct Wire: Decodable {
        var type: String?; var key: String?; var delta: Int?; var value: Int?; var label: String?
    }
    fileprivate init(wire: Wire) throws {
        guard let rawType = wire.type, let kind = Kind(rawValue: rawType), let key = wire.key else {
            throw ShopNPCFailure.malformed
        }
        try self.init(type: kind, key: key, delta: wire.delta, value: wire.value, label: wire.label)
    }
}
public struct ShopNPCReply: Equatable {
    public enum Outcome: String, Equatable { case succeeded = "SUCCEEDED", rejected = "REJECTED", failed = "FAILED", processing = "PROCESSING" }
    public let requestID: UUID
    public let outcome: Outcome
    public let retryable: Bool
    public let retryAfterSeconds: Int?
    public let text: String
    public let asr: String?
    public let safetyDecision: String
    public let errorCode: String?
    public let relation: ShopNPCRelationBadge?
    public let effects: [ShopNPCDialogueEffect]
    /// PROCESSING is not permission to retry an unresolved provider outcome.
    public var needsRetry: Bool { retryable }
    public var hasUnknownOutcome: Bool {
        outcome == .processing && safetyDecision == "UNKNOWN" &&
        errorCode == "REQUEST_OUTCOME_UNKNOWN" && !retryable
    }
    /// This path does not consume audio. An optional server audioUrl does not
    /// establish an approved native playback capability; the legacy case name is retained.
    public let audio: ShopNPCAudioSource = .unavailableInSource
    public static func decode(_ bytes: Data, voice: Bool) throws -> Self {
        struct Envelope: Decodable {
            var code: Int?; var msg: String?; var asr: String?; var data: Payload?
            struct Payload: Decodable {
                var requestId: String?; var outcomeStatus: String?; var safetyDecision: String?
                var retryable: Bool?; var retryAfterSeconds: Int?; var safeText: String?; var errorCode: String?
                var relation: ShopNPCRelationBadge.Wire?; var effects: [ShopNPCDialogueEffect.Wire]?
            }
        }
        let body: Envelope
        do { body = try JSONDecoder().decode(Envelope.self, from: bytes) }
        catch { throw ShopNPCFailure.malformed }
        guard let code = body.code else { throw ShopNPCFailure.malformed }
        guard code == 200 else { throw ShopNPCFailure.server(code: code, message: body.msg) }
        guard let data = body.data, let request = data.requestId, let id = UUID(uuidString: request),
              let status = data.outcomeStatus, let outcome = Outcome(rawValue: status),
              let retryable = data.retryable, let safety = data.safetyDecision else { throw ShopNPCFailure.malformed }
        let unknownOutcome = outcome == .processing && safety == "UNKNOWN" &&
            data.errorCode == "REQUEST_OUTCOME_UNKNOWN" && !retryable
        guard ["PASS", "BLOCKED", "NOT_RUN"].contains(safety) || unknownOutcome else { throw ShopNPCFailure.malformed }
        // 9b emits either the one-second in-progress delay or secondsUntilTomorrow,
        // which is bounded to one day. This is not an inferred reset timestamp.
        if let seconds = data.retryAfterSeconds, !(0...86_400).contains(seconds) { throw ShopNPCFailure.malformed }
        let safe = data.safeText ?? ""
        guard safe.utf8.count <= 32_768, (body.asr?.utf8.count ?? 0) <= 32_768 else { throw ShopNPCFailure.malformed }
        if outcome == .succeeded, !retryable {
            guard safety == "PASS", !safe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ShopNPCFailure.malformed }
        }
        let relation = try data.relation.map(ShopNPCRelationBadge.init(wire:))
        let effects = try (data.effects ?? []).map(ShopNPCDialogueEffect.init(wire:))
        // No legacy data.text fallback: missing terminal evidence is not success.
        return Self(requestID: id, outcome: outcome, retryable: retryable, retryAfterSeconds: data.retryAfterSeconds,
                    text: safe, asr: voice ? body.asr : nil, safetyDecision: safety, errorCode: data.errorCode,
                    relation: relation, effects: effects)
    }
}
/// Public NPC read of one published release. Private order, customer and cost keys are withheld.
public struct ShopNPCPublicRead: Equatable, Sendable {
    public static let withheldKeys: Set<String> = ["order", "orders", "customer", "customers", "cost", "costs"]
    public let releaseID: String
    public let facts: [String: String]
    public init?(releaseID: String, stage: MerchantAuthoringStage, facts: [String: String]) {
        guard stage == .published, !releaseID.isEmpty else { return nil }
        let kept = facts.filter { !Self.withheldKeys.contains($0.key.lowercased()) }
        guard !kept.isEmpty else { return nil }
        self.releaseID = releaseID
        self.facts = kept
    }
}
public enum ShopNPCAudioSource: Equatable { case unavailableInSource }
public struct ShopNPCVoiceClip: Equatable {
    public let bytes: Data
    public let duration: TimeInterval
    public init(bytes: Data, duration: TimeInterval) throws {
        guard !bytes.isEmpty, bytes.count <= 2 * 1024 * 1024, duration >= 0.5, duration <= 60 else { throw ShopNPCFailure.invalid }
        self.bytes = bytes; self.duration = duration
    }
}
public struct ShopNPCMessage: Identifiable, Equatable {
    public enum Source: Equatable { case text, voice }
    public let id: UUID
    public let mine: Bool
    public var text: String
    public let source: Source
    public var effects: [ShopNPCDialogueEffect]
    public var hasReusableQuestion: Bool { mine && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var voiceTranscriptMissing: Bool { mine && source == .voice && !hasReusableQuestion }
    public init(id: UUID = UUID(), mine: Bool, text: String, source: Source = .text, effects: [ShopNPCDialogueEffect] = []) {
        self.id = id; self.mine = mine; self.text = text; self.source = mine ? source : .text
        self.effects = mine ? [] : effects
    }
}
