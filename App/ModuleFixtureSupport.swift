#if DEBUG
import SwiftUI

enum ModuleFixture: String {
    case playDirector, playPrefab, playPrefabBoot
    case ownedOrderHistory
    case signedInContentDetail
    case publicTemplateDetail, publicPlayTemplate
    case templateDetailParity, templateTabStaff, playOpening, playFinishRoute, playCircleLink, playThemeRecords, playEntryCode, playBackpack, playTeamBackpack, sessionTeamCreate
    case privateHome
    case cityGame, homeReturn
    case nativeEnrollment
    case nativePlatform
    case playBranchHistory
    case playExperience, compareGame, letterPoolGame
    case journeyContent
    case squareWorkspace = "square-workspace"
    case objectCards
    case socialAccount
    case searchMap
    case teams
    case settingsNative
    case presentationPatterns
    case homeFeed = "home-feed"
    case merchantCityNPC = "merchant-city-npc"
    case miniCrop = "mini-crop"
    case ticketWallet, square, cooperation, accountCollections, creatorContent, growthCenter, officialEvents, projectEdit
    case discovery, profile, messaging, roam, participants, play, composer, topic, localization
    case appsecChein
    static var selected: Self? {
        let args=ProcessInfo.processInfo.arguments
        guard let i=args.firstIndex(of:"--uitesting-module"),args.indices.contains(i+1) else { return nil }
        return Self(rawValue:args[i+1])
    }
}

@MainActor
struct ModuleFixtureRootView: View {
    let module: ModuleFixture
    @State private var discovery=DiscoveryFixtureReader()
    @State private var roam=RoamFixtureReader()
    var body: some View {
        VStack(spacing:0) {
            // Keep fixture chrome compact while the actual content retains accessibility5.
            Group {
                if ProcessInfo.processInfo.arguments.contains("--uitesting-max-text") {
                    Label("activity.fixtureNotice", systemImage: "testtube.2").labelStyle(.iconOnly)
                } else { Text("activity.fixtureNotice") }
            }.cyText(.meta, weight: .bold).padding(8)
                .frame(maxWidth:.infinity).background(.yellow.opacity(0.2))
                .accessibilityIdentifier("module.fixture.notice")
                .modifier(AccessibilityFixtureEnvironmentValue())
            switch module {
            case .playDirector: PlayDirectorPrefabFixtureHostView(scenario: "director")
            case .playPrefab: PlayDirectorPrefabFixtureHostView(scenario: "prefab")
            case .playPrefabBoot: PlayDirectorPrefabFixtureHostView(scenario: "prefabBoot")
            case .ownedOrderHistory: OwnedOrderFixtureHost()
            case .signedInContentDetail: SignedInContentDetailFixtureHost()
            case .publicTemplateDetail: PublicTemplateDetailFixtureHost()
            case .publicPlayTemplate: PublicPlayTemplateFixtureHost()
            case .templateDetailParity: TemplateDetailParityFixtureHost()
            case .templateTabStaff: TemplateTabStaffFixtureHost()
            case .playOpening: PlayOpeningFixtureHost()
            case .playFinishRoute: PlayFinishRouteFixtureHost()
            case .playCircleLink: PlayCircleLegacyLinkFixtureHost()
            case .playThemeRecords: PlayThemeRecordsFixtureHost()
            case .playEntryCode: PlayEntryCodeFixtureHost()
            case .playBackpack: PlayThemeBackpackFixtureHost()
            case .playTeamBackpack: PlayTeamBackpackFixtureHost()
            case .sessionTeamCreate: SessionTeamCreateFixtureHost()
            case .privateHome: PrivateHomeFixtureHost()
            case .cityGame: CityGameFixtureHost()
            case .homeReturn: HomeReturnFixtureHost()
            case .nativeEnrollment: NativeEnrollmentFixtureHost()
            case .nativePlatform: NativePlatformFixtureHost()
            case .playBranchHistory: PlayBranchHistoryFixtureHost()
            case .playExperience: PlayExperienceFixtureHostView()
            case .compareGame: PlayCompareFixtureHost()
            case .letterPoolGame: LetterPoolGameFixtureHost()
            case .journeyContent: JourneyContentFixtureHostView()
            case .squareWorkspace: SquareWorkspaceFixtureHost()
            case .objectCards: ObjectCardFixtureHostView()
            case .socialAccount: SocialAccountFixtureHostView()
            case .searchMap: SearchMapFixtureHostView()
            case .teams: TeamFixtureHostView()
            case .settingsNative: SettingsFixtureHostView()
            case .presentationPatterns: NativePresentationFixtureHost()
            case .homeFeed: HomeFeedFixtureHostView()
            case .merchantCityNPC: MerchantCityNPCParityFixtureHost()
            case .ticketWallet: TicketWalletFixtureHostView()
            case .square: SquareFixtureHostView()
            case .officialEvents: OfficialFixtureHostView()
            case .projectEdit:
                if ProcessInfo.processInfo.arguments.contains("--project-owned-flow") { ProjectOwnedContentFixtureHost() }
                else { ProjectEditFixtureHostView() }
            case .growthCenter: GrowthCenterFixtureHostView()
            case .creatorContent: CreatorContentFixtureHostView()
            case .miniCrop: MiniCropFixtureHostView()
            case .accountCollections: AccountCollectionFixtureHostView()
            case .cooperation: CooperationFixtureHostView()
            case .discovery: DiscoveryHomeView(reader:discovery)
            case .profile: ProfileFixtureHostView()
            case .messaging: MessagingFixtureHostView()
            case .roam: RoamBrowserView(reader:roam)
            case .participants: ParticipantFixtureHostView()
            case .play: PlayFixtureHostView()
            case .composer: MessageActionFixtureHost()
            case .topic: TopicFixtureHostView()
            case .localization: ComputedLocalizationFixtureView()
            case .appsecChein: AppSecCheinLinkFixtureHost()
            }
        }
        .modifier(AccessibilityFixtureOptions())
    }
}

/// Registered letter-pool board. Pool trim and stage analytics stay off; this host only shows the kit.
@MainActor private struct LetterPoolGameFixtureHost: View {
    private static let segmentJSON = #"{"length":5,"blankCount":3,"caseSensitive":false,"solved":false,"display":"__-_D","inputMode":"pool","pool":["C","X","A","Y","B","A"],"poolRemoved":0,"slots":[{"i":0,"kind":"BLANK"},{"i":1,"kind":"BLANK"},{"i":2,"ch":"-","kind":"SEPARATOR"},{"i":3,"kind":"BLANK"},{"i":4,"ch":"D","kind":"PREFILLED"}]}"#
    private var segment: PlayWireValue {
        (try? JSONDecoder().decode(PlayWireValue.self, from: Data(Self.segmentJSON.utf8))) ?? .null
    }
    var body: some View {
        NavigationStack {
            PlayKitHangmanView(projection: PlayKitHangmanProjection(segment: segment), segment: segment)
                .environment(\.playGameStage, PlayGameStage(ordinal: 1, stationName: nil, chapterTitle: nil, lead: nil))
                .navigationTitle(Text(verbatim: "letterPoolGame"))
                .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("letterPoolGame.host")
    }
}
#endif
