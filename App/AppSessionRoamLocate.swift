import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

extension AppSession {
    /// Function audit P1-17 / MP pages/roam/index.js `enableEntryLocation`: one foreground fix through the standard
    /// permission flow (primer → system prompt), converted to GCJ-02 once, becomes the 漫游 search area. Same
    /// provider the nearby-teams 定位 button uses; no background location, nothing persisted.
    @MainActor func locateRoamArea() async throws -> RoamSearchArea {
        let fix = try await RoamDeviceFixGCJ.currentGCJ02Fix(provider: RuntimeNativeLocationProvider(enabled: true))
        let area = RoamSearchArea(coordinate: fix.coordinate, label: "")
        if roamArea?.coordinate != area.coordinate { roamArea = area }
        return area
    }
}
