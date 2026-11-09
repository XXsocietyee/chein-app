import Foundation

/// Player-loop presentation for zip-v35 chapter 24 (P7, P1, P4, P5).
/// Execution of that wave is NOT_RUN. These types bind later UI; they do not draw it.
/// A feature stays hidden unless a server fact and a capability are both present.
/// UNKNOWN, null, and a missing number stay `.unknown` and are never stored as 0.

public enum PWaveFeature: String, Equatable, Sendable, CaseIterable {
    case battleReport = "P7"
    case inviteLanding = "P1"
    case playMode = "P4"
    case ticketSeats = "P5"
    case affiliateCenter = "P2"
    case themeCollection = "P3"
    case cityPass = "P6"
    case runMemory = "P8"
    case memberBoard = "P9"

    /// First batch from §24.1. P2, P3, P6, P8, and P9 keep the later order.
    public static let displayOrder: [PWaveFeature] = [.battleReport, .inviteLanding, .playMode, .ticketSeats]
    public static let laterDisplayOrder: [PWaveFeature] = [.affiliateCenter, .themeCollection, .cityPass, .runMemory, .memberBoard]
}

public enum PWaveRefusal: Error, Equatable, Sendable {
    case productionEndpoint
    case invalidRequest
    case writesNotAvailable
}

public enum PWaveNumberFact: Equatable, Sendable {
    case unknown
    case value(Int)

    /// A server literal, including 0 when the server sent 0. Unknown is nil.
    public var literal: Int? {
        if case .value(let number) = self { return number }
        return nil
    }

    /// Shown text. Unknown, null, a numeric string, and an unnamed object are an em dash, never 0.
    public static let unknownDisplay = "—"
    public var displayText: String {
        switch self {
        case .unknown: return Self.unknownDisplay
        case .value(let number): return String(number)
        }
    }

    public static func parse(_ value: PlayWireValue) -> PWaveNumberFact {
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

public enum PWaveIdentifierFact: Equatable, Sendable {
    case unknown
    case text(String)
    case integer(Int)

    public var literalInteger: Int? {
        if case .integer(let number) = self { return number }
        return nil
    }

    public static func parse(_ value: PlayWireValue) -> PWaveIdentifierFact {
        switch value {
        case .string(let raw):
            if raw.isEmpty || raw == "UNKNOWN" { return .unknown }
            if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .unknown }
            return .text(raw)
        case .integer(let raw):
            guard let number = Int(exactly: raw) else { return .unknown }
            return .integer(number)
        case .number(let raw):
            guard raw.isFinite, abs(raw) <= 9_007_199_254_740_991 else { return .unknown }
            let number = Int(raw)
            guard Double(number) == raw else { return .unknown }
            return .integer(number)
        case .bool, .array, .object, .null:
            return .unknown
        }
    }
}

public struct PWaveErrorFact: Equatable, Sendable {
    public let httpStatus: Int?
    public let businessCode: Int?
    public let message: String?
    public let runErrorToken: String?
    /// RUN_NOT_FOUND and RUN_SCOPE_MISMATCH never open a different run.
    public var didSubstituteAnotherRun: Bool { false }

    public init(httpStatus: Int?, businessCode: Int?, message: String?, runErrorToken: String?) {
        self.httpStatus = httpStatus
        self.businessCode = businessCode
        self.message = message
        self.runErrorToken = runErrorToken
    }
}

public struct PWavePresentation<Ready: Equatable & Sendable>: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case loading
        case empty
        case error(PWaveErrorFact)
        case unknown
        case ready(Ready)
    }

    public let clientCapabilityPresent: Bool
    public let serverFactPresent: Bool
    public let phase: Phase?
    public let unsatisfiedServerCapabilities: [String]
    /// Nil when the contract has no server capability list. False when P4 omitted or nulled the list.
    public let serverCapabilitiesDeclared: Bool?
    public var hidden: Bool { !(clientCapabilityPresent && serverFactPresent) }

    public init(clientCapabilityPresent: Bool, serverFactPresent: Bool, phase: Phase?,
                unsatisfiedServerCapabilities: [String] = [], serverCapabilitiesDeclared: Bool? = nil) {
        self.clientCapabilityPresent = clientCapabilityPresent
        self.serverFactPresent = serverFactPresent
        self.unsatisfiedServerCapabilities = unsatisfiedServerCapabilities
        self.serverCapabilitiesDeclared = serverCapabilitiesDeclared
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

public enum PWaveServerFact<Ready: Equatable & Sendable>: Equatable, Sendable {
    case empty
    case error(PWaveErrorFact)
    case unknown
    case ready(Ready)
}

public struct PWaveCapability: Equatable, Sendable {
    public let granted: Set<PWaveFeature>
    /// Exact server `requiredCapabilities` strings this build can satisfy. Empty satisfies nothing.
    public let supportedServerCapabilities: Set<String>

    public init(granted: Set<PWaveFeature> = [], supportedServerCapabilities: Set<String> = []) {
        self.granted = granted
        self.supportedServerCapabilities = supportedServerCapabilities
    }

    public static let none = PWaveCapability()
    public func allows(_ feature: PWaveFeature) -> Bool { granted.contains(feature) }
}

public struct PWaveSessionScope: Equatable, Sendable {
    public let accountID: Int
    public let epoch: UInt64
    public let namespace: String

    /// Account 0 is rejected. It is not a stand-in for an unknown account.
    public init(accountID: Int, epoch: UInt64, namespace: String) throws {
        guard accountID > 0, !namespace.isEmpty, namespace.utf8.count <= 128,
              namespace.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else {
            throw PWaveRefusal.invalidRequest
        }
        self.accountID = accountID
        self.epoch = epoch
        self.namespace = namespace
    }
}

enum PWaveTokens {
    static let runErrors: Set<String> = ["RUN_NOT_FOUND", "RUN_SCOPE_MISMATCH"]
    static let perMember = "PER_MEMBER"
    static let topicColumn = "CURRENT_TOPIC_COLUMN"
}

enum PWaveWalk {
    static func firstString(in tokens: Set<String>, value: PlayWireValue, depth: Int = 0) -> String? {
        if depth > 64 { return nil }
        switch value {
        case .string(let text):
            return tokens.contains(text) ? text : nil
        case .array(let items):
            for item in items {
                if let found = firstString(in: tokens, value: item, depth: depth + 1) { return found }
            }
            return nil
        case .object(let fields):
            for key in fields.keys.sorted() {
                if let found = firstString(in: tokens, value: fields[key] ?? .null, depth: depth + 1) { return found }
            }
            return nil
        case .integer, .number, .bool, .null:
            return nil
        }
    }

    static func contains(_ token: String, in value: PlayWireValue, depth: Int = 0) -> Bool {
        firstString(in: [token], value: value, depth: depth) != nil
    }
}

enum PWaveEnvelope {
    enum Classified: Equatable {
        case error(PWaveErrorFact)
        case unknown
        case payload(PlayWireValue)
    }

    static func classify(data: Data, status: Int) -> Classified {
        guard (200..<300).contains(status) else {
            let root = try? JSONDecoder().decode(PlayWireValue.self, from: data)
            return .error(error(httpStatus: status, root: root))
        }
        guard let root = try? JSONDecoder().decode(PlayWireValue.self, from: data), root.object != nil else {
            return .error(PWaveErrorFact(httpStatus: status, businessCode: nil, message: nil, runErrorToken: nil))
        }
        if let token = PWaveWalk.firstString(in: PWaveTokens.runErrors, value: root) {
            return .error(PWaveErrorFact(httpStatus: status, businessCode: businessCode(root["code"]),
                                          message: text(root["msg"]), runErrorToken: token))
        }
        guard let code = businessCode(root["code"]) else {
            return .error(PWaveErrorFact(httpStatus: status, businessCode: nil, message: text(root["msg"]), runErrorToken: nil))
        }
        guard code == 200 else {
            return .error(PWaveErrorFact(httpStatus: status, businessCode: code, message: text(root["msg"]), runErrorToken: nil))
        }
        let payload = root.object?["data"] ?? .null
        if case .null = payload { return .unknown }
        return .payload(payload)
    }

    private static func error(httpStatus: Int, root: PlayWireValue?) -> PWaveErrorFact {
        guard let root else {
            return PWaveErrorFact(httpStatus: httpStatus, businessCode: nil, message: nil, runErrorToken: nil)
        }
        return PWaveErrorFact(httpStatus: httpStatus, businessCode: businessCode(root["code"]),
                               message: text(root["msg"]),
                               runErrorToken: PWaveWalk.firstString(in: PWaveTokens.runErrors, value: root))
    }

    /// AjaxResult `code` only. Score and rank do not use this coercion.
    private static func businessCode(_ value: PlayWireValue) -> Int? {
        if let number = value.integer { return number }
        return value.tolerantInteger
    }

    static func text(_ value: PlayWireValue) -> String? {
        guard case .string(let raw) = value, !raw.isEmpty else { return nil }
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        return raw
    }
}

enum PWaveGate {
    static func presentation<Ready>(clientCapabilityPresent: Bool, fact: PWaveServerFact<Ready>,
                                    unsatisfiedServerCapabilities: [String] = [],
                                    serverCapabilitiesDeclared: Bool? = nil) -> PWavePresentation<Ready> {
        let phase: PWavePresentation<Ready>.Phase
        switch fact {
        case .empty: phase = .empty
        case .error(let error): phase = .error(error)
        case .unknown: phase = .unknown
        case .ready(let value): phase = .ready(value)
        }
        return PWavePresentation(clientCapabilityPresent: clientCapabilityPresent, serverFactPresent: true,
                                 phase: phase, unsatisfiedServerCapabilities: unsatisfiedServerCapabilities,
                                 serverCapabilitiesDeclared: serverCapabilitiesDeclared)
    }
}

/// §23.3: a missing or null `requiredCapabilities` is not "no capability required".
/// P2, P3, P6, P8, and P9 stay hidden until that list is present and this build supports every entry.
/// An empty list is declared and still unsatisfied, so it is not an empty success.
enum PWaveServerCapability {
    struct Outcome: Equatable, Sendable {
        let satisfied: Bool
        let declared: Bool?
        let missing: [String]
    }

    static func presentation<Ready>(data: Data, status: Int, supported: Set<String>,
                                    project: (PlayWireValue, PlayWireValue) -> PWaveServerFact<Ready>) -> PWavePresentation<Ready> {
        let root = (try? JSONDecoder().decode(PlayWireValue.self, from: data)) ?? .null
        switch PWaveEnvelope.classify(data: data, status: status) {
        case .error(let error):
            return PWaveGate.presentation(clientCapabilityPresent: true, fact: .error(error))
        case .unknown:
            let outcome = evaluate(root: root, supported: supported)
            if outcome.satisfied {
                return PWaveGate.presentation(clientCapabilityPresent: true, fact: .unknown,
                                             serverCapabilitiesDeclared: outcome.declared)
            }
            return PWavePresentation(clientCapabilityPresent: false, serverFactPresent: true, phase: .unknown,
                                    unsatisfiedServerCapabilities: outcome.missing,
                                    serverCapabilitiesDeclared: outcome.declared)
        case .payload(let payload):
            let outcome = evaluate(root: root, supported: supported)
            let fact = project(root, payload)
            if outcome.satisfied {
                return PWaveGate.presentation(clientCapabilityPresent: true, fact: fact,
                                             unsatisfiedServerCapabilities: outcome.missing,
                                             serverCapabilitiesDeclared: outcome.declared)
            }
            return conceal(fact, outcome: outcome)
        }
    }

    static func conceal<Ready>(_ fact: PWaveServerFact<Ready>, outcome: Outcome) -> PWavePresentation<Ready> {
        let phase: PWavePresentation<Ready>.Phase
        switch fact {
        case .empty: phase = .empty
        case .error(let error): phase = .error(error)
        case .unknown: phase = .unknown
        case .ready(let value): phase = .ready(value)
        }
        return PWavePresentation(clientCapabilityPresent: false, serverFactPresent: true, phase: phase,
                                unsatisfiedServerCapabilities: outcome.missing,
                                serverCapabilitiesDeclared: outcome.declared)
    }

    static func evaluate(root: PlayWireValue, supported: Set<String>) -> Outcome {
        guard let rootObject = root.object else {
            return Outcome(satisfied: false, declared: false, missing: [])
        }
        var lists: [PlayWireValue] = []
        if rootObject.keys.contains("requiredCapabilities") {
            lists.append(rootObject["requiredCapabilities"] ?? .null)
        }
        if let dataObject = rootObject["data"]?.object, dataObject.keys.contains("requiredCapabilities") {
            lists.append(dataObject["requiredCapabilities"] ?? .null)
        }
        if lists.isEmpty { return Outcome(satisfied: false, declared: false, missing: []) }
        var missing: [String] = []
        var declared = true
        var satisfied = true
        for value in lists {
            switch parsed(value) {
            case .absent, .malformed:
                declared = false
                satisfied = false
            case .listed(let keys):
                let gap = keys.filter { !supported.contains($0) }
                missing.append(contentsOf: gap)
                if keys.isEmpty || !gap.isEmpty { satisfied = false }
            }
        }
        return Outcome(satisfied: satisfied, declared: declared, missing: missing)
    }

    private enum Parsed: Equatable {
        case absent
        case malformed
        case listed([String])
    }

    private static func parsed(_ value: PlayWireValue) -> Parsed {
        if case .null = value { return .absent }
        guard case .array(let items) = value else { return .malformed }
        var keys: [String] = []
        for item in items {
            guard case .string(let key) = item, !key.isEmpty else { return .malformed }
            keys.append(key)
        }
        return .listed(keys)
    }
}

enum PWaveProductionBoundary {
    /// Hosts named by this repo as live or legacy production targets. This wave does not call them.
    static func isProductionHost(_ host: String) -> Bool {
        let host = host.lowercased()
        if host == "47.103.124.64" { return true }
        if host == "chengyinhub.com" || host.hasSuffix(".chengyinhub.com") { return true }
        if host == "chengyinhub.cn" || host.hasSuffix(".chengyinhub.cn") { return true }
        return false
    }
}
