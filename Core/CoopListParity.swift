import Foundation

/// Source `utils/merchant-official-channel.js` row shaping for `GET api/official/merchant-invites` on `pages/coop/list`.
public struct CoopOfficialInvite: Equatable, Identifiable {
    public enum Reward: Equatable { case share(rate: String), fixed(fee: String), resources, unconfirmed }
    public enum Stage: String, Equatable { case declined, expired, awaitingYou, won, notWon, awaitingReview, unknown }
    public enum Deadline: Equatable { case unconfirmed, monthDay(month: Int, day: Int), verbatim(String) }
    public let id: Int
    public let title: String
    public let coverURL: String?
    public let topicID: Int?
    public let status: Int?
    public let reward: Reward
    public let stage: Stage
    public let deadline: Deadline
    public var actionable: Bool { status == 0 }

    /// Rows lacking a positive invite ID or a non-blank title are dropped, as the source filters them.
    public static func rows(_ value: CoopFlowJSON) -> [CoopOfficialInvite] { (value.rows ?? []).compactMap(CoopOfficialInvite.init) }

    public init?(_ row: CoopFlowJSON) {
        guard let id = row["inviteId"].integer, id > 0,
              let title = row["title"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
        self.id = id; self.title = title
        coverURL = row["cover"].text.flatMap { $0.isEmpty ? nil : $0 }
        topicID = row["topicId"].integer
        status = row["status"].integer
        switch row["shareMode"].integer {
        case 1?: reward = row["shareRate"].text.map { .share(rate: $0) } ?? .unconfirmed
        case 2?: reward = row["fixedFee"].text.map { .fixed(fee: $0) } ?? .unconfirmed
        case 0?: reward = .resources
        default: reward = .unconfirmed
        }
        switch (status, row["auditStatus"].integer) {
        case (2?, _): stage = .declined
        case (5?, _): stage = .expired
        case (0?, _): stage = .awaitingYou
        case (1?, 1?): stage = .won
        case (1?, 2?): stage = .notWon
        case (1?, _): stage = .awaitingReview
        default: stage = .unknown
        }
        deadline = Self.deadline(row["expireTime"].text)
    }
    static func deadline(_ text: String?) -> Deadline {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return .unconfirmed }
        let parts = text.prefix(10).split(separator: "-")
        if parts.count == 3, parts[0].count == 4, let month = Int(parts[1]), let day = Int(parts[2]), (1...12).contains(month), (1...31).contains(day) {
            return .monthDay(month: month, day: day)
        }
        return .verbatim(text)
    }
}

/// Source `pages/coop/list` chapter-application legs (`owner-mine` for topic owners, `mine` for merchants).
public struct CoopChapterApplication: Equatable, Identifiable {
    public enum Leg: String, Equatable { case owner, mine }
    public enum Status: String, Equatable { case offerWithdrawn, pendingReview, rejected, offerActive, offerPendingReview, approvedAwaitingSupply }
    public enum Action: String, Equatable { case viewWithdrawal, viewOwned, viewAndSupply }
    public let leg: Leg
    public let applicationID: Int
    public let topicID: Int?
    public let topicName: String?
    public let chapterName: String?
    public let merchantName: String?
    public let status: Status
    /// `source == 1` marks an owner-initiated invitation rather than a merchant application.
    public let invited: Bool
    public var id: String { leg.rawValue + ":" + String(applicationID) }
    public var direction: CooperationDirection { (leg == .owner) != invited ? .received : .sent }
    public var action: Action { status == .offerWithdrawn ? .viewWithdrawal : leg == .owner ? .viewOwned : .viewAndSupply }

    /// The whole leg is rejected when the payload is not a list of objects (source `isRecordList`).
    public static func rows(_ value: CoopFlowJSON, leg: Leg) throws -> [CoopChapterApplication] {
        guard let rows = value.rows else { throw CoopFlowFailure.malformed }
        return try rows.map { row in
            guard case .object = row, let id = row["id"].integer, id > 0 else { throw CoopFlowFailure.malformed }
            return CoopChapterApplication(leg: leg, row: row, id: id)
        }
    }
    init(leg: Leg, row: CoopFlowJSON, id: Int) {
        self.leg = leg; applicationID = id
        topicID = row["topicId"].integer
        topicName = row["topicName"].text.flatMap { $0.isEmpty ? nil : $0 }
        chapterName = row["chapterName"].text.flatMap { $0.isEmpty ? nil : $0 }
        merchantName = row["merchantName"].text.flatMap { $0.isEmpty ? nil : $0 }
        invited = row["source"].integer == 1
        let offerState = row["offerState"].text
        if offerState == "WITHDRAWN" { status = .offerWithdrawn }
        else if row["status"].integer == 0 { status = .pendingReview }
        else if row["status"].integer == 2 { status = .rejected }
        else if row["offerActive"].flag == true { status = .offerActive }
        else if (row["replacementOfOfferId"].integer ?? 0) > 0, (row["offerId"].integer ?? 0) > 0, offerState == "INACTIVE" { status = .offerPendingReview }
        else { status = .approvedAwaitingSupply }
    }
}

public enum CoopListReadFailure {
    /// Source `failureKind`: sign-in / permission style failures. Used to treat the merchant-only `mine`
    /// leg as not applicable for non-merchant accounts instead of surfacing an error.
    public static func isPermission(_ error: Error) -> Bool {
        if error as? APIError == .unauthorized { return true }
        switch error as? CoopFlowFailure {
        case .permission?, .inactiveMerchant?: return true
        case .server(let code, let message)?:
            if code == 401 || code == 403 { return true }
            guard let message else { return false }
            return message.range(of: "请先登录|无权|仅.+可|资格|身份|主理人", options: .regularExpression) != nil
        default: return false
        }
    }
}

/// Deep-link `topicId` / `topicName` filter seed for `pages/coop/list` with clear-filter support.
public struct CoopTopicFilterSeed: Equatable, Sendable {
    public private(set) var topicID: Int?
    public private(set) var topicName: String?

    public init(topicID: Int? = nil, topicName: String? = nil) {
        if let id = topicID, id > 0 {
            self.topicID = id
            let trimmed = topicName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.topicName = trimmed.isEmpty ? nil : trimmed
        } else {
            self.topicID = nil
            self.topicName = nil
        }
    }

    public init(rawTopicID: String?, rawTopicName: String? = nil) {
        let parsedID = rawTopicID.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        self.init(topicID: parsedID, topicName: rawTopicName)
    }

    public var isActive: Bool { topicID != nil }

    public var displayLabel: String? {
        guard let topicID else { return nil }
        if let topicName { return "\(topicName) (#\(topicID))" }
        return "#\(topicID)"
    }

    public mutating func clear() {
        topicID = nil
        topicName = nil
    }

    public func cleared() -> CoopTopicFilterSeed { .init() }

    public func matches(topicID candidate: Int?) -> Bool {
        guard let active = topicID else { return true }
        return candidate == active
    }

    public func filter<Row>(_ rows: [Row], topic: (Row) -> Int?) -> [Row] {
        guard isActive else { return rows }
        return rows.filter { matches(topicID: topic($0)) }
    }
}

/// pages/coop/list/index projection of the existing inbox. It does not fetch, add a route,
/// or mark a route live. A missing read capability stays hidden. Share is not offered.
public enum CoopListPagePhase: Equatable {
    case loading
    case empty
    case error
    case unknown
    case ready
}

/// One slot that already exists on an invite row. A missing or negative number is an em dash.
/// A literal zero stays "0". No slot object means the fact is absent, not zero.
public struct CoopListSlotFact: Equatable {
    public let inviteID: Int
    public let ordinal: Int
    public let kind: CooperationOccupancy.Kind
    public let countText: String
    public let capacityText: String
}

public struct CoopListPage: Equatable {
    /// Missing numeric facts. Never a stand-in zero.
    public static let unknownMark = "—"
    public let phase: CoopListPagePhase
    /// True when the existing read capability is absent. The page is not bindable then.
    public let isHidden: Bool
    public let direction: CooperationDirection
    public let invitationCountText: String
    public let applicationCountText: String
    /// Nil hides the registration section. Sent invites do not read it. An unknown received count is an em dash.
    public let registrationCountText: String?
    public let isPartial: Bool
    public let slotFacts: [CoopListSlotFact]
    /// Existing new-invite control. False unless that flow reader is already present.
    public let showsNewInvite: Bool
    /// Existing official-invite section. Received tab only, and only with the existing flow reader.
    public let showsOfficialInvites: Bool
    /// Existing chapter-application section. Only with the existing flow reader.
    public let showsChapterApplications: Bool
    public let showsShare = false
    public let showsMerchantChoice = false
    public let paymentEnabled = false
    public let payoutEnabled = false
    public let withdrawalEnabled = false
    public let virtualGoodsEnabled = false

    public init(phase: CoopListPagePhase, isHidden: Bool, direction: CooperationDirection,
                invitationCountText: String, applicationCountText: String, registrationCountText: String?,
                isPartial: Bool, slotFacts: [CoopListSlotFact], showsNewInvite: Bool,
                showsOfficialInvites: Bool, showsChapterApplications: Bool) {
        self.phase = phase
        self.isHidden = isHidden
        self.direction = direction
        self.invitationCountText = invitationCountText
        self.applicationCountText = applicationCountText
        self.registrationCountText = registrationCountText
        self.isPartial = isPartial
        self.slotFacts = slotFacts
        self.showsNewInvite = showsNewInvite
        self.showsOfficialInvites = showsOfficialInvites
        self.showsChapterApplications = showsChapterApplications
    }
}

public enum CoopListPageCoordinator {
    /// `inbox == nil` is still loading. Cancellation stays loading. A malformed payload is
    /// unknown, not an empty list. Any other whole-read failure is an error. Counts stay an
    /// em dash until a real list arrives. A known empty list is "0".
    public static func project(direction: CooperationDirection, canRead: Bool,
                               inbox: Result<CooperationInbox, Error>?,
                               canComposeInvite: Bool = false,
                               canReadFlowLegs: Bool = false) -> CoopListPage {
        let showsNewInvite = canRead && canComposeInvite
        let showsOfficialInvites = canRead && canReadFlowLegs && direction == .received
        let showsChapterApplications = canRead && canReadFlowLegs
        guard canRead else {
            return page(phase: .loading, isHidden: true, direction: direction,
                        invitation: CoopListPage.unknownMark, application: CoopListPage.unknownMark,
                        registration: nil, partial: false, slots: [],
                        showsNewInvite: false, showsOfficialInvites: false, showsChapterApplications: false)
        }
        guard let inbox else {
            return unsettled(.loading, direction: direction, showsNewInvite: showsNewInvite,
                             showsOfficialInvites: showsOfficialInvites, showsChapterApplications: showsChapterApplications)
        }
        switch inbox {
        case .failure(let error):
            if error is CancellationError {
                return unsettled(.loading, direction: direction, showsNewInvite: showsNewInvite,
                                 showsOfficialInvites: showsOfficialInvites, showsChapterApplications: showsChapterApplications)
            }
            let phase: CoopListPagePhase = unclassified(error) ? .unknown : .error
            return unsettled(phase, direction: direction, showsNewInvite: showsNewInvite,
                             showsOfficialInvites: showsOfficialInvites, showsChapterApplications: showsChapterApplications)
        case .success(let value):
            guard value.direction == direction else {
                return unsettled(.unknown, direction: direction, showsNewInvite: showsNewInvite,
                                 showsOfficialInvites: showsOfficialInvites, showsChapterApplications: showsChapterApplications)
            }
            return project(value, showsNewInvite: showsNewInvite, showsOfficialInvites: showsOfficialInvites,
                           showsChapterApplications: showsChapterApplications)
        }
    }

    private static func project(_ inbox: CooperationInbox, showsNewInvite: Bool, showsOfficialInvites: Bool,
                                showsChapterApplications: Bool) -> CoopListPage {
        let direction = inbox.direction
        let invitation = countText(inbox.invitations) { $0.rows(direction).count }
        let application = countText(inbox.applications) { $0.count }
        let registration: String?
        if direction == .received {
            if let section = inbox.registrations { registration = countText(section) { $0.rows.count } }
            else { registration = CoopListPage.unknownMark }
        } else {
            registration = nil
        }
        let slots: [CoopListSlotFact]
        if case .content(let invites) = inbox.invitations { slots = slotFacts(direction: direction, invites: invites) }
        else { slots = [] }
        let phase = phase(inbox, invitation: invitation, application: application, registration: registration)
        return page(phase: phase, isHidden: false, direction: direction, invitation: invitation, application: application,
                    registration: registration, partial: inbox.isPartial, slots: slots, showsNewInvite: showsNewInvite,
                    showsOfficialInvites: showsOfficialInvites, showsChapterApplications: showsChapterApplications)
    }

    private static func phase(_ inbox: CooperationInbox, invitation: String, application: String, registration: String?) -> CoopListPagePhase {
        let rows = successfulRows(inbox.invitations) { $0.rows(inbox.direction).count }
            + successfulRows(inbox.applications) { $0.count }
            + (inbox.registrations.map { successfulRows($0) { $0.rows.count } } ?? 0)
        if unclassified(inbox.invitations) { return .unknown }
        let siblingUnclassified = unclassified(inbox.applications) || (inbox.registrations.map { unclassified($0) } ?? false)
        if siblingUnclassified && rows == 0 { return .unknown }
        let anyFailure = failed(inbox.invitations) || failed(inbox.applications) || (inbox.registrations.map { failed($0) } ?? false)
        if anyFailure && rows == 0 { return .error }
        let registrationEmpty = registration == nil || registration == "0"
        if !inbox.isPartial && invitation == "0" && application == "0" && registrationEmpty { return .empty }
        return .ready
    }

    /// Game slots never fall through to a topic slot. That selection stays the existing occupancy rule.
    private static func slotFacts(direction: CooperationDirection, invites: CooperationInvites) -> [CoopListSlotFact] {
        invites.rows(direction).enumerated().compactMap { index, invite in
            if let game = invite.gameId {
                guard let slot = invites.slots?.byGame?[String(game)] else { return nil }
                return CoopListSlotFact(inviteID: invite.id, ordinal: index, kind: .gamePending,
                                         countText: display(slot.pending), capacityText: display(slot.cap))
            }
            if let topic = invite.topicId, let slot = invites.slots?.byTopic?[String(topic)] {
                return CoopListSlotFact(inviteID: invite.id, ordinal: index, kind: .topicAccepted,
                                         countText: display(slot.accepted), capacityText: display(slot.cap))
            }
            return nil
        }
    }

    private static func display(_ value: Int?) -> String {
        guard let value, value >= 0 else { return CoopListPage.unknownMark }
        return String(value)
    }

    private static func countText<T>(_ section: CooperationSection<T>, rows: (T) -> Int) -> String {
        switch section {
        case .failure:
            return CoopListPage.unknownMark
        case .content(let value):
            let count = rows(value)
            guard count >= 0 else { return CoopListPage.unknownMark }
            return String(count)
        }
    }

    private static func successfulRows<T>(_ section: CooperationSection<T>, rows: (T) -> Int) -> Int {
        if case .content(let value) = section, rows(value) > 0 { return rows(value) }
        return 0
    }

    private static func failed<T>(_ section: CooperationSection<T>) -> Bool {
        if case .failure = section { return true }
        return false
    }

    private static func unclassified<T>(_ section: CooperationSection<T>) -> Bool {
        if case .failure(.malformed) = section { return true }
        return false
    }

    private static func unclassified(_ error: Error) -> Bool {
        if case APIError.malformedResponse = error { return true }
        if error is DecodingError { return true }
        return false
    }

    private static func unsettled(_ phase: CoopListPagePhase, direction: CooperationDirection, showsNewInvite: Bool,
                                  showsOfficialInvites: Bool, showsChapterApplications: Bool) -> CoopListPage {
        page(phase: phase, isHidden: false, direction: direction, invitation: CoopListPage.unknownMark,
             application: CoopListPage.unknownMark,
             registration: direction == .received ? CoopListPage.unknownMark : nil,
             partial: false, slots: [], showsNewInvite: showsNewInvite, showsOfficialInvites: showsOfficialInvites,
             showsChapterApplications: showsChapterApplications)
    }

    private static func page(phase: CoopListPagePhase, isHidden: Bool, direction: CooperationDirection,
                             invitation: String, application: String, registration: String?, partial: Bool,
                             slots: [CoopListSlotFact], showsNewInvite: Bool, showsOfficialInvites: Bool,
                             showsChapterApplications: Bool) -> CoopListPage {
        CoopListPage(phase: phase, isHidden: isHidden, direction: direction, invitationCountText: invitation,
                     applicationCountText: application, registrationCountText: registration, isPartial: partial,
                     slotFacts: slots, showsNewInvite: showsNewInvite, showsOfficialInvites: showsOfficialInvites,
                     showsChapterApplications: showsChapterApplications)
    }
}
