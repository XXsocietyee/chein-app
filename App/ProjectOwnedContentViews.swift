import SwiftUI

/// The list owns the exact source row and reader scope. Public detail data is never
/// converted into an owner scope or an editable draft.
@MainActor final class ProjectOwnedContentNavigation: ObservableObject {
    struct Selection: Identifiable, Hashable {
        nonisolated let id = UUID()
        let project: CreatorContentProject
        let scope: UUID
        /// Captured once at open; closing only clears the selection and never rewrites
        /// the row, so a return lets the list re-read instead of mutating local state.
        let decision: MyProjectStateNavigationDecision
        let merchantScopeAccess: MyProjectMerchantScopeAccess
        nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }
    @Published private(set) var selection: Selection?
    func open(_ project: CreatorContentProject, scope: UUID, reader: any CreatorContentReading,
              merchantScopeAccess: MyProjectMerchantScopeAccess = .init(), canEditActivity: Bool = true) {
        guard reader.scope == scope, reader.isAuthenticated else { return }
        let decision = MyProjectStateNavigation.decision(project: project, readerScope: scope,
            canEditActivity: canEditActivity, merchantScopeAccess: merchantScopeAccess)
        selection = .init(project: project, scope: scope, decision: decision, merchantScopeAccess: merchantScopeAccess)
    }
    /// fix-1128b-social #27: the row menu's 编辑 sets a prepared selection.
    func show(_ value: Selection) { selection = value }
    func close(_ original: Selection) {
        guard selection?.id == original.id, selection?.scope == original.scope else { return }
        selection = nil
    }
    func retire(scope: UUID) { if let value = selection, value.scope == scope { close(value) } }
    func presentation(_ original: Selection?) -> Binding<Selection?> {
        Binding(get: { self.selection?.id == original?.id ? self.selection : nil }, set: { next in
            guard next == nil, let original else { return }; self.close(original)
        })
    }
}
@MainActor struct ProjectOwnedContentBrowser: View {
    let reader: any CreatorContentReading
    let revision: UInt64
    let makeEditor: (ProjectEditRemoteTarget) -> ProjectEditCoordinator?
    let detail: (CreatorContentDestination) -> AnyView
    var editorContextID: String? = nil
    var publisherClient: PublisherLifecycleHTTP? = nil
    var publisherHost: ((PublishedResource) -> AnyView)? = nil
    /// `AppSession.activityEditingController(id:)`. Nil leaves the activity route unavailable.
    var makeActivityEditor: ((Int) -> ActivityEditingController?)? = nil
    var makeActivityCover: (() -> ActivityCoverService?)? = nil
    var publishingEpoch: UUID? = nil
    var activityGrants: ActivityEditingGrants = .init()
    /// Nil omits `scope` on `api/project/my`. `MERCHANT` is the store entry.
    var entryScope: String? = nil
    /// From access/me `merchant:project:manage`. False keeps the merchant entry browse-only.
    var canManageProjects: Bool = false
    var initialType: String = "topic"
    @StateObject private var navigation = ProjectOwnedContentNavigation()
    @Environment(\.myProjectMerchantScopeAccess) private var merchantScopeAccess
    @State private var listRefreshGeneration: UInt64 = 0
    @State private var listRefresh: MyProjectListRefreshRequest?
    @State private var cancellingTopic: PublishedResource?
    var body: some View {
        let presented = navigation.selection
        CreatorContentProjectsView(reader: reader, entryScope: entryScope, canManageProjects: canManageProjects, initialType: initialType, onOpenProject: { project, scope, _ in
            navigation.open(project, scope: scope, reader: reader,
                merchantScopeAccess: MyProjectMerchantScopeExclusiveAdapter.access(entryScope: entryScope, canManageProjects: canManageProjects))
        }, onOpen: { _ in }, listRefresh: listRefresh)
        .environment(\.myProjectTopicCancel, publisherHost == nil ? nil : { id in
            cancellingTopic = try? PublishedResource(kind: .topic, value: id)
        })
        .environment(\.myProjectActivityEdit, activityEditEntry)
        .navigationDestination(item: $cancellingTopic) { resource in
            if let publisherHost { publisherHost(resource) }
        }
        .navigationDestination(item: navigation.presentation(presented)) { value in
            if reader.scope == value.scope, reader.isAuthenticated {
                switch value.decision {
                case .ownerTopicEditor(let target):
                    ProjectRemoteEditorDestination(target: target, reader: reader, revision: revision,
                        makeEditor: makeEditor, editorContextID: editorContextID, publisherClient: publisherClient, publisherHost: publisherHost)
                        .accessibilityIdentifier("myProject.state.topicEditor")
                case .activityEditor(let request):
                    MyProjectActivityEditorDestination(request: request, authenticated: reader.isAuthenticated,
                        currentScope: reader.scope, publishingEpoch: publishingEpoch,
                        browseOnly: value.merchantScopeAccess.isBrowseOnly || liveAccess.isBrowseOnly, grants: activityGrants,
                        makeEditor: makeActivityEditor, makeCover: makeActivityCover,
                        onAcknowledged: acceptSave, onRevoke: { revoke(request) })
                case .detail(let destination):
                    detail(destination)
                        .accessibilityIdentifier("myProject.state.detail")
                        .toolbar {
                            // Browse-only merchant scope never gets an edit entry; other
                            // detail rows keep the existing owner-bound edit link.
                            if !value.merchantScopeAccess.isBrowseOnly, !liveAccess.isBrowseOnly,
                               let target = ProjectEditRemoteTarget(project: value.project, readerScope: value.scope) {
                                NavigationLink {
                                    ProjectRemoteEditorDestination(target: target, reader: reader, revision: revision,
                                        makeEditor: makeEditor, editorContextID: editorContextID, publisherClient: publisherClient, publisherHost: publisherHost)
                                } label: { Text("projectRemote.edit") }
                                    .accessibilityIdentifier("projectRemote.edit")
                            }
                        }
                case .unavailable:
                    Text("projectRemote.stale")
                }
            } else { Text("projectRemote.stale") }
        }
        .onChange(of: reader.scope) { original, _ in navigation.retire(scope: original) }
        .onChange(of: liveAccess) { _, access in if access.isBrowseOnly { navigation.retire(scope: reader.scope) } }
    }
    /// fix-1128b-social #27: 编辑 in the activity row menu when the session can build an editor with live grants.
    private var activityEditEntry: ((CreatorContentProject) -> Void)? {
        guard makeActivityEditor != nil, activityGrants.read != nil, activityGrants.update != nil, !liveAccess.isBrowseOnly else { return nil }
        return { project in
            navigation.openActivityEditor(project, scope: reader.scope, reader: reader, merchantScopeAccess: liveAccess)
        }
    }
    private var liveAccess: MyProjectMerchantScopeAccess {
        MyProjectMerchantScopeExclusiveAdapter.access(entryScope: entryScope, canManageProjects: canManageProjects)
    }
    private func acceptSave(_ token: MyProjectActivityEditorReturnToken) {
        let generation = listRefreshGeneration &+ 1
        guard let refresh = MyProjectActivityEditorPolicy.refreshRequest(token: token, status: "acknowledged",
            currentScope: reader.scope, authenticated: reader.isAuthenticated, generation: generation) else { return }
        listRefreshGeneration = generation
        listRefresh = refresh
        if let selection = navigation.selection, selection.scope == token.readerScope { navigation.close(selection) }
    }
    private func revoke(_ request: MyProjectActivityEditorRequest) {
        guard let selection = navigation.selection, selection.scope == request.readerScope,
              selection.decision == .activityEditor(request) else { return }
        navigation.close(selection)
    }
}
@MainActor struct ProjectRemoteEditorDestination: View {
    let target: ProjectEditRemoteTarget
    let reader: any CreatorContentReading
    let revision: UInt64
    let makeEditor: (ProjectEditRemoteTarget) -> ProjectEditCoordinator?
    var editorContextID: String? = nil
    var publisherClient: PublisherLifecycleHTTP? = nil
    var publisherHost: ((PublishedResource) -> AnyView)? = nil
    var body: some View {
        if reader.scope == target.readerScope, reader.isAuthenticated, let coordinator = makeEditor(target) {
            ProjectEditView(coordinator: coordinator, sessionRevision: revision,
                publisherClient: publisherClient, publisherHost: publisherHost).id(editorContextID.map { target.id + ":" + $0 } ?? target.id)
        } else { ContentUnavailableView("projectRemote.stale", systemImage: "exclamationmark.arrow.triangle.2.circlepath").accessibilityIdentifier("projectRemote.stale") }
    }
}
@MainActor struct SessionCreatorProjectsView: View {
    @ObservedObject var session: AppSession
    /// Personal account entry leaves this nil. The merchant entry passes `MERCHANT`.
    var entryScope: String? = nil
    /// MP myproject `type=` link: the tab the page starts on (`topic`, `activity` or `template`).
    var initialType: String = "topic"
    @State private var canManageProjects = false
    @State private var showsReceivedApplies = false
    /// Merchant list scope is a merchant-center entry. Release keeps the personal list.
    private var releasedEntryScope: String? {
        if entryScope == "MERCHANT", !PlayerLaunch.merchantCenterEnabled { return nil }
        return entryScope
    }
    var body: some View {
        ProjectOwnedContentBrowser(reader: session.creatorContentReader, revision: session.sessionRevision,
            makeEditor: { session.projectEditor(target: $0) }, detail: { destination in
                switch destination {
                // R7-PC-B2-4, MP myproject index.js:450-453: 我发布的 topics open the project home (merchantinfo?topicId=, the
                // host view), not the player ticket page. K12: merchantinfo is hidden in Release; the player topic opens.
                case .topic(let id):
                    if PlayerLaunch.merchantCenterEnabled {
                        return AnyView(MerchantContentDocumentView(service: session.merchantContentService, query: .project(topicID: id), focusedTopicID: id)
                            .merchantProjectHostDestinations(session: session)
                            .toolbar { TopicCreatorToolsToolbar(session: session, topicID: id, entryScope: releasedEntryScope) })
                    }
                    return AnyView(SessionTopicDetailView(id: id, session: session))
                case .activity(let id): return AnyView(ActivityDetailView(id: id, reader: session)
                    .toolbar { MyProjectActivityDetailWriteToolbar(session: session, activityID: id) })
                case .playTemplate(let id): return AnyView(DiscoveryTemplateDetailView(id: id, reader: session,
                    authoringFactory: { session.templateAuthoringEditor(adopting: $0) }, authoringRevision: session.sessionRevision, authoringCompletion: session.templateAuthoringCompletionContext).id(session.templateAuthoringViewIdentity))
                }
            }, editorContextID: session.projectEditorContextID, publisherClient: session.publisherLifecycleContext?.client,
            publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) },
            makeActivityEditor: { session.activityEditingController(id: $0) },
            makeActivityCover: { session.makeActivityCoverService() },
            publishingEpoch: session.publishingSession?.epoch,
            activityGrants: session.activityEditingGrants(),
            entryScope: releasedEntryScope, canManageProjects: canManageProjects, initialType: initialType)
            .environment(\.myProjectTemplateShelf, MyProjectTemplateShelfHost { session.myProjectTemplateShelf(header: $0) })
            .environment(\.myProjectPublishEntry, session.myProjectPublishEntry())
            // Lane G: received coop applications (协作邀请) are hidden in Release; nil hides 查看申请.
            .environment(\.myProjectReceivedApplies, PlayerLaunch.merchantCenterEnabled ? { showsReceivedApplies = true } : nil)
            .navigationDestination(isPresented: $showsReceivedApplies) {
                CooperationBrowserView(reader: session.cooperationReader, peerReader: session.cooperationFlowReader,
                                       operationScope: releasedEntryScope, initialDirection: .received,
                                       topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) },
                                       embedsNavigationStack: false)
            }
            .id(session.creatorContentReader.scope)
            .task(id: "\(session.creatorContentReader.scope.uuidString)|\(releasedEntryScope ?? "")") { await loadManage() }
    }
    /// Merchant entry reads access/me. Failure or a missing project-manage grant stays browse-only.
    /// The personal entry does not call access/me and does not send `scope`.
    private func loadManage() async {
        guard (try? CreatorContentService.merchantWireScope(releasedEntryScope)) == "MERCHANT" else {
            canManageProjects = false
            return
        }
        let scope = session.creatorContentReader.scope
        canManageProjects = false
        let allowed = (try? await session.merchantAccess())?.allows(.projects) == true
        guard session.creatorContentReader.scope == scope else { return }
        canManageProjects = allowed
    }
}

extension View {
    /// R7-PC-B2-3: the merchantinfo project view reached outside the merchant hub (the MP deep link, 我的项目 topic rows)
    /// gets the same host supply / offer-withdrawal destinations `MerchantHomeView` injects, so those rows are not dead.
    @MainActor func merchantProjectHostDestinations(session: AppSession) -> some View {
        let flowReader = session.cooperationFlowReader
        let contentService = session.merchantContentService
        let executor = session.offerWithdrawalExecutor
        return self
            .environment(\.merchantContentSupplyDestination, { source in
                AnyView(MerchantCooperationSupplyView(source: source, reader: flowReader))
            })
            .environment(\.merchantOfferWithdrawalDestination, { source in
                AnyView(MerchantOfferWithdrawalHostView(source: source, reader: flowReader, contentService: contentService, executor: executor))
            })
            // R11-PC-B-3: free-explore 自己承接 (MP utils/fe-author-sale.js:117-128).
            .environment(\.topicSelfSupplyService, { session.makePlayerContentRound4Service() })
    }
}
