import Foundation

/// Display rules of mini-program `pages/coop/invite-detail` and `utils/coop-invite-view.js` over one
/// `api/coop/list` row. Pure: decides what is shown and which (dormant) actions are offered, never performs them.
public struct CooperationInvitePresentation: Equatable {
    public enum Terms: Equatable { case share(rate: Double?), fixed(fee: Double?), traffic, unknown }
    public enum Deposit: Equatable { case notRequired, owed(amount: Double?) }
    public enum Contact: Equatable { case visible(String), afterAcceptReceived, afterAcceptSent, acceptedWithoutContact, ended }
    public enum Input: Equatable { case hidden, reply, withdraw }
    public enum Footer: Equatable { case legacy, decide, withdraw, deposit, ongoing(frozen: Bool), inactive }
    public enum ProjectScope: String, Equatable { case merchant = "MERCHANT", club = "CLUB" }

    public let invite: CooperationInvite
    public let direction: CooperationDirection

    public init(invite: CooperationInvite, direction: CooperationDirection) { self.invite = invite; self.direction = direction }

    /// `PARTY_LABEL` keys for "from → to" when either side type is present; nil falls back to `inviteTypeKey`.
    public var partyKeys: (from: String, to: String)? {
        guard invite.fromType?.isEmpty == false || invite.toType?.isEmpty == false else { return nil }
        return (Self.partyKey(invite.fromType, fallback: "from"), Self.partyKey(invite.toType, fallback: "to"))
    }
    public var inviteTypeKey: String {
        guard let type = invite.inviteType, (0...2).contains(type) else { return "cooperation.party.generic" }
        return "cooperation.inviteType." + String(type)
    }
    static func partyKey(_ type: String?, fallback: String) -> String {
        guard let type, ["merchant", "club", "talent", "official"].contains(type) else { return "cooperation.party." + fallback }
        return "cooperation.party." + type
    }
    public var terms: Terms {
        switch invite.shareMode { case 0?: return .traffic; case 1?: return .share(rate: invite.shareRate); case 2?: return .fixed(fee: invite.fixedFee); default: return .unknown }
    }
    /// The source defaults a missing deposit amount to 50; natively a missing amount stays unconfirmed.
    public var deposit: Deposit { !invite.legacyReadonly && invite.depositOwed ? .owed(amount: invite.depositAmount) : .notRequired }
    public var contactText: String? {
        let parts = [invite.partner?.leaderName, invite.partner?.phone].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    public var contact: Contact {
        if let contactText { return .visible(contactText) }
        switch invite.status {
        case 0?: return direction == .received ? .afterAcceptReceived : .afterAcceptSent
        case 1?: return .acceptedWithoutContact
        default: return .ended
        }
    }
    public var input: Input {
        guard invite.status == 0, !invite.legacyReadonly else { return .hidden }
        return direction == .received ? .reply : .withdraw
    }
    public var footer: Footer {
        if invite.legacyReadonly { return .legacy }
        switch invite.status {
        case 0?: return direction == .received ? .decide : .withdraw
        case 1?: return deposit != .notRequired ? .deposit : .ongoing(frozen: invite.termsFrozen)
        default: return .inactive
        }
    }
    var acceptedActionsVisible: Bool { invite.status == 1 && !invite.legacyReadonly }
    /// Source `acceptedProjectScope(inv, box)`.
    public var projectScope: ProjectScope? {
        guard acceptedActionsVisible, (invite.topicId ?? 0) > 0 else { return nil }
        let party = direction == .sent ? invite.fromType : invite.toType
        if party == "club" { return .club }
        if let party, !party.isEmpty, party != "merchant" { return nil }
        let type = invite.inviteType
        return (type == 0 && direction == .received) || (type == 1 && direction == .sent) ? .merchant : nil
    }
    public var showsContactPartner: Bool { acceptedActionsVisible }
    public var showsPerkDeclaration: Bool { acceptedActionsVisible && direction == .received && invite.toType == "merchant" }
    public var showsReview: Bool { acceptedActionsVisible && (direction == .received || invite.toType == "merchant") }
    /// The reviewed party: the inviter for a received invite, the invitee for a sent one.
    public var revieweeID: Int? {
        let id = direction == .received ? invite.fromId : invite.toId
        return (id ?? 0) > 0 && (invite.topicId ?? 0) > 0 ? id : nil
    }
    public var cancelLocked: Bool { invite.termsFrozen }
    /// Source `decisionReady`: partner name, topic and terms must all be known before a decision is offered.
    public var decisionReady: Bool {
        invite.partner?.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && (invite.topicName != nil || invite.topicId != nil) && terms != .unknown
    }
    /// Who wrote `handleReason`: a sent invite's cancel (3) and a received invite's reject (2) are ours.
    public var handleReasonIsOurs: Bool { direction == .sent ? invite.status == 3 : invite.status == 2 }
    public var messageIsOurs: Bool { direction == .sent }

    /// Picks this viewer's own star rating from `api/coop/review/summary` for the same topic; 1…5 only.
    public static func myRating(summary: CoopFlowJSON, me: Int, topicID: Int?) -> Int? {
        guard let topicID, let reviews = summary["reviews"].rows else { return nil }
        let mine = reviews.first { $0["fromId"].integer == me && $0["topicId"].integer == topicID }
        guard let rating = mine?["rating"].integer, (1...5).contains(rating) else { return nil }
        return rating
    }
}

/// Source `linkRepliedApplies` (CU-M-38): a received club application answered with an invite (status 3) links to
/// the sent invite carrying its `originApplyId`, and reads "对方已接受" once that invite is accepted.
public struct CooperationRepliedApplication: Equatable {
    public let statusKey: String
    public let linkedInviteID: Int?
    public init?(application: CooperationApplication, sent: [CooperationInvite]) {
        guard application.status == 3 else { return nil }
        let linked = sent.first { $0.originApplyId == application.applyId }
        linkedInviteID = linked?.id
        statusKey = linked?.status == 1 ? "cooperation.list.apply.partnerAccepted" : "cooperation.list.apply.replied"
    }
}

/// Read phase for `pages/coop/invite-detail` over the existing `api/coop/list` detail.
/// This type does not register a route and does not open an invite composer.
public struct CooperationInviteDetailPage: Equatable {
    public enum Phase: Equatable { case loading, empty, error, unknown, ready }
    /// Visible slot text. `withheld` means the ready row has no slot object, which is not a zero.
    public enum SlotCount: Equatable {
        case withheld
        case text(String)
    }
    /// Existing list read. Not a new invite route.
    public static let readPath = "api/coop/list"
    /// This lane does not change `ChinaReviewedRouteCapability`.
    public static let routeMarkedLive = false
    public static let opensNewInviteSurface = false
    public static let unknownDisplay = CooperationInviteCountFact.unknownDisplay
    public enum Copy {
        public static let loading = "cooperation.loading"
        public static let empty = "cooperation.unavailable"
        public static let unknown = "cooperation.ambiguous"
        public static let malformed = "cooperation.malformed"
    }
    public let phase: Phase
    /// Existing catalog key for the phase. Ready has none.
    public let copyKey: String?
    public let detail: CooperationInviteDetail?
    public let slotCount: SlotCount
    public let slotCapacity: SlotCount

    /// `result == nil` is still loading. Cancellation stays loading.
    /// Not found is empty. A bad id, a duplicate id, and a malformed payload are unknown.
    /// Other failures are errors. None of those phases stores a count of 0.
    public static func project(key: CooperationInviteKey, result: Result<CooperationInviteDetail, Error>?) -> Self {
        guard key.id > 0 else { return unsettled(.unknown, copyKey: Copy.unknown) }
        guard let result else { return unsettled(.loading, copyKey: Copy.loading) }
        switch result {
        case .failure(let error):
            if error is CancellationError { return unsettled(.loading, copyKey: Copy.loading) }
            let issue = CooperationIssue(error)
            switch issue {
            case .unavailable:
                return unsettled(.empty, copyKey: Copy.empty)
            case .malformed:
                return unsettled(.unknown, copyKey: Copy.malformed)
            case .ambiguousIdentity:
                return unsettled(.unknown, copyKey: Copy.unknown)
            case .login, .unconfigured, .failure, .forbidden, .server:
                return unsettled(.error, copyKey: issue.key)
            }
        case .success(let detail):
            guard detail.row.id == key.id else { return unsettled(.unknown, copyKey: Copy.unknown) }
            let count: SlotCount
            let capacity: SlotCount
            if let line = detail.slotLine {
                count = .text(line.count.displayText)
                capacity = .text(line.capacity.displayText)
            } else {
                count = .withheld
                capacity = .withheld
            }
            return Self(phase: .ready, copyKey: nil, detail: detail, slotCount: count, slotCapacity: capacity)
        }
    }

    /// Reads the existing detail. An id that cannot be confirmed does not call the reader.
    @MainActor public static func load(reader: any CooperationReading, key: CooperationInviteKey) async -> Self {
        guard key.id > 0 else { return unsettled(.unknown, copyKey: Copy.unknown) }
        do {
            let detail = try await reader.detail(key: key)
            return project(key: key, result: .success(detail))
        } catch is CancellationError {
            return project(key: key, result: nil)
        } catch {
            return project(key: key, result: .failure(error))
        }
    }

    private static func unsettled(_ phase: Phase, copyKey: String) -> Self {
        Self(phase: phase, copyKey: copyKey, detail: nil, slotCount: .text(unknownDisplay), slotCapacity: .text(unknownDisplay))
    }
}
