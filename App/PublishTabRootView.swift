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
        SessionPublishingModesView(appliesPushedChrome: false)
            .id(session.publishingSession?.epoch)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if session.isConfigured {
                        Button("discovery.browseTemplates", systemImage: "square.stack.3d.up") {
                            showsTemplates = true
                        }
                        .accessibilityIdentifier("publishTab.openTemplates")
                    }
                    if session.publishingSession != nil {
                        Menu {
                            Button("creatorContent.projects", systemImage: "square.stack") {
                                showsProjects = true
                            }
                            .accessibilityIdentifier("publishTab.openCreatorProjects")
                            Button("creatorContent.center", systemImage: "pencil.and.outline") {
                                showsCreatorCenter = true
                            }
                            .accessibilityIdentifier("publishTab.openCreatorCenter")
                        } label: {
                            Label("homeFeed.more", systemImage: "ellipsis.circle")
                                .labelStyle(.iconOnly)
                                .frame(minWidth: 44, minHeight: 44)
                        }
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
                    }
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
