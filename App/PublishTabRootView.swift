import SwiftUI

/// Root view for the restored `.publish` player tab (5-tab root: 首页 / 漫游 / 发布 / 俱乐部 / 我的).
///
/// mp-r3-publish (MP-first): the mini-program 发布 tab is `pages/template/index` — the template shelf
/// (主题 / 玩法 tabs, search, featured rail, tags, shelves) with the bell in the header. Publishing starts from the
/// floating “+” (`components/tabBar` `tabBar__publish` → `cy-publish-sheet`): 自由探索 → `publish/fabu?mode=2`,
/// 城市定向 → `publish/fabu?mode=1`, 互动 → `publish/template-intro`, and 返回 closes it (V3-44: no quick-setup step,
/// the type goes straight to the professional editor). Here the shelf is the root, the “+” is a system menu with the
/// same three choices in the same order, and tapping outside the menu is 返回.
@MainActor struct PublishTabRootView: View {
    @EnvironmentObject private var session: AppSession
    @State private var showsProjects = false
    @State private var showsCreatorCenter = false
    @State private var publishRoute: PublishTabRoute?

    var body: some View {
        DiscoveryTemplateBrowserView(
            reader: session,
            authoringFactory: { session.templateAuthoringEditor(adopting: $0) },
            authoringRevision: session.sessionRevision,
            authoringCompletion: session.templateAuthoringCompletionContext,
            isTabRoot: true
        )
        .id(session.templateAuthoringViewIdentity)
        // Design hand-off r1 PL-11: 消息 is the first trailing action on every tab root (MP `tpl-bell` → IM list).
        .modifier(SessionMessagingToolbarEntry(session: session))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if session.isConfigured {
                    publishMenu
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if session.publishingSession != nil {
                    creatorMenu
                }
            }
        }
        .navigationDestination(item: $publishRoute) { route in
            publishDestination(route)
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
        .onChange(of: session.publishingSession) { _, _ in
            publishRoute = nil
        }
    }

    /// MP `cy-publish-sheet`: 自由探索, 城市定向, 互动 (in that order); dismissing the menu is 返回.
    private var publishMenu: some View {
        Menu {
            Button {
                publishRoute = .freeExplore
            } label: {
                Label("projectEdit.freeExplore", systemImage: "location.magnifyingglass")
            }
            .accessibilityIdentifier("publishTab.publish.freeExplore")
            Button {
                publishRoute = .city
            } label: {
                Label("projectEdit.city", systemImage: "map")
            }
            .accessibilityIdentifier("publishTab.publish.city")
            Button {
                publishRoute = .interaction
            } label: {
                Label("publishTab.publish.interaction", systemImage: "puzzlepiece.extension")
            }
            .accessibilityIdentifier("publishTab.publish.interaction")
        } label: {
            Label("discovery.templateTab.publish", systemImage: "plus")
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(Text("discovery.templateTab.publish"))
        .accessibilityIdentifier("publishTab.publish")
    }

    /// Creator shortcuts kept from the earlier root (the MP reaches them from 我的): 我的项目 and the content center.
    private var creatorMenu: some View {
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

    /// 自由探索 / 城市定向 open an empty professional editor (MP `publish/fabu?mode=`); 互动 opens template intro →
    /// naming → template editor (MP `publish/template-intro` → `publish/temp`).
    @ViewBuilder private func publishDestination(_ route: PublishTabRoute) -> some View {
        switch route {
        case .freeExplore:
            professionalEditor(.freeExplore)
        case .city:
            professionalEditor(.city)
        case .interaction:
            sessionTemplateAuthoringEntry(session)
        }
    }

    private func professionalEditor(_ product: ProjectEditProduct) -> some View {
        ProjectEditView(coordinator: session.projectEditor(product: product), sessionRevision: session.sessionRevision, publisherClient: session.publisherLifecycleContext?.client, publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) }, cloudDraftProjectsHost: { AnyView(SessionCreatorProjectsView(session: session)) })
            .id(session.projectEditorContextID)
    }
}

/// The three choices of the MP publish sheet.
enum PublishTabRoute: String, Hashable, Identifiable {
    case freeExplore, city, interaction
    var id: String { rawValue }
}
