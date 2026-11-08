import Foundation

/// P4 `GET /api/play/player-journey/choices`.
/// `UNAVAILABLE` and `RUN_CONFIG_SNAPSHOT_MISSING` are empty choices, even if a list was returned.
/// A null or missing `requiredCapabilities` is not "no capability required".
/// `PER_MEMBER` is not drawn as a shared team deduction. The shared pool is not implemented.
/// Choice objects have no named fields here, so no mode is submittable.

public enum PWaveConfigState: Equatable, Sendable {
    case frozenRun
    case published
    case unavailable
    case runConfigSnapshotMissing
    case other(String)

    public static func parse(_ raw: String) -> PWaveConfigState {
        switch raw {
        case "FROZEN_RUN": return .frozenRun
        case "PUBLISHED": return .published
        case "UNAVAILABLE": return .unavailable
        case "RUN_CONFIG_SNAPSHOT_MISSING": return .runConfigSnapshotMissing
        default: return .other(raw)
        }
    }

    public var forcesEmptyChoices: Bool {
        self == .unavailable || self == .runConfigSnapshotMissing
    }
}

public struct PWavePlayModeFact: Equatable, Sendable {
    public let configState: PWaveConfigState
    public let runtimeScope: String?
    public let worldMode: String?
    public let routeMode: String?
    public let requiredCapabilities: [String]
    public let teamModeSource: String?
    /// False only for `CURRENT_TOPIC_COLUMN`. That column is not a frozen config. Other values stay unknown.
    public let topicColumnIsFrozen: Bool?
    public let choiceCount: Int
    /// True when a string value is exactly `PER_MEMBER`. Nil when the server did not say so. Nil is not false.
    public let perMemberHintAndScore: Bool?
    public var teamSharedDeductionOffered: Bool { false }
    public var modeSubmissionAvailable: Bool { false }

    public static let teamSharedPoolImplemented = false

    public init(configState: PWaveConfigState, runtimeScope: String?, worldMode: String?, routeMode: String?,
                requiredCapabilities: [String], teamModeSource: String?, topicColumnIsFrozen: Bool?,
                choiceCount: Int, perMemberHintAndScore: Bool?) {
        self.configState = configState
        self.runtimeScope = runtimeScope
        self.worldMode = worldMode
        self.routeMode = routeMode
        self.requiredCapabilities = requiredCapabilities
        self.teamModeSource = teamModeSource
        self.topicColumnIsFrozen = topicColumnIsFrozen
        self.choiceCount = choiceCount
        self.perMemberHintAndScore = perMemberHintAndScore
    }
}

public enum PWaveRequiredCapabilities: Equatable, Sendable {
    case undeclared
    case malformed
    case listed([String])
}

public enum PWavePlayMode {
    public struct Decision: Equatable, Sendable {
        public let fact: PWaveServerFact<PWavePlayModeFact>
        /// False when this payload has no usable server capability list. Errors do not fail this gate.
        public let serverCapabilitySatisfied: Bool
        public let unsatisfiedServerCapabilities: [String]
        public let serverCapabilitiesDeclared: Bool?
    }

    public static func decode(data: Data, status: Int, supportedServerCapabilities: Set<String>) -> Decision {
        switch PWaveEnvelope.classify(data: data, status: status) {
        case .error(let error):
            return Decision(fact: .error(error), serverCapabilitySatisfied: true,
                            unsatisfiedServerCapabilities: [], serverCapabilitiesDeclared: nil)
        case .unknown:
            return Decision(fact: .unknown, serverCapabilitySatisfied: false,
                            unsatisfiedServerCapabilities: [], serverCapabilitiesDeclared: false)
        case .payload(let payload):
            return decide(payload, supported: supportedServerCapabilities)
        }
    }

    static func decide(_ payload: PlayWireValue, supported: Set<String>) -> Decision {
        guard let object = payload.object else {
            return Decision(fact: .unknown, serverCapabilitySatisfied: false, unsatisfiedServerCapabilities: [],
                            serverCapabilitiesDeclared: false)
        }
        let required = requirements(object)
        let capability = satisfy(required, supported: supported)
        guard let configRaw = PWaveEnvelope.text(object["configState"] ?? .null) else {
            return Decision(fact: .unknown, serverCapabilitySatisfied: capability.present,
                            unsatisfiedServerCapabilities: capability.missing, serverCapabilitiesDeclared: capability.declared)
        }
        let config = PWaveConfigState.parse(configRaw)
        switch config {
        case .frozenRun, .published:
            return ready(object, config: config, required: required, capability: capability)
        case .unavailable, .runConfigSnapshotMissing:
            return Decision(fact: .empty, serverCapabilitySatisfied: capability.present,
                            unsatisfiedServerCapabilities: capability.missing, serverCapabilitiesDeclared: capability.declared)
        case .other:
            return Decision(fact: .unknown, serverCapabilitySatisfied: capability.present,
                            unsatisfiedServerCapabilities: capability.missing, serverCapabilitiesDeclared: capability.declared)
        }
    }

    private static func ready(_ object: [String: PlayWireValue], config: PWaveConfigState,
                              required: PWaveRequiredCapabilities, capability: Capability) -> Decision {
        guard let choices = object["choices"] else {
            return Decision(fact: .unknown, serverCapabilitySatisfied: capability.present,
                            unsatisfiedServerCapabilities: capability.missing, serverCapabilitiesDeclared: capability.declared)
        }
        guard case .array(let items) = choices else {
            return Decision(fact: .unknown, serverCapabilitySatisfied: capability.present,
                            unsatisfiedServerCapabilities: capability.missing, serverCapabilitiesDeclared: capability.declared)
        }
        if items.isEmpty {
            return Decision(fact: .empty, serverCapabilitySatisfied: capability.present,
                            unsatisfiedServerCapabilities: capability.missing, serverCapabilitiesDeclared: capability.declared)
        }
        let listed: [String]
        if case .listed(let keys) = required { listed = keys } else { listed = [] }
        let team = PWaveEnvelope.text(object["teamModeSource"] ?? .null)
        let fact = PWavePlayModeFact(
            configState: config,
            runtimeScope: PWaveEnvelope.text(object["runtimeScope"] ?? .null),
            worldMode: PWaveEnvelope.text(object["worldMode"] ?? .null),
            routeMode: PWaveEnvelope.text(object["routeMode"] ?? .null),
            requiredCapabilities: listed,
            teamModeSource: team,
            topicColumnIsFrozen: team == PWaveTokens.topicColumn ? false : nil,
            choiceCount: items.count,
            perMemberHintAndScore: PWaveWalk.contains(PWaveTokens.perMember, in: .object(object)) ? true : nil)
        return Decision(fact: .ready(fact), serverCapabilitySatisfied: capability.present,
                        unsatisfiedServerCapabilities: capability.missing, serverCapabilitiesDeclared: capability.declared)
    }

    static func requirements(_ object: [String: PlayWireValue]) -> PWaveRequiredCapabilities {
        guard object.keys.contains("requiredCapabilities") else { return .undeclared }
        guard let value = object["requiredCapabilities"] else { return .undeclared }
        if case .null = value { return .undeclared }
        guard case .array(let items) = value else { return .malformed }
        var keys: [String] = []
        for item in items {
            guard case .string(let key) = item, !key.isEmpty else { return .malformed }
            keys.append(key)
        }
        return .listed(keys)
    }

    private struct Capability: Equatable {
        let present: Bool
        let missing: [String]
        let declared: Bool?
    }

    private static func satisfy(_ required: PWaveRequiredCapabilities, supported: Set<String>) -> Capability {
        switch required {
        case .undeclared:
            return Capability(present: false, missing: [], declared: false)
        case .malformed:
            return Capability(present: false, missing: [], declared: false)
        case .listed(let keys):
            let missing = keys.filter { !supported.contains($0) }
            let present = !keys.isEmpty && missing.isEmpty
            return Capability(present: present, missing: missing, declared: true)
        }
    }
}
