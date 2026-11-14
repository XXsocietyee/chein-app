import Foundation

/// Current publicMultiplayer/publicRuntimeConfig projection, not the obsolete
/// mini client's `roles` alias. Other members' roles are leader-only data.
public struct PlayAdvancedTeamProjection: Equatable {
    public struct Member: Equatable, Identifiable { public let id: Int; public let name: String; public let roleID: String? }
    public struct Role: Equatable, Identifiable { public let id: String; public let label: String; public let maximum: Int }
    public let members: [Member]; public let roles: [Role]
    public let assignment: String; public let myRole: String?
    /// Server `myRoleLabel` (OWN-U06-02). Non-leaders never receive the role table, so this is their only label.
    public let myRoleLabel: String?
    /// OWN-U06-02. Only the viewer's task, evidence and private clues. Another role's `privateClues` object is never stored.
    public let myTask: String?
    public let myEvidence: [String]
    public let myPrivateClues: [String]
    public let turnIndex: Int; public let completedUnits: Int; public let requiredTurns: Int
    public let isLeader: Bool
    /// U06 turn block; nil when the backend does not send one.
    public let turn: PlayAdvancedTurn?
    public init?(state: PlayAdvancedState, actorID: Int) {
        let config = state.config["multiplayer"], value = state.multiplayer
        guard state.isMultiplayer, state.ownerType == 2, actorID > 0,
              let rawMembers = value["members"].array, !rawMembers.isEmpty, rawMembers.count <= 100,
              let index = value["turnIndex"].integer, index >= 0,
              let units = value["completedUnitIds"].array, units.count <= 10000,
              units.allSatisfy({ $0.text?.isEmpty == false }),
              let required = config["requiredTurns"].integer, required > 0,
              let assignment = config["assignment"].text, ["AUTO", "LEADER"].contains(assignment) else { return nil }
        let isLeader = value["leaderMemberId"].integer == actorID
        let assignments = isLeader ? value["roleAssignments"].object ?? [:] : [:]
        var members: [Member] = []; var ids = Set<Int>()
        for item in rawMembers {
            guard let id = item["memberId"].integer, id > 0, ids.insert(id).inserted,
                  let name = item["name"].text, !name.isEmpty, name.utf16.count <= 256 else { return nil }
            members.append(.init(id: id, name: name, roleID: assignments[String(id)]?.text))
        }
        guard ids.contains(actorID) else { return nil }
        var roles: [Role] = []; var roleIDs = Set<String>()
        if isLeader {
            for item in config["roles"].array ?? [] {
                guard let id = item["id"].text, !id.isEmpty, id.utf16.count <= 64, roleIDs.insert(id).inserted,
                      let label = item["label"].text, !label.isEmpty, label.utf16.count <= 256,
                      let maximum = item["max"].integer, maximum > 0 else { return nil }
                roles.append(.init(id: id, label: label, maximum: maximum))
            }
        }
        self.members = members; self.roles = roles; self.assignment = assignment; self.isLeader = isLeader
        let mine = value["myRole"].text.flatMap { $0.isEmpty || $0.utf16.count > 64 ? nil : $0 }
        let label = value["myRoleLabel"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.myRole = mine
        self.myRoleLabel = mine == nil ? nil : label.flatMap { $0.isEmpty || $0.utf16.count > 256 ? nil : $0 }
        self.myTask = Self.shortText(value["myTask"].text)
        self.myEvidence = Self.shortList(value["myEvidence"])
        self.myPrivateClues = Self.shortList(value["myPrivateClues"])
        self.turn = PlayAdvancedTurn(multiplayer: value, isLeader: isLeader)
        self.turnIndex = index; completedUnits = Set(units.compactMap(\.text)).count; requiredTurns = required
    }
    /// OWN-U06-02. A non-leader never receives another member's role name. No turn block is an em dash, not a guess.
    public func waitingOn(chinese: Bool) -> String {
        guard let turn else { return WP09Copy.unknown }
        if turn.finished { return WP09Copy.text("本轮已结束", "This round is finished", chinese: chinese) }
        if turn.myTurn { return myRoleDisplay ?? WP09Copy.text("轮到我", "My turn", chinese: chinese) }
        if isLeader, let slot = turn.currentSlot { return slot.display }
        if let wait = turn.turnsUntilMine, wait > 0 {
            return WP09Copy.text("还有 \(wait) 轮到我", "My turn in \(wait)", chinese: chinese)
        }
        return WP09Copy.unknown
    }
    /// True when a foreign private-clue string was kept. The projection must not keep one.
    public func exposes(_ needle: String) -> Bool {
        guard !needle.isEmpty else { return false }
        let stored = ([myTask, myRoleLabel].compactMap { $0 } + myEvidence + myPrivateClues).joined(separator: "\n")
        return stored.contains(needle)
    }
    private static func shortText(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed.utf16.count <= 256 else { return nil }
        return trimmed
    }
    private static func shortList(_ value: PlayWireValue) -> [String] {
        let rows = value.array ?? []
        var out: [String] = []
        for item in rows.prefix(32) {
            guard let text = shortText(item.text ?? item["text"].text) else { continue }
            out.append(text)
        }
        return out
    }
    public var canRequestUnit: Bool { myRole != nil && completedUnits < requiredTurns }
    public func canAssign(memberID: Int, roleID: String) -> Bool {
        guard isLeader, assignment == "LEADER", let member = members.first(where: { $0.id == memberID }),
              let role = roles.first(where: { $0.id == roleID }) else { return false }
        return member.roleID != roleID && members.filter { $0.roleID == roleID }.count < role.maximum
    }
    public func roleLabel(_ id: String) -> String { roles.first { $0.id == id }?.label ?? id }
    /// My story role as the server names it; the raw id only when no label was sent.
    public var myRoleDisplay: String? { myRole.map { myRoleLabel ?? roleLabel($0) } }
}

public struct PlayAdvancedTeamReview: Identifiable {
    public enum Action: Equatable { case assign(memberID: Int, roleID: String), completeUnit }
    public let id = UUID(); public let action: Action
    public let sessionID: Int; public let nodeID: Int; public let version: Int
    public let memberName: String?; public let roleLabel: String?
    let owner: PlayExperienceSession
    let surfaceRevision: UInt64
    let surfaceID: UUID
}

public enum PlayAdvancedLeaderboardMetric: String { case elapsed = "ELAPSED_TIME", score = "SCORE", units = "COMPLETED_UNITS" }
