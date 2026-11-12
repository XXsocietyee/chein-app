import Foundation

/// G7 client rules that have no backend yet.
/// Pure values from docs/owner-plan/gap-pl-3.md. No connection is opened and no money write is enabled.
/// Rows: CT04.d, CT04.e, CT05.c, CT07.e, CT09.b, CT09.c, CT14.b.
public enum G7ClientRuleBoundary {
    public static let performsNetwork = false
    public static let enablesMoney = false
}

// MARK: - CT04.d

/// Declining personal location share must not remove ordinary play or roam.
public enum ShareConsentChoice: String, Equatable, Sendable, CaseIterable {
    case unset
    case declined
    case granted
}

public enum OrdinaryActivity: String, Equatable, Sendable, CaseIterable {
    case play
    case roam
}

public struct ParticipationDecision: Equatable, Sendable {
    public let activity: OrdinaryActivity
    public let shareConsent: ShareConsentChoice
    public let allowed: Bool

    public init(activity: OrdinaryActivity, shareConsent: ShareConsentChoice, allowed: Bool) {
        self.activity = activity
        self.shareConsent = shareConsent
        self.allowed = allowed
    }
}

public enum ShareDeclineParticipation {
    public static func decide(_ activity: OrdinaryActivity, shareConsent: ShareConsentChoice) -> ParticipationDecision {
        switch (activity, shareConsent) {
        case (.play, _), (.roam, _):
            return ParticipationDecision(activity: activity, shareConsent: shareConsent, allowed: true)
        }
    }
}

// MARK: - CT04.e

/// A copy of location data. None of these may outlive the source window or gain a use the source lacks.
public enum LocationCopyKind: String, Equatable, Sendable, CaseIterable {
    case permanentRestore
    case derivedStat
    case importedTrack
    case migratedCopy
}

public enum LocationRetentionUse: String, Equatable, Sendable, Hashable {
    case activePlayCapture
    case personalShare
}

public struct LocationCopyClaim: Equatable, Sendable {
    public let kind: LocationCopyKind
    public let sourceEndsAt: Date
    public let proposedEndsAt: Date
    public let sourceUses: Set<LocationRetentionUse>
    public let proposedUses: Set<LocationRetentionUse>

    public init(kind: LocationCopyKind, sourceEndsAt: Date, proposedEndsAt: Date,
                sourceUses: Set<LocationRetentionUse>, proposedUses: Set<LocationRetentionUse>) {
        self.kind = kind
        self.sourceEndsAt = sourceEndsAt
        self.proposedEndsAt = proposedEndsAt
        self.sourceUses = sourceUses
        self.proposedUses = proposedUses
    }
}

public enum LocationCopyVerdict: Equatable, Sendable {
    case kept(endsAt: Date, uses: Set<LocationRetentionUse>)
    case refusedExtension
    case refusedNewUse
}

public enum LocationCopyRetention {
    /// Copies keep the source window and the source uses. A later end or a new use is refused.
    public static func evaluate(_ claim: LocationCopyClaim) -> LocationCopyVerdict {
        if claim.proposedEndsAt > claim.sourceEndsAt { return .refusedExtension }
        if !claim.proposedUses.isSubset(of: claim.sourceUses) { return .refusedNewUse }
        return .kept(endsAt: claim.sourceEndsAt, uses: claim.sourceUses)
    }
}

// MARK: - CT05.c

public struct PointOfInterestID: Hashable, Sendable {
    public let raw: String
    public init(raw: String) { self.raw = raw }
}

public struct GameNodeID: Hashable, Sendable {
    public let raw: String
    public init(raw: String) { self.raw = raw }
}

public struct StorePlaceID: Hashable, Sendable {
    public let raw: String
    public init(raw: String) { self.raw = raw }
}

public struct MapProviderPlaceID: Hashable, Sendable {
    public let raw: String
    public init(raw: String) { self.raw = raw }
}

public enum GeographicPlaceKind: String, Equatable, Sendable, CaseIterable {
    case pointOfInterest
    case gameNode
    case store
    case mapProvider
}

public struct GeographicPlaceRef: Hashable, Sendable {
    public let kind: GeographicPlaceKind
    public let raw: String
    public init(kind: GeographicPlaceKind, raw: String) {
        self.kind = kind
        self.raw = raw
    }
}

public enum GeographicPlaceIDs {
    public static func pointOfInterest(_ ref: GeographicPlaceRef) -> PointOfInterestID? {
        guard ref.kind == .pointOfInterest, !ref.raw.isEmpty else { return nil }
        return PointOfInterestID(raw: ref.raw)
    }

    public static func gameNode(_ ref: GeographicPlaceRef) -> GameNodeID? {
        guard ref.kind == .gameNode, !ref.raw.isEmpty else { return nil }
        return GameNodeID(raw: ref.raw)
    }

    public static func store(_ ref: GeographicPlaceRef) -> StorePlaceID? {
        guard ref.kind == .store, !ref.raw.isEmpty else { return nil }
        return StorePlaceID(raw: ref.raw)
    }

    public static func mapProvider(_ ref: GeographicPlaceRef) -> MapProviderPlaceID? {
        guard ref.kind == .mapProvider, !ref.raw.isEmpty else { return nil }
        return MapProviderPlaceID(raw: ref.raw)
    }

    /// Same text in two kinds is not the same place. Empty text is not a place.
    public static func samePlace(_ lhs: GeographicPlaceRef, _ rhs: GeographicPlaceRef) -> Bool {
        lhs.kind == rhs.kind && !lhs.raw.isEmpty && lhs.raw == rhs.raw
    }
}

// MARK: - CT07.e

public struct OriginalTaskCompletion: Equatable, Sendable {
    public let taskInstanceID: String
    public let score: Int
    public let requiredComplete: Bool

    public init(taskInstanceID: String, score: Int, requiredComplete: Bool) {
        self.taskInstanceID = taskInstanceID
        self.score = score
        self.requiredComplete = requiredComplete
    }
}

public enum PhotoReviewState: String, Equatable, Sendable {
    case pending
    case notPending
}

public struct PhotoSubstituteRuling: Equatable, Sendable {
    /// Score awarded by the photo substitute itself. Pending review awards none.
    public let substituteScore: Int
    /// True only when this photo substitute advances a required completion. Pending review never does.
    public let advancesRequiredCompletion: Bool
    /// Completion handed back. Replay and a method switch return the original fact.
    public let completion: OriginalTaskCompletion
    public let callsNetwork: Bool

    public init(substituteScore: Int, advancesRequiredCompletion: Bool,
                completion: OriginalTaskCompletion, callsNetwork: Bool) {
        self.substituteScore = substituteScore
        self.advancesRequiredCompletion = advancesRequiredCompletion
        self.completion = completion
        self.callsNetwork = callsNetwork
    }
}

public enum PhotoSubstituteCompletion {
    /// A local photo proposal cannot mint a full score or advance a required task.
    /// There is no backend receipt here, so replay and a method switch both return the original completion.
    public static func rule(original: OriginalTaskCompletion, review: PhotoReviewState,
                            proposedScore: Int, proposedAdvance: Bool,
                            replayOrSwitchMethod: Bool) -> PhotoSubstituteRuling {
        let awardsProposedScore = false
        let advancesFromProposal = false
        if review == .pending && !replayOrSwitchMethod {
            return PhotoSubstituteRuling(
                substituteScore: awardsProposedScore ? proposedScore : 0,
                advancesRequiredCompletion: advancesFromProposal && proposedAdvance,
                completion: original,
                callsNetwork: false)
        }
        return PhotoSubstituteRuling(
            substituteScore: 0,
            advancesRequiredCompletion: false,
            completion: original,
            callsNetwork: false)
    }
}

// MARK: - CT09.b

/// Entitlement quantity. One whole unit is two half-steps. This is not money.
public enum QuotaQuantity: Equatable, Sendable {
    case whole(Int)
    case halves(Int)
    case unlimited

    public var isUnlimited: Bool {
        if case .unlimited = self { return true }
        return false
    }

    /// Finite non-negative size in half-steps. One whole unit is two halves.
    public var halfStepCount: Int? {
        switch self {
        case .whole(let count):
            guard count >= 0, count <= Int.max / 2 else { return nil }
            return count * 2
        case .halves(let count):
            guard count >= 0 else { return nil }
            return count
        case .unlimited:
            return nil
        }
    }
}

public enum QuotaGate: Equatable, Sendable {
    case admit
    case insufficientBalance
    case overCapacity
    case invalidQuantity
    case moneyDisabled
}

public struct QuotaCheck: Equatable, Sendable {
    public let gate: QuotaGate
    public let remaining: QuotaQuantity
    public let chargedMoney: Bool

    public init(gate: QuotaGate, remaining: QuotaQuantity, chargedMoney: Bool) {
        self.gate = gate
        self.remaining = remaining
        self.chargedMoney = chargedMoney
    }
}

public enum QuotaUnitGate {
    /// Balance and capacity only. `spendsMoney` is refused and does not flip a money switch.
    public static func check(balance: QuotaQuantity, request: QuotaQuantity,
                             capacityHalfSteps: Int?, spendsMoney: Bool) -> QuotaCheck {
        if spendsMoney {
            return QuotaCheck(gate: .moneyDisabled, remaining: balance, chargedMoney: false)
        }
        if request.isUnlimited {
            return QuotaCheck(gate: .invalidQuantity, remaining: balance, chargedMoney: false)
        }
        guard let requestSteps = request.halfStepCount else {
            return QuotaCheck(gate: .invalidQuantity, remaining: balance, chargedMoney: false)
        }
        if let capacityHalfSteps, capacityHalfSteps < 0 {
            return QuotaCheck(gate: .invalidQuantity, remaining: balance, chargedMoney: false)
        }
        if requestSteps == 0 {
            return QuotaCheck(gate: .admit, remaining: balance, chargedMoney: false)
        }
        if let capacityHalfSteps, requestSteps > capacityHalfSteps {
            return QuotaCheck(gate: .overCapacity, remaining: balance, chargedMoney: false)
        }
        if balance.isUnlimited {
            return QuotaCheck(gate: .admit, remaining: .unlimited, chargedMoney: false)
        }
        guard let balanceSteps = balance.halfStepCount else {
            return QuotaCheck(gate: .invalidQuantity, remaining: balance, chargedMoney: false)
        }
        if requestSteps > balanceSteps {
            return QuotaCheck(gate: .insufficientBalance, remaining: balance, chargedMoney: false)
        }
        return QuotaCheck(gate: .admit, remaining: .halves(balanceSteps - requestSteps), chargedMoney: false)
    }
}

// MARK: - CT09.c

public enum TicketUnitState: String, Equatable, Sendable {
    case available
    case reserved
    case fulfilled
    case noShow
}

public struct TicketUnit: Equatable, Sendable, Identifiable {
    public let id: String
    public let state: TicketUnitState

    public init(id: String, state: TicketUnitState) {
        self.id = id
        self.state = state
    }
}

public struct MultiUseTicket: Equatable, Sendable {
    public let ticketID: String
    public let units: [TicketUnit]

    public init(ticketID: String, units: [TicketUnit]) {
        self.ticketID = ticketID
        self.units = units
    }
}

public struct NoShowResult: Equatable, Sendable {
    public let ticket: MultiUseTicket
    public let wholeTicketVoided: Bool
    public let chargesMoney: Bool
    public let refundsMoney: Bool

    public init(ticket: MultiUseTicket, wholeTicketVoided: Bool, chargesMoney: Bool, refundsMoney: Bool) {
        self.ticket = ticket
        self.wholeTicketVoided = wholeTicketVoided
        self.chargesMoney = chargesMoney
        self.refundsMoney = refundsMoney
    }
}

public enum MissedAppointmentTicket {
    /// One missed appointment marks that unit only. Sibling units and the ticket stay as they were.
    public static func recordNoShow(_ ticket: MultiUseTicket, unitID: String) -> NoShowResult {
        var matched = false
        let units = ticket.units.map { unit -> TicketUnit in
            guard !matched, unit.id == unitID else { return unit }
            matched = true
            if unit.state == .fulfilled { return unit }
            return TicketUnit(id: unit.id, state: .noShow)
        }
        return NoShowResult(
            ticket: MultiUseTicket(ticketID: ticket.ticketID, units: units),
            wholeTicketVoided: false,
            chargesMoney: false,
            refundsMoney: false)
    }
}

// MARK: - CT14.b

public struct PublicReferencePost: Equatable, Sendable {
    public let postID: String
    public let referenceExpired: Bool
    public let hasLocation: Bool
    public let isPublic: Bool

    public init(postID: String, referenceExpired: Bool, hasLocation: Bool, isPublic: Bool) {
        self.postID = postID
        self.referenceExpired = referenceExpired
        self.hasLocation = hasLocation
        self.isPublic = isPublic
    }
}

public struct ReferencePublication: Equatable, Sendable {
    public let visible: Bool
    public let isPublic: Bool
    public let hasLocation: Bool

    public init(visible: Bool, isPublic: Bool, hasLocation: Bool) {
        self.visible = visible
        self.isPublic = isPublic
        self.hasLocation = hasLocation
    }

    public var isLocationlessPublicPost: Bool { visible && isPublic && !hasLocation }
}

public enum ExpiredPublicReference {
    /// An expired public reference stays withheld. It is not rewritten into a public post with no location.
    public static func resolve(_ post: PublicReferencePost, downgradeToLocationlessPublic: Bool) -> ReferencePublication {
        if post.referenceExpired || downgradeToLocationlessPublic {
            return ReferencePublication(visible: false, isPublic: false, hasLocation: post.hasLocation)
        }
        return ReferencePublication(visible: post.isPublic, isPublic: post.isPublic, hasLocation: post.hasLocation)
    }
}
