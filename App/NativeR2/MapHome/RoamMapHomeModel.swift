import SwiftUI
import MapKit
import Observation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// Native r2 map home (docs/design/native-r2/map-home.md). Pins come only from reads the old roam root and
// roam browser already made: `RoamReading.roamPlaces` / `roamRouteNodes`, the entry peek
// (`RoamEntryNearbyReading.entryNearby` plus its team read) and `OfficialRouteReader`. No new requests.
// P-037: a submitted search runs the same `SearchMapReading.citySearch` the search map explorer ran when it was
// pushed for that keyword; its results become pins on this map instead of a second map in the sheet.

/// The 附近 filter: one segmented `Picker` drives both the map pins and the list (Maps' category row).
enum RoamMapHomeCategory: String, CaseIterable, Identifiable, Hashable {
    case all, activities, places, routes, teams
    var id: String { rawValue }
    var titleKey: LocalizedStringKey {
        switch self {
        case .all: return "nativeR2.mapHome.category.all"
        case .activities: return "nativeR2.mapHome.category.activities"
        case .places: return "nativeR2.mapHome.category.places"
        case .routes: return "nativeR2.mapHome.category.routes"
        case .teams: return "nativeR2.mapHome.category.teams"
        }
    }
}

/// What a pin stands for. Every case keeps the Core value so the card and the full detail use the same facts.
enum RoamMapHomePinPayload: Equatable {
    case place(RoamPlace)
    case routeStop(RoamRouteNode)
    case activity(RoamEntryActivityCard)
    case team(NearbyTeam)
    case officialStop(OfficialRouteNode)
    /// P-037: a city place from the submitted search (`SearchMapReading.citySearch`).
    case searchNode(SearchMapCityNode)
    /// P-037: an activity from the submitted search.
    case searchActivity(ActivitySummary)
}

struct RoamMapHomePin: Identifiable, Equatable {
    let id: String
    let payload: RoamMapHomePinPayload
    let title: String
    let latitude: Double
    let longitude: Double
    /// Server distance in metres, or the distance from the search centre.
    let distanceMeters: Double?

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    var category: RoamMapHomeCategory {
        switch payload {
        case .place, .searchNode: return .places
        case .routeStop, .officialStop: return .routes
        case .activity, .searchActivity: return .activities
        case .team: return .teams
        }
    }

    /// Server search results are already matched by the server; the local filter does not drop them.
    var isSearchResult: Bool {
        switch payload {
        case .searchNode, .searchActivity: return true
        default: return false
        }
    }

    /// Spec §4: SF Symbols per kind, the system balloon draws the rest.
    var systemImage: String {
        switch payload {
        case .place(let place):
            if place.readStatus.discovered == .yes { return "checkmark.circle.fill" }
            return place.type == 2 ? "storefront.fill" : "mappin"
        case .routeStop, .officialStop: return "point.topleft.down.to.point.bottomright.curvepath"
        case .activity(let card):
            if card.activity.kind == "activity", card.activity.linkedTopicID == nil { return "calendar" }
            return card.isFreeExplore ? "map.fill" : "flag.2.crossed.fill"
        case .team: return "person.2.fill"
        case .searchNode(let node): return node.merchantID != nil ? "storefront.fill" : "mappin"
        case .searchActivity: return "calendar"
        }
    }

    var tint: Color {
        switch payload {
        case .place(let place):
            if place.readStatus.discovered == .yes { return .gray }
            return place.type == 2 ? .orange : .red
        case .routeStop, .officialStop: return .green
        case .activity(let card):
            if card.activity.kind == "activity", card.activity.linkedTopicID == nil { return .pink }
            return .teal
        case .team: return .indigo
        case .searchNode(let node): return node.merchantID != nil ? .orange : .red
        case .searchActivity: return .pink
        }
    }

    /// Numbered official-route stops use a monogram marker (Maps' guide numbering).
    var monogram: String? {
        if case .officialStop(let node) = payload { return String(node.order) }
        return nil
    }

    /// The secondary line under the title: kind (and the MP tag for activities).
    var kindKey: LocalizedStringKey {
        switch payload {
        case .place(let place): return place.type == 2 ? "nativeR2.mapHome.kind.merchant" : "nativeR2.mapHome.kind.cityNode"
        case .routeStop, .officialStop: return "nativeR2.mapHome.kind.routeStop"
        case .activity(let card):
            if card.activity.kind == "activity", card.activity.linkedTopicID == nil { return "nativeR2.mapHome.kind.activity" }
            return LocalizedStringKey(card.tagKey)
        case .team: return "nativeR2.mapHome.kind.team"
        case .searchNode(let node): return node.merchantID != nil ? "nativeR2.mapHome.kind.merchant" : "nativeR2.mapHome.kind.cityNode"
        case .searchActivity: return "nativeR2.mapHome.kind.activity"
        }
    }

    var imageURL: URL? {
        let raw: String?
        switch payload {
        case .place(let place): raw = place.coverImage
        case .activity(let card): raw = card.activity.coverURL
        case .team(let team): raw = team.leaderAvatar
        case .officialStop(let node): raw = node.imageURL
        case .routeStop: raw = nil
        case .searchNode(let node): raw = node.imageURL
        case .searchActivity(let activity): raw = activity.imageURL
        }
        guard let raw, raw.hasPrefix("https://") else { return nil }
        return URL(string: raw)
    }

    /// The place the old roam browser opened for this pin (`RoamItemDetailView`), when there is one.
    var roamItem: RoamMapItem? {
        switch payload {
        case .place(let place): return .place(place)
        case .routeStop(let node): return .route(node)
        case .activity, .team, .officialStop, .searchNode, .searchActivity: return nil
        }
    }

    var address: String? {
        let raw: String?
        switch payload {
        case .place(let place): raw = place.address
        case .routeStop(let node): raw = node.address ?? node.addressName
        case .activity(let card): raw = card.activity.addressName
        case .team(let team): raw = team.addressName
        case .officialStop(let node): raw = node.address
        case .searchNode(let node): raw = node.merchantName
        case .searchActivity(let activity): raw = activity.address ?? activity.addressName
        }
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(needle) || (address?.localizedCaseInsensitiveContains(needle) ?? false)
    }

    static func make(places: [RoamPlace], stops: [RoamRouteNode], cards: [RoamEntryActivityCard], teams: [NearbyTeam],
                     center: RoamCoordinate?) -> [RoamMapHomePin] {
        func distance(_ lat: Double, _ lng: Double, server: Double?) -> Double? {
            if let server, server.isFinite, server >= 0 { return server }
            guard let center else { return nil }
            return CLLocation(latitude: center.latitude, longitude: center.longitude)
                .distance(from: CLLocation(latitude: lat, longitude: lng))
        }
        var pins: [RoamMapHomePin] = []
        for card in cards where card.activity.isSupported {
            guard let c = card.activity.coordinate else { continue }
            pins.append(.init(id: "activity-" + card.id, payload: .activity(card), title: card.activity.title,
                              latitude: c.latitude, longitude: c.longitude,
                              distanceMeters: distance(c.latitude, c.longitude, server: card.activity.distance)))
        }
        for place in places where place.isSupported {
            guard let c = place.coordinate else { continue }
            pins.append(.init(id: "place-" + String(place.id), payload: .place(place), title: place.name,
                              latitude: c.latitude, longitude: c.longitude, distanceMeters: distance(c.latitude, c.longitude, server: nil)))
        }
        for node in stops {
            guard let c = node.coordinate else { continue }
            pins.append(.init(id: "route-" + String(node.id), payload: .routeStop(node), title: node.addressName,
                              latitude: c.latitude, longitude: c.longitude,
                              distanceMeters: distance(c.latitude, c.longitude, server: node.distance)))
        }
        for team in teams {
            guard let lat = team.latitude, let lng = team.longitude, RoamCoordinate(latitude: lat, longitude: lng) != nil,
                  lat != 0, lng != 0 else { continue }
            pins.append(.init(id: "team-" + String(team.teamID.rawValue), payload: .team(team), title: team.title,
                              latitude: lat, longitude: lng, distanceMeters: distance(lat, lng, server: team.distance)))
        }
        var seen = Set<String>()
        return pins.filter { seen.insert($0.id).inserted }
    }

    /// P-037: pins for the submitted search's results that carry a coordinate.
    static func make(searchNodes: [SearchMapCityNode], activities: [ActivitySummary], center: RoamCoordinate?) -> [RoamMapHomePin] {
        func distance(_ lat: Double, _ lng: Double, server: Double?) -> Double? {
            if let server, server.isFinite, server >= 0 { return server }
            guard let center else { return nil }
            return CLLocation(latitude: center.latitude, longitude: center.longitude)
                .distance(from: CLLocation(latitude: lat, longitude: lng))
        }
        var pins: [RoamMapHomePin] = []
        for node in searchNodes {
            guard let c = node.coordinate else { continue }
            pins.append(.init(id: "search-node-" + String(node.poiID), payload: .searchNode(node), title: node.name,
                              latitude: c.latitude, longitude: c.longitude,
                              distanceMeters: distance(c.latitude, c.longitude, server: node.distance)))
        }
        for activity in activities where activity.hasValidCoordinates {
            guard let lat = activity.latitude, let lng = activity.longitude else { continue }
            pins.append(.init(id: "search-activity-" + String(activity.id), payload: .searchActivity(activity),
                              title: activity.name, latitude: lat, longitude: lng,
                              distanceMeters: distance(lat, lng, server: nil)))
        }
        var seen = Set<String>()
        return pins.filter { seen.insert($0.id).inserted }
    }

    static func make(officialRoute detail: OfficialRouteDetail) -> [RoamMapHomePin] {
        detail.nodes.sorted { $0.order < $1.order }.compactMap { node in
            guard let lat = node.latitude, let lng = node.longitude, RoamCoordinate(latitude: lat, longitude: lng) != nil,
                  lat != 0, lng != 0 else { return nil }
            return RoamMapHomePin(id: "official-" + detail.route.id + "-" + node.key, payload: .officialStop(node),
                                  title: node.name, latitude: lat, longitude: lng, distanceMeters: nil)
        }
    }
}

/// Pushes inside the sheet's `NavigationStack` (Maps replaces the sheet content; back returns to the list).
enum RoamMapHomeRoute: Hashable {
    case pin(String)
    case placeDetail(String)
    case event(RoamEventDestination)
    case officialRoutes
    case officialRoute(String)
}

/// The nearby-team page for one team, opened as a sheet over the map.
struct RoamMapHomeTeamSheet: Identifiable, Equatable {
    let teamID: NearbyTeamID
    var id: Int { teamID.rawValue }
}

enum RoamMapHomeLoadPhase: Equatable { case idle, loading, loaded, failed }

/// All UI state of the map home. The map, the sheet and the cards share one instance.
@MainActor @Observable final class RoamMapHomeModel {
    let entry = RoamNearbyEventsEntryState()
    var places: [RoamPlace] = []
    var placesPhase: RoamMapHomeLoadPhase = .idle
    var stops: [RoamRouteNode] = []
    var stopsPhase: RoamMapHomeLoadPhase = .idle
    /// Teams from the entry peek's own team read (`AppSession.roamEntryTeams`), kept for their coordinates.
    var teams: [NearbyTeam] = []
    var officialRoute: OfficialRouteDetail?

    var category: RoamMapHomeCategory = .all
    var query = ""
    var searchActive = false
    var radius = RoamEntryNearbyRoute.radius
    var satellite = false
    var selectedPinID: String?
    var path: [RoamMapHomeRoute] = []
    var detent: PresentationDetent = RoamMapHomeModel.peek
    /// Bumped by 重试; part of every read key.
    var reloadGeneration = 0

    // P-037: the submitted search, shown as pins on this map.
    var searchNodes: [SearchMapCityNode] = []
    var searchActivities: [ActivitySummary] = []
    var searchPhase: RoamMapHomeLoadPhase = .idle
    var searchUnauthorized = false
    /// The keyword the current results belong to (empty: no submitted search).
    var submittedQuery = ""
    /// Bumped when a search lands, so the map fits its pins.
    var searchRevision = 0
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    // Presentations owned by the bottom panel's content.
    var showsLive = false
    var showsCityBoard = false
    var showsPassport = false
    var showsMyTeams = false
    var showsNearbyTeams = false
    var teamSheet: RoamMapHomeTeamSheet?
    /// A full-screen cover hides the map.
    var coversMap: Bool { showsLive || showsCityBoard }

    /// The panel's peek height (search field only) at the default text size, in points. P-035: the panel scales it
    /// with Dynamic Type (`@ScaledMetric` in `RoamMapHomeView`); `peek` is only the detent's identity.
    nonisolated static let peekHeight: CGFloat = 120
    static let peek = PresentationDetent.height(peekHeight)
    /// The panel's detents, smallest first (the Apple Maps set).
    static let detents: [PresentationDetent] = [peek, .medium, .large]
    static let radiusOptions = [1000, 3000, 5000, 10000, 20000]

    /// Entry cards of the current read, or none while loading / failed / signed out.
    func cards(reader: (any RoamEntryNearbyReading)?) -> [RoamEntryActivityCard] {
        guard let reader, case .loaded(let cards) = entry.visibleState(reader: reader) else { return [] }
        return cards
    }

    func allPins(reader: (any RoamEntryNearbyReading)?, center: RoamCoordinate?) -> [RoamMapHomePin] {
        var pins = RoamMapHomePin.make(places: places, stops: stops, cards: cards(reader: reader), teams: teams, center: center)
        if let officialRoute { pins += RoamMapHomePin.make(officialRoute: officialRoute) }
        pins += searchPins(center: center)
        return pins
    }

    /// Pins of the submitted search while its keyword is still in the field.
    func searchPins(center: RoamCoordinate?) -> [RoamMapHomePin] {
        guard hasSubmittedSearch else { return [] }
        return RoamMapHomePin.make(searchNodes: searchNodes, activities: searchActivities, center: center)
    }

    var hasSubmittedSearch: Bool {
        !submittedQuery.isEmpty && submittedQuery == query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// P-037: runs the search map's city search for the field's keyword in the map's area. Same read the pushed
    /// explorer made on appear for that keyword; a newer submit cancels the older one.
    func submitSearch(reader: (any SearchMapReading)?, area: RoamSearchArea?) {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()
        guard !keyword.isEmpty, let reader, reader.isConfigured, let area else { return }
        submittedQuery = keyword
        searchPhase = .loading
        searchUnauthorized = false
        searchTask = Task { [weak self] in
            reader.selectManualArea(area)
            do {
                let result = try await reader.citySearch(CityNodeSearchQuery(filter: GlobalSearchQuery(keyword: keyword), area: area))
                guard !Task.isCancelled, let self, self.submittedQuery == keyword else { return }
                self.searchNodes = result.nodes
                self.searchActivities = result.activities
                self.searchUnauthorized = result.hasUnauthorized
                let bothFailed = result.nodeFailure != nil && result.activityFailure != nil
                self.searchPhase = bothFailed ? .failed : .loaded
                self.searchRevision += 1
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, let self, self.submittedQuery == keyword else { return }
                self.searchNodes = []; self.searchActivities = []
                self.searchUnauthorized = (error as? APIError) == .unauthorized
                self.searchPhase = .failed
            }
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        searchTask = nil
        submittedQuery = ""
        searchNodes = []; searchActivities = []
        searchPhase = .idle; searchUnauthorized = false
    }

    /// Map pins: an open official route shows only its stops (Maps' guide view); otherwise the filter and search apply.
    func mapPins(reader: (any RoamEntryNearbyReading)?, center: RoamCoordinate?) -> [RoamMapHomePin] {
        let pins = allPins(reader: reader, center: center)
        if officialRoute != nil { return pins.filter { $0.monogram != nil } }
        return listPins(from: pins)
    }

    func listPins(from pins: [RoamMapHomePin]) -> [RoamMapHomePin] {
        pins.filter { pin in
            pin.monogram == nil && (category == .all || pin.category == category) && (pin.isSearchResult || pin.matches(query))
        }
        .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
    }

    /// Selecting a marker pushes its card at `.medium`, like Maps.
    func open(pinID: String?) {
        guard let pinID else { return }
        if path.last == .pin(pinID) { return }
        if officialRoute != nil, pinID.hasPrefix("official-") {
            path.append(.pin(pinID))
        } else {
            path = [.pin(pinID)]
        }
        if detent == Self.peek { detent = .medium }
    }

    func push(_ route: RoamMapHomeRoute) {
        path.append(route)
        detent = .large
    }

    /// Keeps the map selection and the route overlay in step with what the sheet shows.
    func pathChanged() {
        if case .pin(let id)? = path.last { if selectedPinID != id { selectedPinID = id } }
        else if path.last == nil || !path.contains(where: { if case .pin = $0 { return true }; return false }) { selectedPinID = nil }
        if !path.contains(where: { if case .officialRoute = $0 { return true }; return false }) { officialRoute = nil }
    }

    func loadEntry(reader: (any RoamEntryNearbyReading)?, teams fetch: ((RoamSearchArea) async -> [NearbyTeam]?)?) async {
        teams = []
        guard let reader else { return }
        let capture: ((RoamSearchArea) async -> [NearbyTeam]?)? = fetch.map { fetch in
            { [weak self] area in
                let result = await fetch(area)
                self?.teams = result ?? []
                return result
            }
        }
        await entry.load(reader: reader, teams: capture)
    }

    func loadPlaces(reader: any RoamReading) async {
        guard reader.isConfigured, reader.searchArea != nil else { places = []; placesPhase = .idle; return }
        placesPhase = .loading
        do {
            let rows = try await reader.roamPlaces(radiusM: radius)
            guard !Task.isCancelled else { return }
            places = rows.filter(\.isSupported); placesPhase = .loaded
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            places = []; placesPhase = .failed
        }
    }

    func loadStops(reader: any RoamReading) async {
        guard reader.isConfigured, reader.searchArea != nil else { stops = []; stopsPhase = .idle; return }
        stopsPhase = .loading
        do {
            let rows = try await reader.roamRouteNodes(radiusM: radius)
            guard !Task.isCancelled else { return }
            stops = rows; stopsPhase = .loaded
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            stops = []; stopsPhase = .failed
        }
    }
}
