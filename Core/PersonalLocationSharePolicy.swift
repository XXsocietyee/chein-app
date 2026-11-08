import Foundation

/// No runtime business defaults. The server supplies an approved, versioned choice set.
public struct PersonalLocationSharePolicy: Codable, Equatable, Sendable {
    public struct ModeChoice: Codable, Equatable, Identifiable, Sendable {
        public let id: String
        public let mode: PersonalLocationShareMode
        public let datum: String
        public let latitudeStep: Double?
        public let longitudeStep: Double?
    }
    public struct DurationChoice: Codable, Equatable, Identifiable, Sendable {
        public let id: String
        public let seconds: Int64
    }
    public let policyId: String
    public let version: Int64
    public let digest: String
    public let approvalRef: String
    public let foregroundOnly: Bool
    public let requiresRecipientAcceptance: Bool
    public let modeChoices: [ModeChoice]
    public let durationChoices: [DurationChoice]
    public let refreshAfterMs: Int64
    public let staleAfterMs: Int64
    public let displayLeaseMs: Int64
    public let ownerLeaseMs: Int64
    public func validate() throws {
        guard !policyId.isEmpty, version > 0, digest.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil, !approvalRef.isEmpty, foregroundOnly,
              !modeChoices.isEmpty, !durationChoices.isEmpty,
              refreshAfterMs > 0, UInt64(refreshAfterMs) <= UInt64.max / 1_000_000,
              staleAfterMs >= refreshAfterMs, displayLeaseMs >= refreshAfterMs, ownerLeaseMs >= refreshAfterMs,
              Set(modeChoices.map(\.id)).count == modeChoices.count,
              Set(durationChoices.map(\.id)).count == durationChoices.count else { throw PersonalLocationShareFailure.invalidContract }
        guard !requiresRecipientAcceptance else { throw PersonalLocationShareFailure.acceptanceUnavailable }
        for mode in modeChoices {
            guard !mode.id.isEmpty, mode.datum == "WGS84" else { throw PersonalLocationShareFailure.invalidContract }
            if mode.mode == .coarse {
                guard let lat = mode.latitudeStep, let lon = mode.longitudeStep,
                      lat.isFinite, lon.isFinite, lat > 0, lat <= 180, lon > 0, lon <= 360 else { throw PersonalLocationShareFailure.invalidContract }
            } else if mode.latitudeStep != nil || mode.longitudeStep != nil { throw PersonalLocationShareFailure.invalidContract }
        }
        guard durationChoices.allSatisfy({ !$0.id.isEmpty && $0.seconds > 0 && $0.seconds <= Int64.max / 1000 }) else { throw PersonalLocationShareFailure.invalidContract }
    }
}

/// Separate endpoint approval, pinned to an origin and a review record. Defaults remain nil at every host.
public struct PersonalLocationShareEndpointApproval: Equatable, Sendable {
    public let origin: URL
    public let approvalReference: String
    public let operations: Set<PersonalLocationShareOperation>
    public init(origin: URL, approvalReference: String, operations: Set<PersonalLocationShareOperation>) throws {
        guard origin.scheme == "https", origin.host != nil, origin.user == nil, origin.password == nil,
              origin.query == nil, origin.fragment == nil, !approvalReference.isEmpty else { throw PersonalLocationShareFailure.invalidContract }
        self.origin = origin; self.approvalReference = approvalReference; self.operations = operations
    }
    public func permits(_ operation: PersonalLocationShareOperation, baseURL: URL) -> Bool {
        origin.standardized == baseURL.standardized && operations.contains(operation)
    }
}
public enum PersonalLocationShareOperation: String, Hashable, Sendable {
    case context, requestStatus, owned, received, events, create, revoke, publish
    public var isRead: Bool { [.context, .requestStatus, .owned, .received, .events].contains(self) }
}

/// Independent, reviewed personal-sharing collection purpose. Other app uses never imply this consent.
/// Approval pins the exact OS disclosure in the installed bundle as well as the account/session scope.
public struct PersonalLocationShareCaptureApproval: Equatable, Sendable {
    public let scope: PersonalLocationShareScope
    public let approvalReference: String
    public let usageDescription: String
    public let purpose: String
    public init(scope: PersonalLocationShareScope, approvalReference: String, usageDescription: String) throws {
        guard !approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !usageDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !usageDescription.lowercased().contains("not shared with other people") else {
            throw PersonalLocationShareFailure.invalidContract
        }
        self.scope = scope; self.approvalReference = approvalReference; self.usageDescription = usageDescription
        purpose = "PERSONAL_LOCATION_SHARING_FOREGROUND"
    }
    public func permits(scope: PersonalLocationShareScope, installedUsageDescription: String?) -> Bool {
        self.scope == scope && installedUsageDescription == usageDescription && purpose == "PERSONAL_LOCATION_SHARING_FOREGROUND"
    }
}

/// Owner-chosen place the owner never wants shown precisely (home, school). Held on device only.
public struct PersonalLocationShareSensitivePlace: Equatable, Sendable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let radiusMeters: Double
    public init(id: String, latitude: Double, longitude: Double, radiusMeters: Double) throws {
        guard !id.isEmpty, PersonalLocationShareDistanceBanding.isValid(latitude, longitude),
              radiusMeters.isFinite, radiusMeters > 0 else { throw PersonalLocationShareFailure.invalidContract }
        self.id = id; self.latitude = latitude; self.longitude = longitude; self.radiusMeters = radiusMeters
    }
}
public struct PersonalLocationShareSensitivePlacePolicy: Equatable, Sendable {
    public let places: [PersonalLocationShareSensitivePlace]
    public init(places: [PersonalLocationShareSensitivePlace]) { self.places = places }
    public func hides(latitude: Double, longitude: Double) -> Bool {
        places.contains { place in
            // Distance is only compared with the radius here; it is never returned.
            guard let meters = PersonalLocationShareDistanceBanding.meters(latitude, longitude, place.latitude, place.longitude) else { return false }
            return meters <= place.radiusMeters
        }
    }
}
/// Decides what a viewer may see of a fix they are already entitled to receive.
/// Strangers are coarse-only; a hidden sensitive place collapses to coarse for everyone; a coarse fix is never upgraded.
public struct PersonalLocationShareFixRenderer: Equatable, Sendable {
    public let latitudeStep: Double
    public let longitudeStep: Double
    public let sensitivePlaces: PersonalLocationShareSensitivePlacePolicy
    public init(latitudeStep: Double, longitudeStep: Double, sensitivePlaces: PersonalLocationShareSensitivePlacePolicy) throws {
        guard latitudeStep.isFinite, longitudeStep.isFinite, latitudeStep > 0, latitudeStep <= 180,
              longitudeStep > 0, longitudeStep <= 360 else { throw PersonalLocationShareFailure.invalidContract }
        self.latitudeStep = latitudeStep; self.longitudeStep = longitudeStep; self.sensitivePlaces = sensitivePlaces
    }
    public func render(latitude: Double, longitude: Double, mode: PersonalLocationShareMode,
                       layer: PersonalLocationShareViewerLayer) -> PersonalLocationShareRenderedFix {
        guard PersonalLocationShareDistanceBanding.isValid(latitude, longitude) else { return .withheld }
        if layer == .friend, mode == .exact, !sensitivePlaces.hides(latitude: latitude, longitude: longitude) {
            return .exact(latitude: latitude, longitude: longitude)
        }
        return .coarse(latitude: Self.cellCenter(latitude, origin: -90, span: 180, step: latitudeStep),
                       longitude: Self.cellCenter(longitude, origin: -180, span: 360, step: longitudeStep))
    }
    private static func cellCenter(_ value: Double, origin: Double, span: Double, step: Double) -> Double {
        let cells = (span / step).rounded(.up)
        let index = min(max((value - origin) / step, 0).rounded(.down), cells - 1)
        return min(origin + span, origin + (index + 0.5) * step)
    }
}

/// DEC-06: game location collection and voluntary personal sharing are two independent switches.
/// Neither implies, starts or stops the other.
public struct PersonalLocationShareCollectionSwitches: Equatable, Sendable {
    public private(set) var gameCollectionActive = false
    public private(set) var shareActive = false
    public init() {}
    public mutating func setGameCollection(active: Bool) { gameCollectionActive = active }
    public mutating func shareStarted() { shareActive = true }
    public mutating func shareStopped() { shareActive = false }
}
