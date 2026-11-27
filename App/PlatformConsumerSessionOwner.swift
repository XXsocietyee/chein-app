import SwiftUI

/// Session owner invalidates all active consumers BEFORE credentials/account are replaced.
/// No production factory supplies native drivers. Injection is explicit and optional.
@MainActor final class PlatformConsumerSessionOwner {
    private(set) var scope = UUID()
    private let audioBuilder: (() -> PlatformAudioPlayback)?
    private let mapsBuilder: (() -> PlatformExternalMaps)?
    private var audio: [PlatformAudioPlayback] = []
    private var maps: [PlatformExternalMaps] = []
    init(audio: (() -> PlatformAudioPlayback)? = nil, maps: (() -> PlatformExternalMaps)? = nil) {
        audioBuilder = audio; mapsBuilder = maps
    }
    var audioFactory: (() -> PlatformAudioPlayback)? {
        guard let audioBuilder else { return nil }
        return { [self] in let model = audioBuilder(); audio.append(model); return model }
    }
    var mapsFactory: (() -> PlatformExternalMaps)? {
        guard let mapsBuilder else { return nil }
        return { [self] in let model = mapsBuilder(); maps.append(model); return model }
    }
    func invalidate() {
        audio.forEach { $0.dispose() }; maps.forEach { $0.invalidate() }
        audio.removeAll(); maps.removeAll(); scope = UUID()
    }
}

/// Default read/write denial has no HTTP implementation and cannot reach a backend.
struct CommunityDormantHTTPTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) { throw APIError.notConfigured }
}

@MainActor struct SessionTopicDetailView: View {
    let id: Int
    @ObservedObject var session: AppSession
    var topicReaderOverride: (any TopicReading)? = nil
    /// Club session card (`via=session`): the bar opens the session picker before self-play.
    var preferSession = false
    /// CLB-detail-11: 带票分享 query. Nil for every other entry.
    var ticketSource: TopicClubShareLink? = nil
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @State private var showsGuestLogin = false
    var body: some View {
        Group {
            if let message = session.contentDetailReadAvailability.messageKey {
                ContentUnavailableView("topic.detail", systemImage: "network.slash", description: Text(LocalizedStringKey(message)))
                    .accessibilityIdentifier("topic.detail.configurationUnavailable")
            } else {
                TopicDetailView(id: id, reader: topicReaderOverride ?? session.topicReader, preferSession: preferSession,
                    activityDestination: { AnyView(ActivityDetailView(id: $0, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)) },
                    publicMerchant: session.publicMerchantHomeContext,
                    makeAudio: session.platformConsumers.audioFactory, makeExternalMaps: session.platformConsumers.mapsFactory,
                    publisherDestination: { detail in
                        guard detail.isOwner, let resource = try? PublishedResource(kind: .topic, value: detail.id) else { return AnyView(EmptyView()) }
                        return AnyView(PublisherLifecycleNavigationLink(session: session, resource: resource))
                    },
                    reviewOwner: session.contextualReviews?.coordinator(.topic(id)),
                    guestSignIn: session.account == nil ? { promptGuestSignIn() } : nil,
                    selfPlayDestination: { AnyView(SessionTopicSelfPlayView(session: session, topic: $0, ticketSource: ticketSource)) },
                    ticketWalletDestination: { topicID in
                        AnyView(SessionTicketWalletHost(focusTopicID: topicID).environmentObject(session))
                    },
                    playDestination: { topicID in
                        AnyView(SessionPlayRuntimeView(session: session, destination: .journey(.topic(topicID))))
                    })
                    .id(session.contentDetailRevision)
                    .environment(\.pricingChapterProjectDestination, { topicID in
                        AnyView(MerchantContentDocumentView(service: session.merchantContentService, query: .project(topicID: topicID), focusedTopicID: topicID))
                    })
                    // RTEAMS-1: topic 组队 card reads nearby teams (20 km, signed in) and opens 本场招募.
                    .environment(\.topicTeamsSource, TopicTeamsSource(
                        read: { latitude, longitude in await session.topicNearbyTeams(latitude: latitude, longitude: longitude) },
                        lobby: { ownerType, ownerID, scope in
                            // P-061: the native r2 lobby mounts directly; the legacy wrapper is only the flag-off path.
                            if NativeR2Flags.cityOrientation {
                                return AnyView(CityOrientationTeamLobbyView(ownerType: ownerType, ownerID: ownerID, scopeTitle: scope)
                                    .environmentObject(session))
                            }
                            return AnyView(OrientLobbyTeamsView(ownerType: ownerType, ownerID: ownerID, scopeTitle: scope).environmentObject(session))
                        }))
                    .environment(\.topicLineupClubDestination, { clubID in
                        AnyView(MPReviewedPageScreen(page: "pages/club/detail/index", query: ["id": String(clubID)]).environmentObject(session))
                    })
                    .environment(\.topicLineupMerchantDestination, { memberID in
                        guard let owner = PublicMerchantOwnerID(memberID) else { return AnyView(EmptyView()) }
                        return AnyView(PublicMerchantHomeView(target: .ownerMemberID(owner), context: session.publicMerchantHomeContext))
                    })
                    // R11-PC-B-1: 游玩记录 card 查看战报 / 再玩一局 (MP utils/theme-records.js:35-42, 127-161).
                    .environment(\.topicThemeRecordsSession, session)
                    // R7-PC-B1-13: a picked session opens checkout with the topic-page ticket chosen (MP index.js:1312-1351).
                    .environment(\.topicSessionRegistrationDestination, { activityID, ticketName in
                        AnyView(ActivityDetailView(id: activityID, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true,
                                                   opensRegistrationOnLoad: true, registrationTicketName: ticketName))
                    })
                    // PC-B-4-3 / PC-B-1-3 (X1): every entry gets the owner pricing page and the play runtime client,
                    // not only the topic browser sheet (SessionTopicBrowserView).
                    .environment(\.topicPricingDestination, session.publisherLifecycleContext.map { context -> (Int) -> AnyView in
                        { topicID in AnyView(PublisherPricingView(topicID: topicID, client: context.client, coordinator: context.coordinator)) }
                    })
                    .environment(\.topicEditorDestination) { topicID, scope in
                        var query = ["id": String(topicID)]
                        if let scope { query["scope"] = scope }
                        return AnyView(MPReviewedPageScreen(page: "pages/publish/fabu/index", query: query).environmentObject(session))
                    }
                    .environment(\.playRuntimeTopicClient, PlayRuntimeGapBridge.topicClient(session: session))
                    .environment(\.playOrientSafety, PlayRuntimeGapBridge.orientSafety(session: session))
                    .environment(\.topicFavoriteHostFactory, { session.makeTopicFavoriteHost() })
            }
        }
        .cySheet(isPresented: $showsGuestLogin) {
            Group { LoginView(intent: .player).environmentObject(session) }.presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .onChange(of: session.account == nil) { _, signedOut in if !signedOut { showsGuestLogin = false } }
    }
    /// 收藏, buy, and review. The public info-to-user read stays open.
    private func promptGuestSignIn() {
        if rootTabSwitch.isAvailable { rootTabSwitch(.mine) } else { showsGuestLogin = true }
    }
}

#if DEBUG
@MainActor struct ClubCommunityFixtureRoot: View {
    private let context = try? ClubCommunityFixture.context()
    var body: some View {
        NavigationStack {
            if let context { ClubCommunityFeedView(context: context, identity: ClubCommunityFixture.identity, clubID: 10) }
            else { Text("club.community.loadError") }
        }
    }
}
#endif
