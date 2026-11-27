import SwiftUI
import MapKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Everything the map home needs from the session. Hosts pass the same readers and destinations the
/// City root (`SessionCityRoamRoot`) and the roam browser (`RoamBrowserView`) already use.
struct RoamMapHomeDependencies {
    let roamReader: any RoamReading
    var entryReader: (any RoamEntryNearbyReading)? = nil
    var entryTeams: ((RoamSearchArea) async -> [NearbyTeam]?)? = nil
    var officialRouteReader: OfficialRouteReader? = nil
    var locationSettings: (any RoamLocationSettingsProviding)? = nil
    var mediaScope = UUID()
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    /// Live roam (`RoamLiveSessionView`), shown as a full-screen cover.
    var liveDestination: (() -> AnyView)? = nil
    /// 漫游护照与工具: the shipped roam browser, opened as a sheet (`presentedAsSheet`).
    var passportDestination: (() -> AnyView)? = nil
    /// The City Monopoly board (the previous tab root), shown as a full-screen map mode.
    var cityBoardDestination: (() -> AnyView)? = nil
    /// The full place page with every POI action (`RoamItemDetailView`).
    var placeDetailDestination: ((RoamMapItem) -> AnyView)? = nil
    var eventDestination: ((RoamEventDestination) -> AnyView)? = nil
    var myTeamsDestination: (() -> AnyView)? = nil
    var nearbyTeamsDestination: (() -> AnyView)? = nil
    var nearbyTeamDestination: ((NearbyTeamID) -> AnyView)? = nil
    /// P-037: the search map reader (`AppSession.searchMapReader`). A submitted search shows its results as pins on
    /// this map; the explorer is no longer pushed as a second map inside the sheet.
    var searchReader: (any SearchMapReading)? = nil
    var onChooseArea: (() -> Void)? = nil
    var onOpenAccount: (() -> Void)? = nil
}

/// Native r2 漫游 tab root: a full-screen MapKit `Map` and one persistent bottom panel (Apple Maps detents).
/// The panel lives inside the tab, as in Find My, so the system tab bar stays visible under it.
@MainActor struct RoamMapHomeView: View {
    let dependencies: RoamMapHomeDependencies
    @State private var model = RoamMapHomeModel()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var cameraArea: RoamSearchArea?
    @ObservedObject private var cityLinks = CityDeepLinks.shared
    /// P-035: the peek grows with Dynamic Type so the search field is never clipped.
    @ScaledMetric(relativeTo: .body) private var peekHeight: CGFloat = RoamMapHomeModel.peekHeight

    private var area: RoamSearchArea? { dependencies.entryReader?.searchArea ?? dependencies.roamReader.searchArea }

    private struct PlacesKey: Equatable {
        let area: RoamSearchArea?
        let identity: RoamReadIdentity?
        let configured: Bool
        let radius: Int
        let wantsStops: Bool
        let generation: Int
    }
    private var placesKey: PlacesKey {
        let reader = dependencies.roamReader
        return PlacesKey(area: reader.searchArea, identity: reader.identity, configured: reader.isConfigured,
                         radius: model.radius, wantsStops: model.category == .routes, generation: model.reloadGeneration)
    }

    var body: some View {
        GeometryReader { proxy in
            map
                .safeAreaPadding(.bottom, RoamMapHomePanelMetrics.mapInset(detent: model.detent, available: proxy.size.height, peek: peekHeight))
                .overlay(alignment: .bottom) {
                    RoamMapHomePanel(detent: $model.detent, available: proxy.size.height, peekHeight: peekHeight) {
                        RoamMapHomeSheet(model: model, dependencies: dependencies)
                    }
                }
        }
        .onChange(of: model.selectedPinID) { _, id in model.open(pinID: id) }
        .onChange(of: model.path) { _, _ in model.pathChanged() }
        .onChange(of: model.officialRoute) { _, route in
            guard let route else { return }
            fit(RoamMapHomePin.make(officialRoute: route).map(\.coordinate))
        }
        // P-037: a landed search frames its pins on this map.
        .onChange(of: model.searchRevision) { _, _ in
            fit(model.searchPins(center: area?.coordinate).map(\.coordinate))
        }
        .task(id: (dependencies.entryReader?.readKey ?? "") + "|" + String(model.reloadGeneration)) {
            await model.loadEntry(reader: dependencies.entryReader, teams: dependencies.entryTeams)
        }
        .task(id: placesKey) {
            await model.loadPlaces(reader: dependencies.roamReader)
            if placesKey.wantsStops { await model.loadStops(reader: dependencies.roamReader) }
        }
        .onChange(of: area, initial: true) { _, newArea in recentre(on: newArea) }
        .onChange(of: cityLinks.pendingProperty, initial: true) { _, id in
            // A City property deep link still opens on the City board (decision 1: the board is a map mode).
            if id != nil, dependencies.cityBoardDestination != nil { model.showsCityBoard = true }
        }
    }

    /// The map layer under the panel.
    private var map: some View {
        Map(position: $position, selection: $model.selectedPinID) {
            UserAnnotation()
            ForEach(model.mapPins(reader: dependencies.entryReader, center: area?.coordinate)) { pin in
                if let monogram = pin.monogram {
                    Marker(pin.title, monogram: Text(verbatim: monogram), coordinate: pin.coordinate)
                        .tint(pin.tint)
                        .tag(pin.id)
                } else {
                    Marker(pin.title, systemImage: pin.systemImage, coordinate: pin.coordinate)
                        .tint(pin.tint)
                        .tag(pin.id)
                }
            }
            if let route = model.officialRoute {
                MapPolyline(coordinates: RoamMapHomePin.make(officialRoute: route).map(\.coordinate))
                    .stroke(.tint, lineWidth: 5)
            }
        }
        .mapStyle(model.satellite ? .hybrid(elevation: .realistic) : .standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        // MP maps set show-location="{{false}}" (pages/roam): no locate-me button (fix-r11 N-r11-2, P9 minimal controls).
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapScaleView()
        }
        .accessibilityIdentifier("city.roam.map")
    }

    private func recentre(on newArea: RoamSearchArea?) {
        guard let newArea, newArea != cameraArea else { return }
        cameraArea = newArea
        let meters = CLLocationDistance(max(model.radius, 1000) * 2)
        position = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: newArea.coordinate.latitude, longitude: newArea.coordinate.longitude),
            latitudinalMeters: meters, longitudinalMeters: meters))
    }

    private func fit(_ coordinates: [CLLocationCoordinate2D]) {
        guard let first = coordinates.first else { return }
        var minLat = first.latitude, maxLat = first.latitude, minLng = first.longitude, maxLng = first.longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let span = MKCoordinateSpan(latitudeDelta: max(0.005, (maxLat - minLat) * 1.6), longitudeDelta: max(0.005, (maxLng - minLng) * 1.6))
        withAnimation {
            position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2), span: span))
        }
    }
}
