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

    /// Chapter 24 display order. Later P items are outside this Core slice.
    public static let displayOrder: [PWaveFeature] = [.battleReport, .inviteLanding, .playMode, .ticketSeats]
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
