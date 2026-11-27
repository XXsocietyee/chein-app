#if DEBUG
import SwiftUI

/// E1 (player discovery + commerce) design fixtures. They mount the REAL views on the existing offline fixture
/// readers (synthetic data, clearly labelled) under the player (dark) role theme.
/// `--design-fixture e1-topics | e1-topic-detail | e1-activities | e1-activity-detail | e1-official | e1-official-detail
///  | e1-official-inbox | e1-registration | e1-participants | e1-templates ...`
/// Scenario launch arguments of the underlying hosts (for example `--uitesting-topic-scenario empty`) pass through.
struct E1Fixture: View {
    enum Screen {
        case topics, topicDetail, activities, activityDetail, activityDetailError, activityPeople
        case official, officialDetail, officialInbox
        case registration(RegistrationFixtureScenario)
        case participants(ParticipantFixtureScenario)
        case discovery, routes, routesEmpty, routeDetail
    }
    let screen: Screen
    var body: some View {
        host
            .themeDomain(.player)
            .cyDomainPageBackground()
            .themeDomain(.player)
    }

    @ViewBuilder private var host: some View {
        switch screen {
        case .topics: TopicFixtureHostView()
        case .topicDetail: NavigationStack { TopicDetailView(id: 7, reader: TopicFixtureReader(scenario: .reviews)) }
        case .activities: ActivityBrowserView(reader: ActivityFixtureReader(scenario: .pagination))
        case .activityDetail:
            NavigationStack { ActivityDetailView(id: 101, reader: ActivityFixtureReader(scenario: .reviews), registrationEnabled: true) }
                .environment(\.e1ActivityHeroFixtureCover, MPAsset.BannerCover.feNight)
        case .activityDetailError: NavigationStack { ActivityDetailView(id: 101, reader: ActivityFixtureReader(scenario: .retry), registrationEnabled: true) }
        case .activityPeople: NavigationStack { ActivityDetailView(id: 101, reader: ActivityFixtureReader(scenario: .people)) }
        case .official, .officialDetail, .officialInbox: OfficialFixtureHostView()
        case .registration(let s): RegistrationFixtureHostView(scenario: s)
        case .participants(let s): ParticipantFixtureHostView(scenario: s)
        case .routes: NavigationStack { OfficialRouteListView(reader: E1Fixture.routeReader) }
        case .routesEmpty: NavigationStack { OfficialRouteListView(reader: E1Fixture.emptyRouteReader) }
        case .routeDetail: NavigationStack { OfficialRouteDetailView(reader: E1Fixture.routeReader, routeID: "1") }
        case .discovery: DiscoveryHomeView(reader: DiscoveryFixtureReader(), topicBrowsingEnabled: true)
        }
    }

    /// Labelled synthetic official routes (offline example data, no photos: generated cover art).
    static var routeReader: OfficialRouteReader {
        let routes = [
            OfficialRoute(id: "1", name: "Old Town Lantern Walk (offline example)", city: "Beijing", previewImage: "", distanceKm: 3.2, totalMinutes: 95),
            OfficialRoute(id: "2", name: "Riverside Sunrise Trail (offline example)", city: "Shanghai", previewImage: "", distanceKm: 5.8, totalMinutes: 130),
            OfficialRoute(id: "3", name: "Hutong Food and Photo Loop (offline example)", city: "Beijing", previewImage: "", distanceKm: 2.4, totalMinutes: 75),
            OfficialRoute(id: "4", name: "Temple Hill Panorama (offline example)", city: "Hangzhou", previewImage: "", distanceKm: 7.1, totalMinutes: 180),
        ]
        let nodes = [
            OfficialRouteNode(key: "a", order: 1, name: "Lantern Square", address: "1 Lantern Road", imageURL: "", stayMinutes: 15, latitude: 39.94, longitude: 116.40),
            OfficialRouteNode(key: "b", order: 2, name: "Courtyard Tea House", address: "9 Courtyard Lane", imageURL: "", stayMinutes: 30, latitude: 39.941, longitude: 116.402),
            OfficialRouteNode(key: "c", order: 3, name: "Drum Tower Steps", address: "Drum Tower East Street", imageURL: "", stayMinutes: 20, latitude: nil, longitude: nil),
            OfficialRouteNode(key: "d", order: 4, name: "Night Market Finale", address: "Dumpling Street", imageURL: "", stayMinutes: 0, latitude: 39.943, longitude: 116.406),
        ]
        return OfficialRouteReader(list: { routes }, detail: { _ in OfficialRouteDetail(route: routes[0], nodes: nodes) })
    }

    /// Offline empty shelf. No network call; the list renders the empty state.
    static var emptyRouteReader: OfficialRouteReader {
        OfficialRouteReader(list: { [] }, detail: { _ in throw OfficialRouteReader.Failure.notFound })
    }

    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "e1-topics": return AnyView(E1Fixture(screen: .topics))
        case "e1-topic-detail": return AnyView(E1Fixture(screen: .topicDetail))
        case "e1-activities": return AnyView(E1Fixture(screen: .activities))
        case "e1-activity-detail", "rep3-activity-detail": return AnyView(E1Fixture(screen: .activityDetail))
        case "rep3-activity-detail-error": return AnyView(E1Fixture(screen: .activityDetailError))
        case "e1-official": return AnyView(E1Fixture(screen: .official))
        case "e1-registration": return AnyView(E1Fixture(screen: .registration(.standard)))
        case "e1-registration-soldout": return AnyView(E1Fixture(screen: .registration(.soldOut)))
        case "e1-participants": return AnyView(E1Fixture(screen: .participants(.success)))
        case "e1-participants-empty": return AnyView(E1Fixture(screen: .participants(.empty)))
        case "e1-routes": return AnyView(E1Fixture(screen: .routes))
        case "e1-routes-empty": return AnyView(E1Fixture(screen: .routesEmpty))
        case "e1-official-empty": return AnyView(NavigationStack { OfficialEventsBrowserView(reader: OfficialFixtureReader(scenario: .empty)) }.themeDomain(.player).cyDomainPageBackground())
        case "e1-route-detail": return AnyView(E1Fixture(screen: .routeDetail))
        case "e1-discovery": return AnyView(E1Fixture(screen: .discovery))
        case "e1-motion-hero": return AnyView(E1MotionLabFixture(mode: .hero))
        case "e1-motion-list": return AnyView(E1MotionLabFixture(mode: .list))
        case "e1-motion-scroll": return AnyView(E1MotionLabFixture(mode: .scroll))
        case "e1-bundle-shelf": return AnyView(E1BundleFixture(.shelf))
        case "e1-bundle-shelf-empty": return AnyView(E1BundleFixture(.shelfEmpty))
        case "e1-bundle-shelf-error": return AnyView(E1BundleFixture(.shelfError))
        case "e1-bundle-detail": return AnyView(E1BundleFixture(.detail))
        case "e1-bundle-detail-off": return AnyView(E1BundleFixture(.detailOff))
        case "e1-ticket-holder": return AnyView(E1TicketHolderFixture(kind: .wallet))
        case "e1-ticket-holder-valid": return AnyView(E1TicketHolderFixture(kind: .valid))
        case "e1-ticket-holder-pending": return AnyView(E1TicketHolderFixture(kind: .pending))
        case "e1-ticket-holder-used": return AnyView(E1TicketHolderFixture(kind: .used))
        case "e1-ticket-holder-expired": return AnyView(E1TicketHolderFixture(kind: .expired))
        case "e1-ticket-holder-present": return AnyView(E1TicketHolderFixture(kind: .present))
        case "ui-pass-card": return AnyView(PassCardHostFixture())
        case "ui-pass-card-sheet": return AnyView(PassCardFixture(kind: .valid))
        case "ui-pass-card-verify": return AnyView(PassCardVerifyFixture())
        case "ui-pass-card-pending": return AnyView(PassCardFixture(kind: .pending))
        case "ui-pass-card-used": return AnyView(PassCardFixture(kind: .used))
        case "ui-pass-card-expired": return AnyView(PassCardFixture(kind: .expired))
        case "ui-pass-card-empty": return AnyView(PassCardFixture(kind: .empty))
        case "ui-pass-card-error": return AnyView(PassCardFixture(kind: .error))
        default: return nil
        }
    }
}
#endif
