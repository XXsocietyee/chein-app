import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// Composition for the City kit: the board store is built from the reviewed CITY lease services
// (`makeCityMonopolyService`, `makeRoamTerritoryService`); without the lease it is `.unavailable`
// and every City surface hides itself.

extension AppSession {
    /// One board store per CITY identity. Reads and writes go through the reviewed CITY lease only.
    func makeCityBoardStore() -> CityBoardStore {
        let monopoly = makeCityMonopolyService()
        let territory = makeRoamTerritoryService()
        let nearby: CityNearbyRead? = territory.map { service in
            { coordinate in try await service.nearby(lat: coordinate.latitude, lng: coordinate.longitude, radius: 3_000) }
        }
        let member = currentRuntimeDependencyContext.map { Int64($0.session.accountID) }
        return CityBoardStore(service: monopoly, nearby: nearby, memberID: member)
    }

    /// A GCJ-02 device fix (the backend datum), through the runtime location provider.
    func cityCaptureFix() -> @MainActor () async throws -> RoamDeviceFix {
        { try await RoamDeviceFixGCJ.currentGCJ02Fix(provider: RuntimeNativeLocationProvider(enabled: true)) }
    }

    /// The claim photo uploader (the roam territory's retained-image upload). Nil without media scope.
    func makeCityClaimPhotoUploader() -> CityClaimPhotoUploading? {
        makeRoamTerritoryPhotoContext().map { CityRetainedClaimPhotoUploader(context: $0) }
    }
}

/// The 漫游 tab root host: builds the store once per CITY identity and hands the shipped roam page
/// to the root as its passport destination.
@MainActor struct SessionCityRoamRoot: View {
    @EnvironmentObject private var session: AppSession
    let liveDestination: (() -> AnyView)?
    let passportDestination: () -> AnyView
    var onChooseArea: (() -> Void)?

    @State private var store: CityBoardStore?
    @State private var identity: String?

    /// The retained live controller (the one the live page drives), for the flagged live-on-map controls.
    private var liveController: (@MainActor () -> RoamLiveSessionController)? {
        guard liveDestination != nil else { return nil }
        let session = session
        return { session.makeRoamLiveSessionController() }
    }

    var body: some View {
        Group {
            if let store {
                CityRoamRootView(store: store, dependencies: CityRoamRootDependencies(
                    captureFix: session.cityCaptureFix(),
                    fallbackCenter: session.roamArea?.coordinate,
                    photoUploader: session.makeCityClaimPhotoUploader(),
                    liveDestination: liveDestination,
                    liveController: liveController,
                    passportDestination: passportDestination,
                    onChooseArea: onChooseArea))
                    .id(identity)
            } else {
                Color.clear
            }
        }
        .task(id: session.cityPlayerReadIdentity) {
            guard identity != session.cityPlayerReadIdentity || store == nil else { return }
            identity = session.cityPlayerReadIdentity
            store = session.makeCityBoardStore()
        }
        .themeDomain(.player)
    }
}
