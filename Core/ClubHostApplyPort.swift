import Foundation

/// club/apply parity helpers: the mini-program wizard counts selected capabilities ("已选 N 项")
/// and only accepts non-negative whole numbers for the two optional event-size fields.
public enum ClubHostApplyPort {
    public static let capabilityKeys = ["canDesignRoute", "canDesignTask", "canNpc", "canMerchantCoop"]
    public static let sizeKeys = ["maxEventSize", "avgEventSize"]

    public static func capabilityCount(_ flags: [String: Bool]) -> Int {
        capabilityKeys.filter { flags[$0] == true }.count
    }

    /// Empty is allowed (sent as null). Otherwise a base-10 integer >= 0, matching parseInt on a number input.
    public static func isValidSize(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return true }
        guard let number = Int(value) else { return false }
        return number >= 0
    }

    /// Keys of size fields that must be fixed before the application can be reviewed.
    public static func invalidSizeKeys(_ text: [String: String]) -> [String] {
        sizeKeys.filter { !isValidSize(text[$0] ?? "") }
    }

    public static func requiredFieldsFilled(_ text: [String: String]) -> Bool {
        let name = (text["leaderName"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = (text["phone"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !phone.isEmpty
    }

    /// Mini-program step gating: 1 needs name+phone, 2 needs an experience choice, 3 is optional, 4 is optional.
    public static func canAdvance(step: Int, text: [String: String]) -> Bool {
        switch step {
        case 1: return requiredFieldsFilled(text)
        case 2: return !(text["experience"] ?? "").isEmpty && invalidSizeKeys(text).isEmpty
        default: return true
        }
    }

    public static func canReview(text: [String: String]) -> Bool {
        requiredFieldsFilled(text) && invalidSizeKeys(text).isEmpty
    }
}

/// pages/club/apply/index. Projects the host-status read the governance coordinator already
/// performs (`api/publisher/identity/status`) before `hostApply` (`api/club/become-leader`).
/// A missing capability stays hidden. This does not add a route or mark one live.
public enum ClubHostApplyCount: Equatable, Sendable {
    case unknown
    case value(Int)

    /// UNKNOWN, null, a numeric string, and any non-integer stay an em dash. A server integer 0 stays 0.
    public static let unknownDisplay = "—"
    public var literal: Int? {
        if case .value(let number) = self { return number }
        return nil
    }
    public var displayText: String {
        switch self {
        case .unknown: return Self.unknownDisplay
        case .value(let number): return String(number)
        }
    }

    /// Integer JSON only. `ClubGovernanceValue.int` also accepts numeric strings; this parser does not.
    public static func parse(_ value: ClubGovernanceValue) -> ClubHostApplyCount {
        if case .integer(let number) = value { return .value(number) }
        return .unknown
    }

    /// Empty and rejected draft text are unknown, never 0. A typed non-negative integer, including 0, is kept.
    public static func parseDraftSize(_ raw: String) -> ClubHostApplyCount {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || !ClubHostApplyPort.isValidSize(value) { return .unknown }
        guard let number = Int(value) else { return .unknown }
        return .value(number)
    }
}

public struct ClubHostApplyPageModel: Equatable {
    public static let page = "pages/club/apply/index"
    public static let statusPath = ClubGovernanceRead.hostStatus.path
    public static let submitPath = ClubGovernanceMutation.hostApply.path
    public static let read = ClubGovernanceRead.hostStatus
    public static let mutation = ClubGovernanceMutation.hostApply
    /// Club-owner application. Not listed on the player-first launch entry.
    public static let showsOnPlayerFirstEntry = false
    /// This page does not turn the merchant role choice back on.
    public static let showsMerchantChoice = false

    public enum Phase: Equatable {
        case hidden
        case loading
        case empty
        case error
        case unknown
        case intro
        case merchantBlocked
        case host
    }

    public let phase: Phase
    public let messageKey: String
    public let allowance: ClubHostApplyCount
    public let selectedCount: ClubHostApplyCount
    public let maxEventSize: ClubHostApplyCount
    public let avgEventSize: ClubHostApplyCount

    public var accessibilityIdentifier: String {
        switch phase {
        case .hidden: return "club.host.apply.hidden"
        case .loading: return "club.host.apply.loading"
        case .empty: return "club.host.apply.empty"
        case .error: return "club.host.apply.error"
        case .unknown: return "club.host.apply.unknown"
        case .intro: return "club.host.apply.intro"
        case .merchantBlocked: return "club.host.apply.merchantBlocked"
        case .host: return "club.host.apply.host"
        }
    }
    public static let allowanceIdentifier = "club.host.apply.allowance"
    public static let selectedCountIdentifier = "club.host.apply.selectedCount"

    public static func isVisible(capabilityGranted: Bool, playerFirstEntry: Bool) -> Bool {
        capabilityGranted && !playerFirstEntry
    }

    /// Nil base cannot call the route, so the page stays hidden. China production is offered only
    /// when both existing paths already admit a call. No new route is registered.
    public static func capabilityGranted(baseURL: URL?) -> Bool {
        ChinaReviewedRouteCapability.offersFeature("/" + statusPath, baseURL: baseURL)
            && ChinaReviewedRouteCapability.offersFeature("/" + submitPath, baseURL: baseURL)
    }

    public init(loading: Bool, failure: ClubGovernanceFailure? = nil, snapshot: ClubGovernanceSnapshot? = nil,
                capabilityGranted: Bool, playerFirstEntry: Bool = false, draftFlags: [String: Bool]? = nil,
                draftSizes: [String: String] = [:], allowance: ClubGovernanceValue = .null) {
        let visible = Self.isVisible(capabilityGranted: capabilityGranted, playerFirstEntry: playerFirstEntry)
        let phase: Phase
        let messageKey: String
        if !visible {
            phase = .hidden
            messageKey = "club.gov.unavailable"
        } else if loading {
            phase = .loading
            messageKey = "club.host.apply.loading"
        } else if let failure {
            switch failure {
            case .unknown:
                phase = .unknown
                messageKey = failure.localizationKey
            default:
                phase = .error
                messageKey = failure.localizationKey
            }
        } else if snapshot == nil {
            phase = .empty
            messageKey = "club.gov.empty"
        } else if snapshot?.operation != Self.read {
            phase = .unknown
            messageKey = "club.gov.unknownValue"
        } else if case .bool(let registered) = snapshot?["registered"] ?? .null {
            if !registered {
                phase = .empty
                messageKey = "club.gov.empty"
            } else if case .string(let role) = snapshot?["accountRole"] ?? .null {
                switch role {
                case "player":
                    phase = .intro
                    messageKey = "club.host.intro.title"
                case "merchant":
                    phase = .merchantBlocked
                    messageKey = "club.host.merchant.title"
                case "club":
                    phase = .host
                    messageKey = "club.host.done.title"
                default:
                    phase = .unknown
                    messageKey = "club.gov.unknownValue"
                }
            } else {
                phase = .unknown
                messageKey = "club.gov.unknownValue"
            }
        } else {
            phase = .unknown
            messageKey = "club.gov.unknownValue"
        }
        self.phase = phase
        self.messageKey = messageKey
        let content = phase == .intro || phase == .merchantBlocked || phase == .host
        self.allowance = content ? ClubHostApplyCount.parse(allowance) : .unknown
        if phase == .intro, let draftFlags {
            selectedCount = .value(ClubHostApplyPort.capabilityCount(draftFlags))
        } else {
            selectedCount = .unknown
        }
        if phase == .intro {
            maxEventSize = ClubHostApplyCount.parseDraftSize(draftSizes["maxEventSize"] ?? "")
            avgEventSize = ClubHostApplyCount.parseDraftSize(draftSizes["avgEventSize"] ?? "")
        } else {
            maxEventSize = .unknown
            avgEventSize = .unknown
        }
    }
}

extension ClubGovernanceSnapshot {
    fileprivate subscript(_ key: String) -> ClubGovernanceValue { value[key] }
}

#if DEBUG
/// Synthetic host-status rows for the club-owner application. Not registered in production.
public enum ClubHostApplyFixtureData {
    public static let accountID = 701
    public static func status(registered: ClubGovernanceValue = .bool(true), role: ClubGovernanceValue = .string("player")) -> ClubGovernanceValue {
        .object(["registered": registered, "accountRole": role, "accountID": .integer(accountID)])
    }
    public static func snapshot(_ value: ClubGovernanceValue, operation: ClubGovernanceRead = .hostStatus) -> ClubGovernanceSnapshot {
        ClubGovernanceSnapshot(operation: operation, scope: ClubGovernanceScope(), permissions: nil, value: value)
    }
    public static var player: ClubGovernanceSnapshot { snapshot(status()) }
    public static var merchant: ClubGovernanceSnapshot { snapshot(status(role: .string("merchant"))) }
    public static var host: ClubGovernanceSnapshot { snapshot(status(role: .string("club"))) }
    public static var unregistered: ClubGovernanceSnapshot { snapshot(status(registered: .bool(false))) }
    public static var unknownRole: ClubGovernanceSnapshot { snapshot(status(role: .string("UNKNOWN"))) }
    public static var missingRegistered: ClubGovernanceSnapshot { snapshot(status(registered: .null)) }
    public static var otherRead: ClubGovernanceSnapshot { snapshot(status(), operation: .feed) }
}
#endif
