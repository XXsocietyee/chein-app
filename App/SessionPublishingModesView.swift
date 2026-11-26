import SwiftUI

/// Real creator entry. Every destination is recreated at the account/role epoch boundary.
@MainActor struct SessionPublishingModesView: View {
    @EnvironmentObject private var session: AppSession
    var makeAIDraft: (() -> any PublishingAIDraftServing)? = nil
    var appliesPushedChrome: Bool = true
    /// 发布 tab root (P 210:8374): large root title and the 从模板开始 section.
    var isTabRoot = false
    var openTemplates: (() -> Void)? = nil
    @State private var seed: ProjectEditDraft?
    @State private var showEditor = false
    @State private var resource: PublishedResource?
    private func activityTemplateCreator() -> AnyView { sessionActivityTemplateCreator(session) }
    /// Empty professional editor for the chosen route type (mini-program 专业手动).
    private func professionalEditor(_ product: ProjectEditProduct) -> AnyView {
        AnyView(ProjectEditView(coordinator: session.projectEditor(product: product), sessionRevision: session.sessionRevision, publisherClient: session.publisherLifecycleContext?.client, publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) }, cloudDraftProjectsHost: { AnyView(SessionCreatorProjectsView(session: session)) }).id(session.projectEditorContextID))
    }
    /// 互动: template intro, naming, then the template editor.
    private func templateAuthoring() -> AnyView { sessionTemplateAuthoringEntry(session) }
    /// 发布 tab root (P 210:8374) or the pushed publish menu; both get the same inputs and destinations.
    @ViewBuilder private var modes: some View {
        if isTabRoot {
            PublishRootContent(service: session.publishingService, account: session.publishingSession, makeAIDraft: makeAIDraft ?? session.g6PublishingAIDraftFactory,
                            makeIdentityRegistration: { session.makePublisherIdentityRegistrationService() },
                            makeActivityTemplate: { activityTemplateCreator() }, makeActivityCover: { session.makeActivityCoverService() },
                            placeSearch: PublishingMapKitAdapter(), draftStore: session.publishingDraftStore, openProfessional: { seed = $0; showEditor = true },
                            openResource: { resource = $0 },
                            makeProfessional: { professionalEditor($0) },
                            makeTemplateAuthoring: { templateAuthoring() },
                               makeProjects: { AnyView(SessionCreatorProjectsView(session: session)) },
                               openTemplates: openTemplates)
        } else {
            PublishingModesView(service: session.publishingService, account: session.publishingSession, makeAIDraft: makeAIDraft ?? session.g6PublishingAIDraftFactory,
                            makeIdentityRegistration: { session.makePublisherIdentityRegistrationService() },
                            makeActivityTemplate: { activityTemplateCreator() }, makeActivityCover: { session.makeActivityCoverService() },
                            placeSearch: PublishingMapKitAdapter(), draftStore: session.publishingDraftStore, openProfessional: { seed = $0; showEditor = true },
                            openResource: { resource = $0 },
                            makeProfessional: { professionalEditor($0) },
                            makeTemplateAuthoring: { templateAuthoring() },
                            makeProjects: { AnyView(SessionCreatorProjectsView(session: session)) })
        }
    }
    var body: some View {
        modes
            .navigationDestination(isPresented: $showEditor) {
                if let seed {
                    ProjectEditView(coordinator: session.projectEditor(product: seed.product, owner: seed.owner), sessionRevision: session.sessionRevision, seed: seed, publisherClient: session.publisherLifecycleContext?.client, publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) }, cloudDraftProjectsHost: { AnyView(SessionCreatorProjectsView(session: session)) })
                        .id(session.projectEditorContextID)
                }
            }
            .navigationDestination(item: $resource) { destination in
                switch destination.kind {
                case .topic: SessionTopicDetailView(id: destination.value, session: session).id(session.topicReader.scope)
                case .activity: ActivityDetailView(id: destination.value, reader: session)
                    .toolbar {
                        PublisherLifecycleNavigationLink(session: session, resource: destination)
                        if let editor = session.activityEditingController(id: destination.value) {
                            NavigationLink { ActivityEditingView(owner: editor, makeActivityCover: { session.makeActivityCoverService() }).id(session.publishingSession?.epoch) } label: {
                                Text("entry", tableName: "ActivityEditing")
                            }.accessibilityIdentifier("activityEdit.entry")
                        }
                    }
                case .template: DiscoveryTemplateDetailView(id: destination.value, reader: session,
                    authoringFactory: { session.templateAuthoringEditor(adopting: $0) }, authoringRevision: session.sessionRevision).id(session.templateAuthoringViewIdentity)
                }
            }
            .onChange(of: session.publishingSession) { _, _ in
                session.publishingService?.invalidateReviews(); seed = nil; showEditor = false; resource = nil
            }
            .modifier(SessionPublishingRootChrome(appliesPushedChrome: appliesPushedChrome))
    }
}

private struct SessionPublishingRootChrome: ViewModifier {
    let appliesPushedChrome: Bool
    func body(content: Content) -> some View {
        if appliesPushedChrome {
            content.cyPushedChrome(domain: .topicEditor)
        } else {
            content
        }
    }
}

/// 发布活动 › 关联玩法模板: the template creator with the shelf as its library (shared by the publish menu and deep links).
@MainActor func sessionActivityTemplateCreator(_ session: AppSession) -> AnyView {
    let coordinator = session.templateAuthoringEditor()
    let library: () -> AnyView = {
        AnyView(TemplateAuthoringMineView(coordinator: session.templateShelfCoordinator(), sessionRevision: session.sessionRevision,
            memberDetail: { AnyView(SessionOwnedMemberTemplateDetailView(id: $0)) },
            ownerConfiguration: { AnyView(SessionOwnedTemplateConfigurationView(id: $0)) },
            creatorConsent: { AnyView(SessionWorkshopCreatorConsentView(selection: $0)) }).id(session.templateShelfViewIdentity))
    }
    return AnyView(TemplateAuthoringSaveFlow(coordinator: coordinator, sessionRevision: session.sessionRevision, metadataReader: session,
        imageSelectionApproved: { session.retainedImagePickerHost.nativeSelectionEnabled }, library: library)
        .modifier(TemplateAuthoringPublishCompletion(coordinator: coordinator, library: library)).id(session.sessionRevision))
}

/// 互动: template intro, naming, then the template editor (MP template-intro → temp).
/// r9 C-T6b: MP template-intro/index.js:291 opens `temp/index?scope=MERCHANT` for merchants.
@MainActor func sessionTemplateAuthoringEntry(_ session: AppSession, scope: String? = nil) -> AnyView {
    AnyView(TemplateAuthoringEntryDestination(factory: { session.templateAuthoringEditor(from: nil, scope: scope) },
        completion: session.templateAuthoringCompletionContext,
        sessionRevision: session.sessionRevision, metadataReader: session,
        imageSelectionApproved: { session.retainedImagePickerHost.nativeSelectionEnabled })
        .environment(\.templateCoverSource, .init(makeService: { session.makeActivityCoverService() }, session: { session.publishingSession }))
        .id(session.templateAuthoringViewIdentity))
}

/// Deep-link host for `pages/publish/activity/index` (fix-parity C-A1): the 发布活动 form itself, with the inputs the
/// publish tab passes; `?id=` opens the existing activity editor. Each screen keeps its own sign-in and precheck gates.
@MainActor struct SessionActivityPublishingDestination: View {
    @EnvironmentObject private var session: AppSession
    var editingID: Int? = nil
    var body: some View {
        if let editingID {
            if let editor = session.activityEditingController(id: editingID) {
                ActivityEditingView(owner: editor, makeActivityCover: { session.makeActivityCoverService() })
                    .id(session.publishingSession?.epoch)
            } else {
                CYEmptyState(systemImage: "exclamationmark.arrow.triangle.2.circlepath", "projectRemote.stale", messageIdentifier: "projectRemote.stale")
            }
        } else {
            ActivityPublishingView(service: session.publishingService, account: session.publishingSession, placeSearch: PublishingMapKitAdapter(),
                                   draftStore: session.publishingDraftStore,
                                   makeIdentityRegistration: { session.makePublisherIdentityRegistrationService() },
                                   makeActivityTemplate: { sessionActivityTemplateCreator(session) },
                                   makeActivityCover: { session.makeActivityCoverService() })
                .id(session.publishingSession?.epoch)
        }
    }
}
