import Foundation

/// U06 turn block from the advanced session read (`publicMultiplayer.turn`, hengyin `758bcf9d1`). Every member gets
/// the turn position, round and whether and when it is their turn. Only the leader gets the current role id and the
/// ordered `turnOrder` list; a non-leader projection drops both even if a response carried them.
public struct PlayAdvancedTurn: Equatable, Sendable {
    public struct Slot: Equatable, Identifiable, Sendable {
        public let position: Int
        public let roleID: String
        public let roleLabel: String?
        public var id: Int { position }
        public var display: String { roleLabel ?? roleID }
    }

    public let index: Int
    public let position: Int
    public let size: Int
    public let round: Int
    public let completedTurns: Int
    public let requiredTurns: Int
    public let finished: Bool
    public let myTurn: Bool
    /// Nil when I hold no role in the order or the run is finished.
    public let turnsUntilMine: Int?
    /// Leader only.
    public let currentRoleID: String?
    /// Leader only, in server order.
    public let order: [Slot]

    /// Nil when the backend did not send a valid `turn` block; the view then keeps the older turn index row.
    public init?(multiplayer value: PlayWireValue, isLeader: Bool) {
        let turn = value["turn"]
        guard turn.object != nil,
              let index = turn["index"].integer, index >= 0,
              let size = turn["size"].integer, size > 0, size <= 100,
              let position = turn["position"].integer, position == index % size,
              let round = turn["round"].integer, round >= 1,
              let completed = turn["completedTurns"].integer, completed >= 0,
              let required = turn["requiredTurns"].integer, required > 0,
              let finished = turn["finished"].bool,
              let myTurn = turn["myTurn"].bool else { return nil }
        let until: Int?
        switch turn["turnsUntilMine"] {
        case .null: until = nil
        case let raw:
            guard let wait = raw.integer, wait >= 0, wait < size else { return nil }
            until = wait
        }
        guard myTurn == (until == 0) else { return nil }
        self.index = index; self.position = position; self.size = size; self.round = round
        self.completedTurns = completed; self.requiredTurns = required; self.finished = finished
        self.myTurn = myTurn; self.turnsUntilMine = finished ? nil : until
        guard isLeader else { currentRoleID = nil; order = []; return }
        currentRoleID = finished ? nil : turn["currentRoleId"].text.flatMap { $0.isEmpty || $0.utf16.count > 64 ? nil : $0 }
        var slots: [Slot] = []
        for (offset, item) in (value["turnOrder"].array ?? []).enumerated() {
            guard item["position"].integer == offset, let role = item["roleId"].text, !role.isEmpty, role.utf16.count <= 64 else { return nil }
            let label = item["roleLabel"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
            slots.append(.init(position: offset, roleID: role, roleLabel: label.flatMap { $0.isEmpty || $0.utf16.count > 256 ? nil : $0 }))
        }
        guard slots.isEmpty || slots.count == size else { return nil }
        order = slots
    }

    /// Position of the next turn in the order; nil once the run is finished or this is the last required turn.
    public var nextPosition: Int? {
        guard !finished, completedTurns + 1 < requiredTurns else { return nil }
        return (position + 1) % size
    }

    /// Whether the next turn is mine, from my own wait count only (no other member's role is needed).
    public var nextIsMine: Bool? {
        guard nextPosition != nil else { return nil }
        guard let wait = turnsUntilMine else { return false }
        return wait == 1 || size == 1
    }

    /// Leader: the role holding the current and next turn.
    public var currentSlot: Slot? { finished || order.isEmpty ? nil : order[position] }
    public var nextSlot: Slot? { nextPosition.flatMap { order.isEmpty ? nil : order[$0] } }
}
