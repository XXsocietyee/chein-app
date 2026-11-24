import Foundation

/// Invitee accept on a station topic. `POST api/coop/handle` adds `supplyStationId` after the confirmation.
/// This is the existing dormant handle write. It does not withdraw, refund, or pay out.
public enum CoopSupplyStationAccept {
    public static let path = "api/coop/handle"
    public static func body(inviteID: Int, reason: String?, supplyStationID: Int) throws -> CoopFlowJSON {
        guard inviteID > 0, supplyStationID > 0 else { throw CoopFlowFailure.invalid("id") }
        var fields: [String: CoopFlowJSON] = ["id": .id(inviteID), "status": .id(CoopFlowHandle.accept.rawValue), "supplyStationId": .id(supplyStationID)]
        if let reason {
            let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { fields["handleReason"] = .string(trimmed) }
        }
        return .object(fields)
    }
}
