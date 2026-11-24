import Foundation

/// U06-01 (B6): the read-only `seats` / `invite` / `viewer` projections of `POST /api/team/info`.
/// Every field is optional: a missing or malformed value stays unknown and is never drawn as 0.
/// The withdrawn `claimable`, `reservedApplications`, `unpaidOccupied` and `viewer.memberId`
/// are deliberately not decoded. None of these facts authorizes a write; `reserveSlot` on the
/// server decides the last seat and the write response is the only verdict.
public struct TeamSeatFacts: Equatable, Sendable {
    /// `max_members`.
    public let capacity: Int?
    /// `joined_count`, the only seat source of truth.
    public let occupied: Int?
    /// Seats still open to a joiner.
    public let available: Int?
    /// Joined and still holding a valid ticket for this session.
    public let paidOccupied: Int?
    /// Joined but the ticket is no longer valid. Not a claimable unpaid seat.
    public let paidTicketMissing: Int?
    /// Unexpired applications awaiting review. Applications never hold a seat.
    public let pendingApplications: Int?
    public init(capacity: Int?, occupied: Int?, available: Int?, paidOccupied: Int?, paidTicketMissing: Int?, pendingApplications: Int?) {
        self.capacity = capacity; self.occupied = occupied; self.available = available
        self.paidOccupied = paidOccupied; self.paidTicketMissing = paidTicketMissing; self.pendingApplications = pendingApplications
    }
}

public struct TeamInviteFacts: Equatable, Sendable {
    public enum Mode: String, Sendable { case publicApplication = "PUBLIC", inviteOnly = "INVITE_ONLY" }
    public let mode: Mode?
    public let available: Bool?
    /// Replays `play_team.expire_time` only; the client sets no expiry rule of its own.
    public let expiresAt: String?
    public let expired: Bool?
    public init(mode: Mode?, available: Bool?, expiresAt: String?, expired: Bool?) {
        self.mode = mode; self.available = available; self.expiresAt = expiresAt; self.expired = expired
    }
}

/// The viewer's own relationship. Team captaincy (`leader`, `role == 1`) is a team duty,
/// separate from a story role in a run and from host permissions.
public struct TeamViewerFacts: Equatable, Sendable {
    public enum ApplicationStatus: String, Sendable { case joined = "JOINED", pending = "PENDING", expired = "EXPIRED", quit = "QUIT", kicked = "KICKED", rejected = "REJECTED", withdrawn = "WITHDRAWN" }
    public let joined: Bool?
    public let leader: Bool?
    public let role: Int?
    public let applicationStatus: ApplicationStatus?
    public let applyExpireTime: String?
    /// Hints only. A true value does not mean the write will succeed.
    public let canApply: Bool?
    public let canJoinWithCode: Bool?
    public let applyBlockers: [String]
    public let joinBlockers: [String]
    public init(joined: Bool?, leader: Bool?, role: Int?, applicationStatus: ApplicationStatus?, applyExpireTime: String?,
                canApply: Bool?, canJoinWithCode: Bool?, applyBlockers: [String], joinBlockers: [String]) {
        self.joined = joined; self.leader = leader; self.role = role; self.applicationStatus = applicationStatus
        self.applyExpireTime = applyExpireTime; self.canApply = canApply; self.canJoinWithCode = canJoinWithCode
        self.applyBlockers = applyBlockers; self.joinBlockers = joinBlockers
    }
}

extension TeamSeatFacts: Decodable {
    enum CodingKeys: String, CodingKey { case capacity, occupied, available, paidOccupied, paidTicketMissing, pendingApplications }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        capacity = c.seatCount(.capacity); occupied = c.seatCount(.occupied); available = c.seatCount(.available)
        paidOccupied = c.seatCount(.paidOccupied); paidTicketMissing = c.seatCount(.paidTicketMissing)
        pendingApplications = c.seatCount(.pendingApplications)
    }
}

extension TeamInviteFacts: Decodable {
    enum CodingKeys: String, CodingKey { case mode, available, expiresAt, expired }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = c.seatText(.mode).flatMap(Mode.init(rawValue:))
        available = c.seatBool(.available); expired = c.seatBool(.expired)
        expiresAt = c.seatText(.expiresAt)
    }
}

extension TeamViewerFacts: Decodable {
    enum CodingKeys: String, CodingKey { case joined, leader, role, applicationStatus, applyExpireTime, canApply, canJoinWithCode, applyBlockers, joinBlockers }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        joined = c.seatBool(.joined); leader = c.seatBool(.leader)
        role = c.seatCount(.role)
        applicationStatus = c.seatText(.applicationStatus).flatMap(ApplicationStatus.init(rawValue:))
        applyExpireTime = c.seatText(.applyExpireTime)
        canApply = c.seatBool(.canApply); canJoinWithCode = c.seatBool(.canJoinWithCode)
        applyBlockers = c.seatCodes(.applyBlockers); joinBlockers = c.seatCodes(.joinBlockers)
    }
}

private extension KeyedDecodingContainer {
    /// A non-negative integer or nil. Strings of digits are accepted the way other team fields are.
    func seatCount(_ key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) { return value >= 0 ? value : nil }
        if let text = try? decode(String.self, forKey: key), let value = Int(text) { return value >= 0 ? value : nil }
        return nil
    }
    func seatBool(_ key: Key) -> Bool? { try? decode(Bool.self, forKey: key) }
    func seatText(_ key: Key) -> String? {
        guard let text = try? decode(String.self, forKey: key) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    func seatCodes(_ key: Key) -> [String] {
        ((try? decode([String].self, forKey: key)) ?? []).filter(TeamSeatPresentation.isMachineCode)
    }
}

/// Mini-program `pages/team/utils/team-seats.js`, translated: copy keys only, never arithmetic
/// that invents a seat category.
public enum TeamSeatPresentation {
    public struct Row: Equatable, Identifiable, Sendable {
        public enum Kind: String, Sendable { case paid, missing, pending, available }
        public let kind: Kind
        public let value: Int
        public var id: String { kind.rawValue }
        public var labelKey: String { "team.seats.\(kind.rawValue)" }
        /// `票已失效` is the one warning row.
        public var warning: Bool { kind == .missing }
    }
    public enum InviteLine: Equatable, Sendable { case unavailable, expires(String) }

    /// Blocker codes shared by `/info` hints and the `/join` and `/apply` write rejections.
    public static let knownBlockers: [String] = [
        "NOT_SIGNED_IN", "ALREADY_JOINED", "APPLY_REJECTED", "TEAM_FULL", "TEAM_UNDER_REVIEW", "APPLY_BLOCKED",
        "TICKET_REQUIRED", "TEAM_NOT_PUBLIC", "APPLY_PENDING", "INVITE_UNAVAILABLE"
    ]
    /// Write-path codes (U06-01 `/join`, U06-03 quit/kick/handover) that get their own copy.
    public static let knownRejections: Set<String> = Set(knownBlockers).union([
        "INVITE_REVOKED", "INVITE_EXPIRED", "TEAM_STATE_CHANGED", "LEADER_HANDOVER_FAILED", "APPLY_STATE_CHANGED", "APPLY_NOT_PENDING"
    ])
    /// pages/team/join sets `ticketRequired` when `errorCode === TICKET_REQUIRED` and shows this CTA.
    public static let buyTicketTitle = "去买这一场的票"
    public static func showsBuyTicket(errorCode: String?) -> Bool { errorCode == "TICKET_REQUIRED" }

    static func isMachineCode(_ code: String) -> Bool {
        !code.isEmpty && code.utf8.count <= 64 && code.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == "_" }
    }

    /// 持有效票 / 票已失效 (only when > 0) / 待审申请 (only when > 0) / 还可加入. Unknown rows are omitted.
    public static func rows(_ seats: TeamSeatFacts?) -> [Row] {
        guard let seats else { return [] }
        var rows: [Row] = []
        if let paid = seats.paidOccupied { rows.append(.init(kind: .paid, value: paid)) }
        if let missing = seats.paidTicketMissing, missing > 0 { rows.append(.init(kind: .missing, value: missing)) }
        if let pending = seats.pendingApplications, pending > 0 { rows.append(.init(kind: .pending, value: pending)) }
        if let available = seats.available { rows.append(.init(kind: .available, value: available)) }
        return rows
    }

    /// Open seats prefer the server's `seats.available`; the source falls back to `max - joined`
    /// only when both are known. Unknown stays nil and nothing is drawn.
    public static func openSeats(team: OwnedTeam, seats: TeamSeatFacts?) -> Int? {
        if let available = seats?.available { return available }
        guard let max = team.maxMembers, let joined = team.joinedCount else { return nil }
        return Swift.max(0, max - joined)
    }

    /// The server's `expired` / `available` win; otherwise the replayed `expiresAt`.
    public static func inviteLine(_ invite: TeamInviteFacts?) -> InviteLine? {
        guard let invite else { return nil }
        if invite.expired == true || invite.available == false { return .unavailable }
        return invite.expiresAt.map(InviteLine.expires)
    }

    public enum Entry: Sendable { case join, apply }
    /// The first recognised blocker as a copy key. Only a hint; the join button stays and the write decides.
    public static func blockerKey(_ viewer: TeamViewerFacts?, entry: Entry) -> String? {
        let list = entry == .join ? viewer?.joinBlockers : viewer?.applyBlockers
        return list?.first(where: knownBlockers.contains).map { "team.blocker.\($0)" }
    }

    /// Branch on the machine code, never on the Chinese message.
    public static func rejectionKey(_ code: String?) -> String {
        guard let code, knownRejections.contains(code) else { return "team.rejected" }
        return "team.reject.\(code)"
    }

    /// Team duty only. Story roles and host permissions come from their own projections.
    public static func dutyKey(_ viewer: TeamViewerFacts?, detail: TeamDetail) -> String? {
        let joined = viewer?.joined ?? detail.joined
        let leader = viewer?.leader ?? detail.leader
        guard joined == true, let leader else { return nil }
        return leader ? "team.viewer.captain" : "team.viewer.member"
    }

    /// U06-03 (mini `team.quit` / `team.quit-leader`): a member does not read the captain's handover
    /// consequence. The server still decides the handover and answers `LEADER_HANDOVER_FAILED` when it cannot.
    public static func consequenceKey(_ action: TeamAction, detail: TeamDetail?) -> String {
        guard case .leave = action, let detail else { return action.consequenceKey }
        switch detail.viewer?.leader ?? detail.leader {
        case true?: return "team.leave.consequence.leader"
        case false?: return "team.leave.consequence.member"
        case nil: return action.consequenceKey
        }
    }

    /// The viewer's own application history on an invitation page (not joined).
    public static func applicationKey(_ viewer: TeamViewerFacts?) -> String? {
        guard let viewer, viewer.joined != true, let status = viewer.applicationStatus, status != .joined else { return nil }
        return "team.viewer.application.\(status.rawValue)"
    }
}
