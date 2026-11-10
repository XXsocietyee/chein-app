import SwiftUI

/// W2-4: the finish moment of a roam. Presentation only. It reads the same gate as `RoamFinishedMedalsPresentation`
/// (a complete, archived settlement for the session this controller owns) and hands the already-decided numbers to the
/// celebration queue. It writes nothing, decides nothing and never invents a value: anything the settlement or the saved
/// history does not provide stays `nil` and renders as an em dash.
@MainActor enum RoamSummaryCelebration {
    /// The server session id once the walk is fully settled and archived; nil in every other state.
    static func settledSessionID(_ controller: RoamLiveSessionController) -> Int? {
        guard controller.phase == .finished, controller.isAvailable, controller.foreground,
              !controller.busy, controller.record == nil,
              controller.makeFinishedHistoryReader().identity != nil,
              let reference = controller.completedHistory,
              let fact = controller.settlement, fact.hasCompleteSettlement,
              fact.sessionID == reference.serverSessionID else { return nil }
        return reference.serverSessionID
    }

    static func payload(_ controller: RoamLiveSessionController, history: RoamFinishedHistoryReader) -> CYRoamSummaryPayload? {
        guard let id = settledSessionID(controller), let reference = controller.completedHistory,
              let result = controller.settlement?.result else { return nil }
        // Distance comes from the archived record of this very walk; a missing or unreadable record is unknown, not 0.
        let kilometers = (try? history.history())?.first { $0.ts == reference.timestamp }?.distance
        let route = controller.finishedRouteTrack ?? []
        return CYRoamSummaryPayload(
            id: String(id),
            kilometers: kilometers,
            tiles: result.newTiles,
            stamps: result.newPois,
            route: CYShareCardContent.silhouette(latitudes: route.map(\.lat), longitudes: route.map(\.lng)))
    }
}
