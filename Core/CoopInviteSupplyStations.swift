import Foundation

/// One confirmed supply station a merchant can serve the topic from (MP `supplyStations` row).
public struct CoopInviteStationOption: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public init(id: Int, name: String) { self.id = id; self.name = name }
}

/// MP `pages/coop/invite` 核销据点 card (wxml:114-131, js:578-650): every merchant invite on a station topic names
/// exactly one confirmed station; the merchant's accept freezes it.
public enum CoopInviteSupplyStations {
    /// The `api/coop/supply-stations` reply for one merchant.
    public struct Reply: Equatable, Sendable {
        public let required: Bool
        public let stations: [CoopInviteStationOption]
    }

    /// MP js:608-611: `requiresSupplyStation` must be a boolean; when true every row needs a positive
    /// `supplyStationId` and a non-blank `stationName`, with no duplicate ids. Anything else is a failed read (nil).
    public static func parse(_ page: CoopFlowJSON) -> Reply? {
        guard let required = page["requiresSupplyStation"].flag else { return nil }
        guard required else { return Reply(required: false, stations: []) }
        guard let rows = page["stations"].rows else { return nil }
        var options: [CoopInviteStationOption] = []
        for row in rows {
            guard let id = row["supplyStationId"].integer, id > 0,
                  let name = row["stationName"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            options.append(CoopInviteStationOption(id: id, name: name))
        }
        guard Set(options.map(\.id)).count == options.count else { return nil }
        return Reply(required: true, stations: options)
    }

    /// MP js:641-650 `validateSupplyStations`: when the topic needs stations, each selected merchant must hold a
    /// choice that is still in its loaded list.
    public static func ready(required: Bool, merchantIDs: [Int], stations: [Int: [CoopInviteStationOption]],
                             picks: [Int: CoopInviteStationOption]) -> Bool {
        guard required else { return true }
        return merchantIDs.allSatisfy { id in
            guard let pick = picks[id], let list = stations[id] else { return false }
            return list.contains(pick)
        }
    }

    /// Contexts with the chosen station attached (merchant recipients only). Nil when a required choice is missing.
    public static func attach(_ contexts: [CoopFlowInvitationContext], required: Bool,
                              picks: [Int: CoopInviteStationOption]) -> [CoopFlowInvitationContext]? {
        guard required else { return contexts.map { $0.withSupplyStation(nil) } }
        var result: [CoopFlowInvitationContext] = []
        for context in contexts {
            guard context.kind == .merchant else { result.append(context.withSupplyStation(nil)); continue }
            guard let pick = picks[context.recipient.id] else { return nil }
            result.append(context.withSupplyStation(pick))
        }
        return result
    }

}
