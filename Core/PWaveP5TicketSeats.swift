import Foundation

/// P5 seat reads. Counts named only in prose (N, pending, claimed, free) have no JSON keys here,
/// so this type does not compute `free` and does not apply a caller-side lifetime.
/// Writes stay unavailable: the migration has not run, and release protection was sent back.
/// `originalPaid` and `CLAIMED` do not satisfy play admission.

public struct PWaveSeatRowFact: Equatable, Sendable {
    public let expiresAt: String?
    public let expiresAtIsUnknown: Bool
    public let originalPaid: Bool?

    public init(expiresAt: String?, originalPaid: Bool?) {
        self.expiresAt = expiresAt
        self.expiresAtIsUnknown = expiresAt == "UNKNOWN"
        self.originalPaid = originalPaid
    }

    init?(_ value: PlayWireValue) {
        guard let object = value.object else { return nil }
        let expiresAt = PWaveEnvelope.text(object["expiresAt"] ?? .null)
        let originalPaid = object["originalPaid"]?.bool
        if expiresAt == nil && originalPaid == nil { return nil }
        self.init(expiresAt: expiresAt, originalPaid: originalPaid)
    }
}

public struct PWaveSeatListFact: Equatable, Sendable {
    public let rows: [PWaveSeatRowFact]
    public var playAdmissionSatisfied: Bool { false }
    public var writesAvailable: Bool { false }
    public var releaseAvailable: Bool { false }
    public var appliesDefaultTTL: Bool { false }

    public init(rows: [PWaveSeatRowFact]) {
        self.rows = rows
    }
}

public enum PWaveSeatRead {
    public static func decode(data: Data, status: Int) -> PWaveServerFact<PWaveSeatListFact> {
        switch PWaveEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return fact(payload)
        }
    }

    static func fact(_ payload: PlayWireValue) -> PWaveServerFact<PWaveSeatListFact> {
        if case .array(let items) = payload {
            if items.isEmpty { return .empty }
            let rows = items.compactMap { PWaveSeatRowFact($0) }
            return rows.isEmpty ? .unknown : .ready(PWaveSeatListFact(rows: rows))
        }
        guard let row = PWaveSeatRowFact(payload) else { return .unknown }
        return .ready(PWaveSeatListFact(rows: [row]))
    }
}

/// Retains a write the server named. Nothing here transmits it.
public struct PWaveSeatWriteDraft: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case invite
        case claim
        case cancel
        case release
    }

    public let kind: Kind
    public let requestID: String
    public let registrationID: String?
    public let seatNo: String?
    public let invitationID: String?
    public var available: Bool { false }

    private let credential: String?

    public init(invite registrationID: String, seatNo: String? = nil, requestID: String) throws {
        try Self.validate(requestID)
        guard Self.acceptable(registrationID) else { throw PWaveRefusal.invalidRequest }
        if let seatNo { guard Self.acceptable(seatNo) else { throw PWaveRefusal.invalidRequest } }
        self.kind = .invite
        self.requestID = requestID
        self.registrationID = registrationID
        self.seatNo = seatNo
        self.invitationID = nil
        self.credential = nil
    }

    public init(claim credential: String, requestID: String) throws {
        try Self.validate(requestID)
        guard Self.acceptable(credential) else { throw PWaveRefusal.invalidRequest }
        self.kind = .claim
        self.requestID = requestID
        self.registrationID = nil
        self.seatNo = nil
        self.invitationID = nil
        self.credential = credential
    }

    public init(cancel invitationID: String, requestID: String) throws {
        try Self.validate(requestID)
        guard Self.acceptable(invitationID), !invitationID.contains("/") else { throw PWaveRefusal.invalidRequest }
        self.kind = .cancel
        self.requestID = requestID
        self.registrationID = nil
        self.seatNo = nil
        self.invitationID = invitationID
        self.credential = nil
    }

    public init(release invitationID: String, requestID: String) throws {
        try Self.validate(requestID)
        guard Self.acceptable(invitationID), !invitationID.contains("/") else { throw PWaveRefusal.invalidRequest }
        self.kind = .release
        self.requestID = requestID
        self.registrationID = nil
        self.seatNo = nil
        self.invitationID = invitationID
        self.credential = nil
    }

    /// Same caller, same request id, and same fields compare equal. This value is not sent.
    public func matchesReplay(of other: PWaveSeatWriteDraft) -> Bool { self == other }

    private static func validate(_ requestID: String) throws {
        guard acceptable(requestID) else { throw PWaveRefusal.invalidRequest }
    }

    private static func acceptable(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 256 && value.unicodeScalars.allSatisfy { $0.value >= 32 && $0.value != 127 }
    }
}
