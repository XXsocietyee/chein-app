import Foundation

/// Carries the owned registration identity alongside the activity context. Re-read this
/// exact registration before creation; an arbitrary activity ID is not eligibility proof.
public struct OrderLifecycleTeamSource: Equatable {
    public let registrationID: Int
    public let context: TeamCreationContext
}
public extension OrderLifecycleDetail {
    var teamCreationSource: OrderLifecycleTeamSource? {
        guard ownerType == 2, let ownerID, ownerID > 0, registrationStatus == 2,
              teamMode == 2, let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return OrderLifecycleTeamSource(registrationID: id, context: TeamCreationContext(ownerID: ownerID, title: title,
            registrationStatus: 2, teamMode: 2, maxMembers: teamMaxMembers))
    }

    /// Mini-program `teamOpen`: an activity registration that is paid, not completed, and a team mode 1 or 2 order.
    /// Mode 1 opens the screen; only mode 2 is a creation source (`teamCreationSource`).
    public var teamOpen: Bool {
        guard ownerType == 2, let ownerID, ownerID > 0, registrationStatus == 2,
              teamMode == 1 || teamMode == 2 else { return false }
        return summary().state != .completed
    }
}

public extension OrderLifecycleDetail {
    /// Planning audit G-04 (owner S14: refund + new purchase, no rebooking). After a refund or a cancellation the
    /// order detail links back to the activity so the player can pick a session and buy again. Activity orders only.
    var reorderActivityID: Int? {
        guard ownerType == 2, let ownerID, ownerID > 0 else { return nil }
        switch summary().state {
        case .refunded, .cancelled: return ownerID
        default: return nil
        }
    }
}
