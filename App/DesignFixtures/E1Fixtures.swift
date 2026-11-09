#if DEBUG
import SwiftUI

/// E1 (player discovery + commerce) design fixtures. They mount the REAL views on the existing offline fixture
/// readers (synthetic data, clearly labelled) under the player (dark) role theme.
/// `--design-fixture e1-topics | e1-topic-detail | e1-activities | e1-activity-detail | e1-official | e1-official-detail
///  | e1-official-inbox | e1-registration | e1-participants | e1-templates ...`
/// Scenario launch arguments of the underlying hosts (for example `--uitesting-topic-scenario empty`) pass through.
struct E1Fixture: View {
    enum Screen {
        case topics, topicDetail, activities, activityDetail, activityPeople
        case official, officialDetail, officialInbox
        case registration(RegistrationFixtureScenario)
        case participants(ParticipantFixtureScenario)
        case discovery
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
        case .activityDetail: NavigationStack { ActivityDetailView(id: 101, reader: ActivityFixtureReader(scenario: .reviews)) }
        case .activityPeople: NavigationStack { ActivityDetailView(id: 101, reader: ActivityFixtureReader(scenario: .people)) }
        case .official, .officialDetail, .officialInbox: OfficialFixtureHostView()
        case .registration(let s): RegistrationFixtureHostView(scenario: s)
        case .participants(let s): ParticipantFixtureHostView(scenario: s)
        case .discovery: DiscoveryHomeView(reader: DiscoveryFixtureReader(), topicBrowsingEnabled: true)
        }
    }

    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "e1-topics": return AnyView(E1Fixture(screen: .topics))
        case "e1-topic-detail": return AnyView(E1Fixture(screen: .topicDetail))
        case "e1-activities": return AnyView(E1Fixture(screen: .activities))
        case "e1-activity-detail": return AnyView(E1Fixture(screen: .activityDetail))
        case "e1-official": return AnyView(E1Fixture(screen: .official))
        case "e1-registration": return AnyView(E1Fixture(screen: .registration(.standard)))
        case "e1-registration-soldout": return AnyView(E1Fixture(screen: .registration(.soldOut)))
        case "e1-participants": return AnyView(E1Fixture(screen: .participants(.success)))
        case "e1-participants-empty": return AnyView(E1Fixture(screen: .participants(.empty)))
        case "e1-discovery": return AnyView(E1Fixture(screen: .discovery))
        default: return nil
        }
    }
}
#endif
