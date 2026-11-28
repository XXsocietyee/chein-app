import SwiftUI
import UIKit

/// Observes the actual AppSession publisher so logout/relogin tears down all displayed
/// journey data even while a nested runtime destination is visible. Factories remain off.
@MainActor struct SessionPlayRuntimeView: View {
    enum Destination { case journey(PlaySessionScope), director(Int), prefab(PlaySessionScope) }
    @ObservedObject var session: AppSession
    let destination: Destination
    /// PLAYC-r7-1: MP pages/play `?inviteCode=` (old circle links and shared play links). Consumed once on open through
    /// `api/circle-theme/session/join` (PlayCircleCoordinator.open), as MP `_consumeInviteCode` does before its first read.
    var inviteCode: String? = nil
    /// PLAYC-r7-1: MP `?registrationId=` (ticket-wallet links): the play page can show this ticket's 入场码.
    var registrationID: Int? = nil
    @State private var consumedInviteCode = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.playThemeAuxiliaryProvider) private var auxiliaryProvider
    @State private var auxiliaryStore = PlayThemeAuxiliaryStore()
    @State private var finishRoute: PlayFinishRouteRecommendationCoordinator?
    @State private var teamBackpack: PlayTeamBackpackCoordinator?
    var body: some View {
        Group {
            switch destination {
            case .journey(let scope):
                VStack(spacing: 0) {
                    if let recovery=session.cityOriginalRecovery(scope:scope) {
                        CityOrientationOriginalRecoveryView(model:recovery)
                    }
                if let model = session.playExperience(for: scope) {
                    let auxiliary = auxiliaryStore.models(revision: session.sessionRevision, scope: scope, topicID: model.snapshot?.result.topicID,
                        provider: auxiliaryProvider ?? session.playThemeAuxiliaryProvider)
                    PlayExperienceView(model: model,
                        deviceModel: { nodeID in session.playDevice(scope: scope, nodeID: nodeID, lifetime: model.makeInteractionLifetime()) },
                        advancedModel: { nodeID in session.playAdvanced(scope: scope, nodeID: nodeID, topicID: model.snapshot?.result.topicID, lifetime: model.makeInteractionLifetime()) },
                        motionModel: { nodeID, configuration in session.playStillness(scope: scope, nodeID: nodeID, configuration: configuration, lifetime: model.makeInteractionLifetime()) },
                        preferenceModel: { nodeID in session.playPreference(scope: scope, nodeID: nodeID, lifetime: model.makeInteractionLifetime()) },
                        summaryModel: { session.playOperatingSummary(topicID: $0) },
                        playerModel: session.playPlayer(scope: scope),
                        circleModel: session.productionPlayCircle(topicID: model.snapshot?.result.topicID) ?? session.playCircle(topicID: model.snapshot?.result.topicID),
                        finishRouteModel: finishRoute,
                        themeRecordsModel: auxiliary.records,
                        backpackModel: auxiliary.backpack,
                        teamBackpackModel: teamBackpack,
                        entryCode: registrationID.flatMap { $0 > 0 ? PlayEntryCodeContext(registrationID: $0, openTicketWallet: nil) : nil },
                        cityGameModel: session.playCityGame,
                        prefabModel: session.playPrefab(scope: scope),
                        journeyModel: { session.journeyCheck(scope: scope, topicID: model.snapshot?.result.topicID, nodeID: $0) },
                        ambientModel: session.journeyAmbient(scope: scope),
                        narrativeModel: { session.journeyNarrative(scope: scope, topicID: model.snapshot?.result.topicID, query: $0) },
                        narrativeImageReader: session.journeyNarrativeImageReader, shopNPCModel: { session.shopNPCNodeHost(scope: scope, nodeID: $0, runtime: model) },
                        invalidateShopNPC: session.invalidateShopNPCConversations,
                        storeDayModel: { nodeID in session.playStoreDay(scope: scope, nodeID: nodeID, evidence: PlayStoreDayDeviceEvidence(makeDevice: {
                            session.playDevice(scope: scope, nodeID: nodeID, lifetime: model.makeInteractionLifetime()) })) },
                        teamPoolModel: { session.teamPoolHint(topicID: model.snapshot?.result.topicID, nodeID: $0, runTeamID: model.snapshot?.result.teamID) },
                        mediaScope: session.platformConsumers.scope,
                        makeAudio: session.platformConsumers.audioFactory, makeExternalMaps: session.platformConsumers.mapsFactory,
                        approvedArtworkHosts: session.playKitArtworkHosts, makeSensorProvider: session.playKitSensorFactory,
                        spatialApproval: session.playKitSpatialApproval,
                        rewardCollectionDestination: { target in
                            AnyView(PlayRewardBadgeCollectionView(target: target, reader: session.profileReader,
                                growthReader: session.growthCenterReader, isCurrent: { model.identity != nil }).id(session.profileReader.identity))
                        })
                        .environment(\.playThemeReplay, PlayThemeReplayBridge.binding(session: session, scope: scope, topicID: model.snapshot?.result.topicID))
                        .environment(\.inGameChannelHost, session.inGameChannelHost)
                        .task(id: session.cityPlayerReadIdentity) { await session.loadCityGamePlayRead() }
                        .environment(\.playRuntimeGap, PlayRuntimeGapBridge.binding(session: session, scope: scope, topicID: model.snapshot?.result.topicID))
                        .environment(\.playToolsSessionStatsLoader, PlayToolsSessionStatsRead.make(session: session))
                        .environment(\.playOrientBoardLoader, OrientScoreBoardRead.make(session: session))
                        .task(id: session.sessionRevision) { await mountTeamAndFinish(scope: scope, model: model) }
                        .task(id: session.sessionRevision) { await consumeInviteCode(scope: scope) }
                } else { CYEmptyState(systemImage: "gamecontroller", "playx.disabled") }
                }
            case .director(let activityID):
                if let model = session.playDirector(activityID: activityID) { PlayDirectorView(model: model) }
                else { CYEmptyState(systemImage: "gamecontroller", "playx.disabled") }
            case .prefab(let scope):
                if let model = session.playPrefab(scope: scope) { PlayPrefabRuntimeView(model: model) }
                else { CYEmptyState(systemImage: "gamecontroller", "playx.disabled") }
            }
        }.id(session.sessionRevision).privacySensitive()
        .environment(\.nativePlatformRuntime, session.nativePlatformRuntime)
        .task(id: session.sessionRevision) { await session.nativePlatformRuntime?.reconcileOwnedRequests() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in session.nativePlatformRuntime?.clockChanged() }
        .cySheet(isPresented: Binding(get: { session.playNativeDeviceProvider.showingCamera }, set: { if !$0 { session.playNativeDeviceProvider.cancel() } })) {
            PlayNativeCameraSheet(provider: session.playNativeDeviceProvider).ignoresSafeArea()
        }
        .cySheet(isPresented: Binding(get: { session.playNativeDeviceProvider.showingLibraryPicker }, set: { if !$0 { session.playNativeDeviceProvider.cancel() } })) {
            PlayKitNativePhotoLibrarySheet(provider: session.playNativeDeviceProvider)
        }
        .onChange(of: session.sessionRevision) { _, _ in session.playNativeDeviceProvider.cancel() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { session.nativePlatformRuntime?.suspendMotion() }; if phase == .active { Task { await session.nativePlatformRuntime?.reconcileOwnedRequests() } }; if phase == .background || (phase != .active && !session.playNativeDeviceProvider.authorizationInFlight) { session.playNativeDeviceProvider.cancel() } }
        .onDisappear { session.playNativeDeviceProvider.cancel() }
    }

    /// PLAYC-r7-1: one join per opened link. The coordinator keeps its own guards (signed-in owner, offers read,
    /// no open card, write grant); a refused join leaves the page as a normal topic play.
    private func consumeInviteCode(scope: PlaySessionScope) async {
        guard !consumedInviteCode, let code = inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty,
              case .topic(let topicID) = scope,
              let circle = session.productionPlayCircle(topicID: topicID) ?? session.playCircle(topicID: topicID) else { return }
        consumedInviteCode = true
        await circle.loadOffers()
        await circle.open(inviteCode: code)
    }

    private func mountTeamAndFinish(scope: PlaySessionScope, model: PlayExperienceCoordinator) async {
        let activityID: Int?
        if case .activity(let id) = scope {
            activityID = id
            teamBackpack = session.playTeamBackpack(activityID: id)
        } else {
            activityID = nil
            teamBackpack = nil
        }
        let enabled = await session.finishNearbyRouteEnabled()
        guard !Task.isCancelled else { return }
        let topicID = model.snapshot?.result.topicID
        let coordinator = PlayFinishRouteRecommendationCoordinator(featureEnabled: enabled, reader: session.playFinishRouteReader(),
            currentActivityID: activityID, currentTopicID: topicID)
        finishRoute = coordinator
        guard model.snapshot?.availability == .completed, let snapshot = model.snapshot else { return }
        let origin = PlayFinishOrigin.resolve(snapshot.visibleNodes.map { node in
            (done: snapshot.isDone(node), latitude: node.latitude, longitude: node.longitude, doneAt: nil as Double?)
        })
        await coordinator.show(origin: origin)
    }
}
