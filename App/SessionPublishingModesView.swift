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
    private func activityTemplateCreator() -> AnyView {
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
    /// Empty professional editor for the chosen route type (mini-program 专业手动).
    private func professionalEditor(_ product: ProjectEditProduct) -> AnyView {
        AnyView(ProjectEditView(coordinator: session.projectEditor(product: product), sessionRevision: session.sessionRevision, publisherClient: session.publisherLifecycleContext?.client, publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) }, cloudDraftProjectsHost: { AnyView(SessionCreatorProjectsView(session: session)) }).id(session.projectEditorContextID))
    }
    /// 互动: template intro, naming, then the template editor.
    private func templateAuthoring() -> AnyView {
        AnyView(TemplateAuthoringEntryDestination(factory: { session.templateAuthoringEditor() },
            completion: session.templateAuthoringCompletionContext,
            sessionRevision: session.sessionRevision, metadataReader: session,
            imageSelectionApproved: { session.retainedImagePickerHost.nativeSelectionEnabled })
            .environment(\.templateCoverSource, .init(makeService: { session.makeActivityCoverService() }, session: { session.publishingSession }))
            .id(session.templateAuthoringViewIdentity))
    }
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
                               openTemplates: openTemplates)
        } else {
            PublishingModesView(service: session.publishingService, account: session.publishingSession, makeAIDraft: makeAIDraft ?? session.g6PublishingAIDraftFactory,
                            makeIdentityRegistration: { session.makePublisherIdentityRegistrationService() },
                            makeActivityTemplate: { activityTemplateCreator() }, makeActivityCover: { session.makeActivityCoverService() },
                            placeSearch: PublishingMapKitAdapter(), draftStore: session.publishingDraftStore, openProfessional: { seed = $0; showEditor = true },
                            openResource: { resource = $0 },
                            makeProfessional: { professionalEditor($0) },
                            makeTemplateAuthoring: { templateAuthoring() })
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
