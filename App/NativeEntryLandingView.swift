import SwiftUI

/// No tracking provider is approved in the current app. Never simulate successful cleanup.
@MainActor final class DormantComplianceRoamEffects: ComplianceRoamEffects {
    func stopTracking() async throws { throw ComplianceFailure.unavailable }
    func clearMapPrivacy() async throws { throw ComplianceFailure.unavailable }
    func invalidateMapPrivacyCaches() {}
}

@MainActor struct SessionDoorInviterView: View {
    @ObservedObject var session: AppSession
    var body: some View {
        Group {
            if let queue = session.doorReferralQueue {
                DoorInviterSheet(session: session.doorReferralSession, queue: queue, enabled: true)
            } else { ContentUnavailableView("door.disabled", systemImage: "lock") }
        }.id(session.sessionRevision)
    }
}

/// Lives outside account-keyed tabs so a guest invitation survives the existing login overlay.
@MainActor struct NativeEntryLandingView: View {
    let entry: NativeEntryPresentation
    @ObservedObject var session: AppSession
    let goHome: () -> Void
    @State private var destination: DoorDestination?
    @State private var failure: String?
    @State private var showsLogin = false
    @StateObject private var dirtyTracker = DeepLinkDirtyTracker()
    @State private var showsDiscardModal = false
    @Environment(\.locale) private var locale
    private let discardPrompt = DeepLinkSceneDiscardPrompt()
    var body: some View {
        Group {
            NavigationStack {
                Group {
                    switch entry.intent {
                    case .routeError(let failure):
                        NativeRouteErrorView(failure: failure, goHome: { session.dismissNativeEntry(); goHome() })
                    case .badge(let parameters):
                        ObjectBadgeShowroomView(parameters: parameters, expectedScope: entry.id,
                            currentScope: { session.nativeEntry?.id ?? UUID() },
                            media: session.makeObjectCardImageLoader(),
                            glbHosts: session.playKitArtworkHosts)
                    case .teamInvitation(let route):
                        if session.account == nil {
                            ContentUnavailableView {
                                Label { Text("nativeNav.team.signInDetail") } icon: { Image(systemName: "person.crop.circle.badge.questionmark") }
                            } actions: {
                                Button { showsLogin = true } label: { Text("team.signIn") }
                                    .buttonStyle(.borderedProminent).controlSize(.large)
                            }
                        } else {
                            SessionTeamDetailView(lookup: .invitation(route.code)).id(session.teamViewIdentity)
                        }
                    case .publicMerchant(let target):
                        PublicMerchantHomeView(target: target, context: session.publicMerchantHomeContext).id(session.sessionRevision)
                    case .content(let target):
                        AuditedContentEntry(target: target, session: session, goHome: goHome)
                    case .miniProgramPage(let link):
                        MPParityPageEntry(link: link, session: session, goHome: goHome)
                    case .merchantInvitation(let route):
                        MerchantOperatorInvitationLandingView(invitation: route.invitation,
                            reader: session.merchantEngagementReader, journal: session.merchantBusinessJournal,
                            exportRecovery: session.merchantExportRecovery, requestSignIn: { showsLogin = true })
                            .id(session.sessionRevision)
                    case .door:
                        doorDestination
                            .task(id: session.doorReferralSession) {
                                guard session.doorReferralSession.restored else { return }
                                guard let model = session.doorEntryCoordinator else { destination = .home; failure = "door.disabled"; return }
                                // AppSession received this intent once. Never re-capture/refire after account changes.
                                await model.resolve()
                                guard !Task.isCancelled else { return }
                                destination = model.destination; failure = model.failure
                            }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("door.close") {
                            switch DeepLinkSceneExitPolicy.evaluate(isDirty: dirtyTracker.isDirty) {
                            case .closeImmediately:
                                session.dismissNativeEntry()
                            case .confirmDiscard:
                                showsDiscardModal = true
                            }
                        }
                        // The page below may set a light domain tint (merchant, topic editor); the label then drew white on
                        // the light glass pill and vanished (combined-r5 verify: 核销记录, 发布活动 links).
                        .tint(.primary)
                    }
                }
                .cySheet(isPresented: $showsLogin) {
                    if case .teamInvitation = entry.intent { LoginView(intent: .player) }
                    else { LoginView(intent: .merchant) }
                }
            }
        }
        .alert(MemberPopupCopy.text(discardPrompt.title, "Discard current changes?", locale: locale), isPresented: $showsDiscardModal) {
            Button(MemberPopupCopy.text(discardPrompt.cancelTitle, "Keep editing", locale: locale), role: .cancel) { showsDiscardModal = false }
                .accessibilityIdentifier("deepLink.discard.cancel")
            Button(MemberPopupCopy.text(discardPrompt.confirmTitle, "Discard & close", locale: locale), role: .destructive) {
                showsDiscardModal = false
                dirtyTracker.isDirty = false
                session.dismissNativeEntry()
            }
            .accessibilityIdentifier("deepLink.discard.confirm")
        } message: {
            Text(verbatim: MemberPopupCopy.text(discardPrompt.message, "Unsaved edits will be lost if you close.", locale: locale))
        }
        .environment(\.deepLinkDirtyTracker, dirtyTracker)
        .environment(\.memberPopupActions, session.memberPopupActions())
        .environment(\.popupCloseActions, session.popupCloseActions())
        .interactiveDismissDisabled(dirtyTracker.isDirty)
        .onDisappear {
            dirtyTracker.isDirty = false
            session.doorEntryCoordinator?.cancel()
        }
    }
    @ViewBuilder private var doorDestination: some View {
        switch destination {
        case .activityPlay(let activityID, _):
            SessionPlayRuntimeView(session: session, destination: .journey(.activity(activityID)))
        case .topicSelfPlay(let topicID):
            SessionPlayRuntimeView(session: session, destination: .journey(.topic(topicID)))
        case .topicDetail(let topicID):
            SessionTopicDetailView(id: topicID, session: session)
        case .home:
            ContentUnavailableView {
                Image(systemName: "house").accessibilityHidden(true)
            } description: {
                if let failure {
                    if ["door.disabled", "door.unavailable"].contains(failure) { Text(LocalizedStringKey(failure)) }
                    else { Text(verbatim: failure) }
                }
            } actions: {
                Button { session.dismissNativeEntry(); goHome() } label: { Text("homeFeed.title") }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
        case nil:
            ProgressView("door.resolving").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}


/// Topic keeps the home-feed topic screen. Every other classified kind opens the mini-program page for that id.
@MainActor private struct AuditedContentEntry: View {
    let target: NativeContentTarget
    @ObservedObject var session: AppSession
    let goHome: () -> Void
    var body: some View {
        if target.kind == .topic {
            SessionTopicDetailView(id: target.id, session: session)
        } else if let route = MPParityRoute(miniProgramPath: target.inboundPage, query: target.inboundQuery) {
            MPParityDestination(route: route)
                .environmentObject(session)
                .modifier(MPParityPassEnvironment(session: session))
        } else {
            NativeRouteErrorView(failure: .unsupported, goHome: { session.dismissNativeEntry(); goHome() })
        }
    }
}

@MainActor struct SessionMerchantMarketingDestination: View {
    @ObservedObject var session: AppSession
    let destination: MerchantInsightDestination
    var body: some View {
        Group {
            switch destination {
            case .topicCooperation: CooperationFlowWorkbench(reader: session.cooperationFlowReader)
            case .decoration: MerchantOperationsDocumentView(reader: session.merchantOperationsReader, destination: .decor, imageHost: session.retainedMerchantImages)
            case .content: ProjectEditView(coordinator: session.projectEditor(product: .city), sessionRevision: session.sessionRevision, publisherClient: session.publisherLifecycleContext?.client, publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) }).id(session.projectEditorContextID)
            case .recommendation(let route):
                if session.merchantOperationsReader.isAuthenticated, session.merchantOperationsReader.scope == route.origin.readerScope {
                    switch route.kind {
                    case .topic:
                        MerchantContentDocumentView(service: session.merchantContentService, query: .recruiting,
                            focusedTopicID: route.targetID, focusedMerchantID: route.origin.merchantID)
                    case .partner:
                        if let owner = PublicMerchantOwnerID(route.targetID) {
                            let home = session.publicMerchantHomeContext
                            let reader = CoopRelationMerchantReader(base: home.reader, owner: owner, isCurrent: {
                                session.merchantOperationsReader.isAuthenticated && session.merchantOperationsReader.scope == route.origin.readerScope
                            })
                            PublicMerchantHomeView(target: .ownerMemberID(owner), context: .init(reader: reader, image: home.image))
                        } else { Text("merchantMarketing.unavailable") }
                    }
                } else { Text("merchantMarketing.stale") }
            case .cooperationCenter(let origin):
                if session.merchantOperationsReader.isAuthenticated, session.merchantOperationsReader.scope == origin.readerScope {
                    MerchantContentDocumentView(service: session.merchantContentService, query: .recruiting,
                        focusedMerchantID: origin.merchantID)
                } else { Text("merchantMarketing.stale") }
            case .cooperationSettings(let origin):
                if session.merchantOperationsReader.isAuthenticated, session.merchantOperationsReader.scope == origin.readerScope {
                    MerchantOperationsDocumentView(reader: session.merchantOperationsReader, destination: .cooperation)
                } else { Text("merchantMarketing.stale") }
            }
        }.id(session.sessionRevision)
    }
}
