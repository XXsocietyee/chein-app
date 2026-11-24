import Foundation

public enum CooperationDirection: String, CaseIterable, Hashable { case received, sent }
public struct CooperationInviteKey: Hashable {
    public let id: Int
    public let direction: CooperationDirection
    public init(id: Int, direction: CooperationDirection) { self.id = id; self.direction = direction }
}

/// Source: coop_invite_row.dart. Unknown states remain unknown; missing amounts never become zero.
public struct CooperationInvite: Decodable, Equatable {
    public let id: Int
    public let inviteType: Int?
    public let fromId: Int?
    public let fromType: String?
    public let toType: String?
    public let toId: Int?
    public let topicId: Int?
    public let gameId: Int?
    public let status: Int?
    public let message: String?
    public let handleReason: String?
    public let shareMode: Int?
    public let shareRate: Double?
    public let fixedFee: Double?
    public let depositOwed: Bool
    public let depositAmount: Double?
    public let depositRefundPending: Bool
    public let termsFrozen: Bool
    public let expireTime: CooperationSourceTime?
    public let createTime: CooperationSourceTime?
    public let partner: CooperationPartner?
    public let coverURL: String?
    /// Display-only joins the source list adds (`topicName`, `viewerPartyName`, `topicStartDate`); tolerant of absence.
    public let topicName: String?
    public let viewerPartyName: String?
    public let topicStartDate: CooperationSourceTime?
    /// Set when this invite answers a club's open application (`coop_club_apply.id`).
    public let originApplyId: Int?
    /// Frozen supply station on a station-topic invite. Absent when the invite has none.
    public let supplyStationId: Int?
    public let supplyStationName: String?
    public var legacyReadonly: Bool { inviteType == 2 }
    public var statusKey: String {
        guard let status, (0...5).contains(status) else { return "cooperation.status.unknown" }
        return "cooperation.invite.status.\(status)"
    }
    enum CodingKeys: String, CodingKey {
        case id, inviteType, fromId, fromType, toType, toId, topicId, gameId, status, message, handleReason
        case shareMode, shareRate, fixedFee, depositOwed, depositAmount, depositRefundPending, termsFrozen
        case expireTime, createTime, partner, cover, topicCover, topicImgUrl
        case topicName, viewerPartyName, topicStartDate, originApplyId, supplyStationId, supplyStationName
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.positiveID(.id)
        inviteType = try c.decodeIfPresent(Int.self, forKey: .inviteType)
        fromId = try c.decodeIfPresent(Int.self, forKey: .fromId)
        fromType = try c.decodeIfPresent(String.self, forKey: .fromType)
        toType = try c.decodeIfPresent(String.self, forKey: .toType)
        toId = try c.decodeIfPresent(Int.self, forKey: .toId)
        topicId = try c.decodeIfPresent(Int.self, forKey: .topicId)
        gameId = try c.decodeIfPresent(Int.self, forKey: .gameId)
        status = try c.decodeIfPresent(Int.self, forKey: .status)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        handleReason = try c.decodeIfPresent(String.self, forKey: .handleReason)
        shareMode = try c.decodeIfPresent(Int.self, forKey: .shareMode)
        shareRate = try c.decodeIfPresent(Double.self, forKey: .shareRate)
        fixedFee = try c.decodeIfPresent(Double.self, forKey: .fixedFee)
        depositOwed = try c.decodeIfPresent(Bool.self, forKey: .depositOwed) ?? false
        depositAmount = try c.decodeIfPresent(Double.self, forKey: .depositAmount)
        depositRefundPending = try c.decodeIfPresent(Bool.self, forKey: .depositRefundPending) ?? false
        termsFrozen = try c.decodeIfPresent(Bool.self, forKey: .termsFrozen) ?? false
        expireTime = try c.decodeIfPresent(CooperationSourceTime.self, forKey: .expireTime)
        createTime = try c.decodeIfPresent(CooperationSourceTime.self, forKey: .createTime)
        partner = try c.decodeIfPresent(CooperationPartner.self, forKey: .partner)
        coverURL = try [c.decodeIfPresent(String.self, forKey: .cover), c.decodeIfPresent(String.self, forKey: .topicCover), c.decodeIfPresent(String.self, forKey: .topicImgUrl)].compactMap { $0 }.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        topicName = (try? c.decodeIfPresent(String.self, forKey: .topicName)).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        viewerPartyName = (try? c.decodeIfPresent(String.self, forKey: .viewerPartyName)).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        topicStartDate = try? c.decodeIfPresent(CooperationSourceTime.self, forKey: .topicStartDate)
        originApplyId = (try? c.decodeIfPresent(Int.self, forKey: .originApplyId)).flatMap { $0 > 0 ? $0 : nil }
        supplyStationId = Self.optionalStationID(c)
        supplyStationName = Self.optionalStationName(c)
    }
    private static func optionalStationID(_ c: KeyedDecodingContainer<CodingKeys>) -> Int? {
        if let number = try? c.decodeIfPresent(Int.self, forKey: .supplyStationId) { return number > 0 ? number : nil }
        if let text = try? c.decodeIfPresent(String.self, forKey: .supplyStationId), let number = Int(text), number > 0, String(number) == text { return number }
        return nil
    }
    private static func optionalStationName(_ c: KeyedDecodingContainer<CodingKeys>) -> String? {
        guard let text = try? c.decodeIfPresent(String.self, forKey: .supplyStationName) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
public struct CooperationPartner: Decodable, Equatable {
    public let name: String?
    public let leaderName: String?
    public let phone: String?
}
/// Keep source wall-time text verbatim. No timezone/countdown is invented for unzoned strings.
public enum CooperationSourceTime: Decodable, Equatable {
    case text(String), milliseconds(Double)
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let value = try? c.decode(String.self) { self = .text(value) }
        else { self = .milliseconds(try c.decode(Double.self)) }
    }
    public var date: Date? {
        if case .milliseconds(let value) = self { return Date(timeIntervalSince1970: value / 1_000) }
        return nil
    }
}
/// A slot count from one `api/coop/list` slots object. A JSON integer, including 0, stays that integer.
/// Null, a missing value, a numeric string, a bool, a fraction, a negative, and `UNKNOWN` are unknown.
/// Unknown is never stored as 0.
public struct CooperationInviteCountFact: Decodable, Equatable, Sendable {
    public enum Value: Equatable, Sendable {
        case known(Int)
        case unknown
    }
    /// U+2014. Not a hyphen, and not a stand-in zero.
    public static let unknownDisplay = "—"
    public static let unknown = CooperationInviteCountFact(value: .unknown)
    public let value: Value
    public init(value: Value) { self.value = value }
    /// The server integer, including 0. Unknown is nil.
    public var literal: Int? {
        if case .known(let number) = value { return number }
        return nil
    }
    public var displayText: String {
        if case .known(let number) = value { return String(number) }
        return Self.unknownDisplay
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.init(value: .unknown)
            return
        }
        if let number = try? container.decode(Int.self), number >= 0 {
            self.init(value: .known(number))
            return
        }
        if let number = try? container.decode(Double.self), number >= 0, let exact = Int(exactly: number) {
            self.init(value: .known(exact))
            return
        }
        self.init(value: .unknown)
    }
}
public struct CooperationSlot: Decodable, Equatable {
    public let pending: Int?
    public let accepted: Int?
    public let cap: Int?
    public let pendingFact: CooperationInviteCountFact
    public let acceptedFact: CooperationInviteCountFact
    public let capFact: CooperationInviteCountFact
    private enum CodingKeys: String, CodingKey { case pending, accepted, cap }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pendingFact = try Self.fact(container, .pending)
        acceptedFact = try Self.fact(container, .accepted)
        capFact = try Self.fact(container, .cap)
        pending = pendingFact.literal
        accepted = acceptedFact.literal
        cap = capFact.literal
    }
    private static func fact(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> CooperationInviteCountFact {
        try container.decodeIfPresent(CooperationInviteCountFact.self, forKey: key) ?? .unknown
    }
}
/// One existing slot object. A missing object stays nil. A present field that is not a non-negative integer is an em dash.
public struct CooperationInviteSlotLine: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case gamePending, topicAccepted }
    public let kind: Kind
    public let count: CooperationInviteCountFact
    public let capacity: CooperationInviteCountFact
    public init(kind: Kind, count: CooperationInviteCountFact, capacity: CooperationInviteCountFact) {
        self.kind = kind
        self.count = count
        self.capacity = capacity
    }
}
public struct CooperationSlots: Decodable, Equatable {
    public let byGame: [String: CooperationSlot]?
    public let byTopic: [String: CooperationSlot]?
}
public struct CooperationOccupancy: Equatable {
    public enum Kind: Equatable { case gamePending, topicAccepted }
    public let kind: Kind
    public let count: Int
    public let capacity: Int
}
public struct CooperationInvites: Decodable, Equatable {
    public let sent: [CooperationInvite]
    public let received: [CooperationInvite]
    public let slots: CooperationSlots?
    enum CodingKeys: String, CodingKey { case sent, received, slots }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sent = try c.decodeIfPresent([CooperationInvite].self, forKey: .sent) ?? []
        received = try c.decodeIfPresent([CooperationInvite].self, forKey: .received) ?? []
        slots = try c.decodeIfPresent(CooperationSlots.self, forKey: .slots)
    }
    public func rows(_ direction: CooperationDirection) -> [CooperationInvite] { direction == .sent ? sent : received }
    public func occupancy(for invite: CooperationInvite) -> CooperationOccupancy? {
        if let game = invite.gameId, let slot = slots?.byGame?[String(game)] {
            guard let count = slot.pending, let cap = slot.cap, count >= 0, cap >= 0 else { return nil }
            return CooperationOccupancy(kind: .gamePending, count: count, capacity: cap)
        }
        if let topic = invite.topicId, let slot = slots?.byTopic?[String(topic)],
           let count = slot.accepted, let cap = slot.cap, count >= 0, cap >= 0 {
            return CooperationOccupancy(kind: .topicAccepted, count: count, capacity: cap)
        }
        return nil
    }
    /// Same box as `occupancy(for:)`. A game id never falls through to the topic slot.
    /// The slot object is kept when a count is unknown, so the caller can show an em dash instead of 0.
    public func slotLine(for invite: CooperationInvite) -> CooperationInviteSlotLine? {
        if let game = invite.gameId {
            guard let slot = slots?.byGame?[String(game)] else { return nil }
            return CooperationInviteSlotLine(kind: .gamePending, count: slot.pendingFact, capacity: slot.capFact)
        }
        if let topic = invite.topicId {
            guard let slot = slots?.byTopic?[String(topic)] else { return nil }
            return CooperationInviteSlotLine(kind: .topicAccepted, count: slot.acceptedFact, capacity: slot.capFact)
        }
        return nil
    }
}
public struct CooperationInviteDetail: Equatable {
    public let row: CooperationInvite
    public let occupancy: CooperationOccupancy?
    public let slotLine: CooperationInviteSlotLine?
    public init(row: CooperationInvite, occupancy: CooperationOccupancy?, slotLine: CooperationInviteSlotLine? = nil) {
        self.row = row
        self.occupancy = occupancy
        self.slotLine = slotLine
    }
}

/// Application history is distinct from the open pool and must never be reconstructed from it.
public struct CooperationApplication: Decodable, Equatable {
    public let applyId: Int
    public let topicId: Int
    public let status: Int?
    public let topicName: String?
    public let clubId: Int?
    public let clubName: String?
    public let merchantNick: String?
    public let message: String?
    public let startDate: CooperationSourceTime?
    public let scope: String?
    public var statusKey: String {
        guard let status, (0...3).contains(status) else { return "cooperation.status.unknown" }
        return "cooperation.application.status.\(status)"
    }
    enum CodingKeys: String, CodingKey { case applyId, topicId, status, topicName, clubId, clubName, merchantNick, message, startDate, scope }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        applyId = try c.positiveID(.applyId); topicId = try c.positiveID(.topicId)
        status = try c.decodeIfPresent(Int.self, forKey: .status)
        topicName = try c.decodeIfPresent(String.self, forKey: .topicName)
        clubId = try c.decodeIfPresent(Int.self, forKey: .clubId)
        clubName = try c.decodeIfPresent(String.self, forKey: .clubName)
        merchantNick = try c.decodeIfPresent(String.self, forKey: .merchantNick)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        startDate = try c.decodeIfPresent(CooperationSourceTime.self, forKey: .startDate)
        scope = try c.decodeIfPresent(String.self, forKey: .scope)
    }
}
public struct CooperationRegistration: Decodable, Equatable {
    public let id: Int
    public let topicId: Int?
    public let topicName: String?
    public let memberId: Int?
    public let merchantName: String?
    public let merchantMeta: String?
    public let addressName: String?
    public let address: String?
    public let auditStatus: Int?
    public var statusKey: String {
        guard let auditStatus, (0...2).contains(auditStatus) else { return "cooperation.status.unknown" }
        return "cooperation.registration.status.\(auditStatus)"
    }
    enum CodingKeys: String, CodingKey { case id, topicId, topicName, memberId, merchantName, merchantMeta, addressName, address, auditStatus }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.positiveID(.id)
        topicId = try c.decodeIfPresent(Int.self, forKey: .topicId)
        topicName = try c.decodeIfPresent(String.self, forKey: .topicName)
        memberId = try c.decodeIfPresent(Int.self, forKey: .memberId)
        merchantName = try c.decodeIfPresent(String.self, forKey: .merchantName)
        merchantMeta = try c.decodeIfPresent(String.self, forKey: .merchantMeta)
        addressName = try c.decodeIfPresent(String.self, forKey: .addressName)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        auditStatus = try c.decodeIfPresent(Int.self, forKey: .auditStatus)
    }
}
public struct CooperationRegistrations: Decodable, Equatable {
    public let rows: [CooperationRegistration]
    public let hasMore: Bool?
    enum CodingKeys: String, CodingKey { case rows, hasMore }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rows = try c.decodeIfPresent([CooperationRegistration].self, forKey: .rows) ?? []
        hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore)
    }
}
public struct CooperationPoolItem: Decodable, Equatable {
    public let topicId: Int
    public let name: String?
    public let subtitle: String?
    public let cover: String?
    public let startDate: CooperationSourceTime?
    public let endDate: CooperationSourceTime?
    public let recruitDeadline: CooperationSourceTime?
    public let merchantNick: String?
    public let state: String?
    public let applyId: Int?
    public var stateKey: String {
        guard let state, ["open", "applied", "invited", "taken", "cooped", "converted", "declined", "withdrawn"].contains(state) else { return "cooperation.status.unknown" }
        return "cooperation.pool.state.\(state)"
    }
    enum CodingKeys: String, CodingKey { case topicId, name, subtitle, cover, startDate, endDate, recruitDeadline, merchantNick, state, applyId }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        topicId = try c.positiveID(.topicId)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        cover = try c.decodeIfPresent(String.self, forKey: .cover)
        startDate = try c.decodeIfPresent(CooperationSourceTime.self, forKey: .startDate)
        endDate = try c.decodeIfPresent(CooperationSourceTime.self, forKey: .endDate)
        recruitDeadline = try c.decodeIfPresent(CooperationSourceTime.self, forKey: .recruitDeadline)
        merchantNick = try c.decodeIfPresent(String.self, forKey: .merchantNick)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        applyId = try c.decodeIfPresent(Int.self, forKey: .applyId)
    }
}
public struct CooperationPool: Decodable, Equatable {
    public let rows: [CooperationPoolItem]
    public let hasClub: Bool
    enum CodingKeys: String, CodingKey { case rows, hasClub }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rows = try c.decodeIfPresent([CooperationPoolItem].self, forKey: .rows) ?? []
        hasClub = try c.decodeIfPresent(Bool.self, forKey: .hasClub) ?? false
    }
}
public struct CooperationClubCandidate: Decodable, Equatable {
    public let id: Int
    public let clubName: String?
    public let message: String?
    public let status: Int?
    public let inviteStatus: String?
    public let createTime: CooperationSourceTime?
    public var statusKey: String {
        guard let status, (0...3).contains(status) else { return "cooperation.status.unknown" }
        return "cooperation.application.status.\(status)"
    }
    enum CodingKeys: String, CodingKey { case id, clubName, message, status, inviteStatus, createTime }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.positiveID(.id)
        clubName = try c.decodeIfPresent(String.self, forKey: .clubName)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        status = try c.decodeIfPresent(Int.self, forKey: .status)
        inviteStatus = try c.decodeIfPresent(String.self, forKey: .inviteStatus)
        createTime = try c.decodeIfPresent(CooperationSourceTime.self, forKey: .createTime)
    }
}
public struct CooperationMerchantCandidate: Decodable, Equatable {
    public let id: Int
    public let name: String?
    public let status: Int?
    enum CodingKeys: String, CodingKey { case id, name, merchantName, status }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.positiveID(.id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? c.decodeIfPresent(String.self, forKey: .merchantName)
        status = try c.decodeIfPresent(Int.self, forKey: .status)
    }
}
public struct CooperationCandidates: Decodable, Equatable {
    public let clubApplies: [CooperationClubCandidate]
    public let registrations: [CooperationMerchantCandidate]
    enum CodingKeys: String, CodingKey { case clubApplies, registrations }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clubApplies = try c.decodeIfPresent([CooperationClubCandidate].self, forKey: .clubApplies) ?? []
        registrations = try c.decodeIfPresent([CooperationMerchantCandidate].self, forKey: .registrations) ?? []
    }
}
private extension KeyedDecodingContainer {
    func positiveID(_ key: Key) throws -> Int {
        let value = try decode(Int.self, forKey: key)
        guard value > 0 else { throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Invalid cooperation identity") }
        return value
    }
}

public enum CooperationReadFailure: Error, Equatable {
    case forbidden(message: String?)
    case rejected(code: Int, message: String?)
    case httpStatus(Int, message: String?)
    case unavailable
    case ambiguousIdentity
}
public enum CooperationIssue: Equatable {
    case login, unconfigured, failure, malformed, unavailable, ambiguousIdentity
    case forbidden(String?), server(String)
    public init(_ error: Error) {
        switch error {
        case APIError.unauthorized: self = .login
        case APIError.notConfigured: self = .unconfigured
        case APIError.malformedResponse: self = .malformed
        case CooperationReadFailure.unavailable: self = .unavailable
        case CooperationReadFailure.ambiguousIdentity: self = .ambiguousIdentity
        case CooperationReadFailure.forbidden(let message): self = .forbidden(message)
        case CooperationReadFailure.rejected(_, let message), CooperationReadFailure.httpStatus(_, let message):
            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { self = .server(message) }
            else { self = .failure }
        default: self = .failure
        }
    }
    public var key: String {
        switch self {
        case .login: return "cooperation.login"
        case .unconfigured: return "cooperation.unconfigured"
        case .failure, .server: return "cooperation.failure"
        case .malformed: return "cooperation.malformed"
        case .unavailable: return "cooperation.unavailable"
        case .ambiguousIdentity: return "cooperation.ambiguous"
        case .forbidden: return "cooperation.forbidden"
        }
    }
    public var canRetry: Bool {
        switch self { case .failure, .malformed, .server: return true; default: return false }
    }
}
public enum CooperationSection<Value> {
    case content(Value), failure(CooperationIssue)
}
/// Each inbox source settles independently. A failed section is never represented by an empty array.
public struct CooperationInbox {
    public let direction: CooperationDirection
    public let invitations: CooperationSection<CooperationInvites>
    public let applications: CooperationSection<[CooperationApplication]>
    public let registrations: CooperationSection<CooperationRegistrations>?
    public init(direction: CooperationDirection, invitations: CooperationSection<CooperationInvites>, applications: CooperationSection<[CooperationApplication]>, registrations: CooperationSection<CooperationRegistrations>?) {
        self.direction = direction; self.invitations = invitations; self.applications = applications; self.registrations = registrations
    }
    public var isPartial: Bool {
        if case .failure = invitations { return true }
        if case .failure = applications { return true }
        if let registrations, case .failure = registrations { return true }
        return false
    }
}
