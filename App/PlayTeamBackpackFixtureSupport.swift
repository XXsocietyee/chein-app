#if DEBUG
import SwiftUI

@MainActor final class PlayTeamBackpackFixtureReader: PlayTeamBackpackReading {
    let snapshot: PlayTeamBackpackCommandSnapshot
    init(snapshot: PlayTeamBackpackCommandSnapshot) { self.snapshot = snapshot }
    func projection(activityID: Int) async throws -> PlayTeamBackpackCommandSnapshot {
        guard activityID == 41 else { throw PlayExperienceError.malformed }
        return snapshot
    }
}

@available(macOS 14.0, *)
@MainActor struct PlayTeamBackpackFixtureHost: View {
    var body: some View {
        if let model = Self.model() { PlayTeamBackpackView(model: model) }
        else { Text("play.teamBackpack.failed").accessibilityIdentifier("play.teamBackpack.failed") }
    }

    static func model() -> PlayTeamBackpackCoordinator? {
        let unknown = ProcessInfo.processInfo.arguments.contains("--play-team-backpack=unknown")
        let raw = PlayWireValue.object([
            "scope": .string("TEAM"),
            "activityId": .int(41),
            "revision": .int(3),
            "authorityEpoch": .int(2),
            "allowDiscard": .bool(true),
            "availableActions": .array([.string("ITEM_USE"), .string("ITEM_DISCARD"), .string("ITEM_RECEIVE")]),
            "contents": .array([.object([
                "kind": .string("ITEM"), "id": .string("tea"), "name": .string("Tea"), "stat": .string("hp"), "quantity": .int(1)
            ])]),
            "pending": .object(["lantern": .object(["name": .string("Lantern"), "itemId": .string("lantern"), "quantity": .int(1)])])
        ])
        guard let snapshot = try? PlayTeamBackpackCommandSnapshot(raw: raw, activityID: 41) else { return nil }
        let coordinator = PlayTeamBackpackCoordinator(activityID: 41, reader: PlayTeamBackpackFixtureReader(snapshot: snapshot),
                                                     client: nil, token: { nil })
        if unknown { coordinator.present(.unknown(requestID: "pg-theme-unknown")) }
        return coordinator
    }
}
#endif
