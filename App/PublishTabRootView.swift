import SwiftUI

/// Root view for the restored `.publish` player tab (5-tab root: 首页 / 漫游 / 发布 / 俱乐部 / 我的).
/// Hosts `SessionPublishingModesView` without pushed-screen tab-bar hiding, plus toolbar access
/// to creator templates, projects, and the creator content center.
@MainActor struct PublishTabRootView: View {
    @EnvironmentObject private var session: AppSession
    @State private var showsTemplates = false
    @State private var showsProjects = false
    @State private var showsCreatorCenter = false

    var body: some View {
        // P 210:8374: the template browser is the page's 从模板开始 section, so the header keeps 消息 plus one page
        // action (the creator ⋯ menu), as the root-header rule asks (verify-r1 2.5).
        SessionPublishingModesView(appliesPushedChrome: false, isTabRoot: true,
                                   openTemplates: session.isConfigured ? { showsTemplates = true } : nil)
            .id(session.publishingSession?.epoch)
            // Design hand-off r1 PL-11: 消息 is the first trailing action on every tab root.
            .modifier(SessionMessagingToolbarEntry(session: session))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if session.publishingSession != nil {
                        Menu {
                            Button("creatorContent.projects", systemImage: "square.stack") {
                                showsProjects = true
                            }
                            .accessibilityLabel(Text("creatorContent.projects"))
                            .accessibilityIdentifier("publishTab.openCreatorProjects")
                            Button("creatorContent.center", systemImage: "pencil.and.outline") {
                                showsCreatorCenter = true
                            }
                            .accessibilityLabel(Text("creatorContent.center"))
                            .accessibilityIdentifier("publishTab.openCreatorCenter")
                        } label: {
                            Label("homeFeed.more", systemImage: "ellipsis.circle")
                                .labelStyle(.iconOnly)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel(Text("homeFeed.more"))
                        .accessibilityHint(Text("publishTab.creatorMenu.hint"))
                        .accessibilityIdentifier("publishTab.creatorMenu")
                    }
                }
            }
            .navigationDestination(isPresented: $showsTemplates) {
                DiscoveryTemplateBrowserView(
                    reader: session,
                    authoringFactory: { session.templateAuthoringEditor(adopting: $0) },
                    authoringRevision: session.sessionRevision,
                    authoringCompletion: session.templateAuthoringCompletionContext,
                    publishDestination: {
                        AnyView(SessionPublishingModesView().environmentObject(session).id(session.publishingSession?.epoch))
                    },
                    searchDestination: { AnyView(SessionLinkedSearchView().environmentObject(session)) },
                    inboxDestination: { AnyView(SessionMessagingHome(session: session)) }
                )
                .id(session.templateAuthoringViewIdentity)
                .cyPushedChrome(domain: .topicEditor)
            }
            .navigationDestination(isPresented: $showsProjects) {
                SessionCreatorProjectsView(session: session)
                    .cyPushedChrome(domain: .topicEditor)
            }
            .navigationDestination(isPresented: $showsCreatorCenter) {
                CreatorContentCenterView(
                    reader: session.creatorContentReader,
                    publisherContext: session.publisherLifecycleContext,
                    creatorStudio: session.creatorStudioService
                )
                .id(session.creatorContentReader.scope)
                .cyPushedChrome(domain: .topicEditor)
            }
    }
}
