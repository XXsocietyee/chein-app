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
    /// MP `openPublishSheet`: the `api/publish/home` snapshot the three choices check first (`pub`). Nil while it
    /// loads or after it fails.
    @State private var publishHome: [String: ProjectEditJSON]?
    /// MP `toast` for the pre-checks (发布信息尚未就绪 / 当前身份不可发布主题).
    @State private var publishNotice: LocalizedStringKey?
    /// P2-6 (MP `components/tabBar/index.js:88-93` `ensureLoginFor('publish', …)`): signed out, “+” opens sign-in.
    @State private var showsSignIn = false

    var body: some View {
        DiscoveryTemplateBrowserView(
            reader: session,
            authoringFactory: { session.templateAuthoringEditor(adopting: $0) },
            authoringRevision: session.sessionRevision,
            authoringCompletion: session.templateAuthoringCompletionContext,
            isTabRoot: true
        )
        .id(session.templateAuthoringViewIdentity)
        // P1-26 (MP topic-preview `useTemplate` → `publish/fabu?id=`): 用这个模板 pushes the copied draft into the editor.
        .environment(\.topicEditorDestination, Self.topicEditorDestination(session: session))
        // Design hand-off r1 PL-11: 消息 is the first trailing action on every tab root (MP `tpl-bell` → IM list).
        .modifier(SessionMessagingToolbarEntry(session: session))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if session.isConfigured {
                    if session.isSignedIn {
                        publishMenu
                    } else {
                        signInPublishButton
                    }
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
        // MP reads `api/publish/home` each time the sheet opens; here each time the shelf appears or the account changes.
        .task(id: session.publishingSession) {
            await loadPublishHome()
        }
        .cyToast(message: $publishNotice)
        .cySheet(isPresented: $showsSignIn) {
            Group { LoginView(intent: .player).environmentObject(session) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    /// Signed out: the same “+” in the same place, but it asks for sign-in first (MP `ensureLoginFor`). After sign-in the
    /// “+” becomes the publish menu.
    private var signInPublishButton: some View {
        Button {
            showsSignIn = true
        } label: {
            Label("discovery.templateTab.publish", systemImage: "plus")
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(Text("discovery.templateTab.publish"))
        .accessibilityHint(Text("action.goSignIn"))
        .accessibilityIdentifier("publishTab.publish.signIn")
    }

    private func loadPublishHome() async {
        publishHome = nil
        guard let service = session.publishingService, let account = session.publishingSession else { return }
        let home = try? await service.read(.capability, session: account)
        guard account == session.publishingSession else { return }
        publishHome = home?.object
    }

    /// MP `chooseTopicMode` / `choosePro` / `goTemplate` pre-checks, in the MP order: no snapshot → 发布信息尚未就绪；
    /// a topic type with `permission.canProPublish == false` → 当前身份不可发布主题. 互动 checks only the snapshot.
    /// (MP's non-blocking 在架已满 toast is answered inside the editor by `projectEdit.quotaFull`.)
    private func choose(_ route: PublishTabRoute) {
        guard let home = publishHome else {
            publishNotice = "publishTab.publish.notReady"
            Task { await loadPublishHome() }
            return
        }
        if route != .interaction, home["permission"]?.object?["canProPublish"] == ProjectEditJSON.bool(false) {
            publishNotice = "publishTab.publish.identityBlocked"
            return
        }
        publishRoute = route
    }

    /// MP `cy-publish-sheet`: 自由探索, 城市定向, 互动 (in that order); dismissing the menu is 返回.
    private var publishMenu: some View {
        Menu {
            // fix/1128c-ai-showcase (owner 11-28): AI is the visible first step of creating; the MP choices follow.
            Button {
                publishRoute = .aiCreation
            } label: {
                Label("aiCreation.title", systemImage: "wand.and.stars")
            }
            .accessibilityIdentifier("publishTab.publish.ai")
            Divider()
            Button {
                choose(.freeExplore)
            } label: {
                Label("projectEdit.freeExplore", systemImage: "location.magnifyingglass")
            }
            .accessibilityIdentifier("publishTab.publish.freeExplore")
            Button {
                choose(.city)
            } label: {
                Label("projectEdit.city", systemImage: "map")
            }
            .accessibilityIdentifier("publishTab.publish.city")
            Button {
                choose(.interaction)
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
        case .aiCreation:
            SessionAICreationHubView()
        }
    }

    /// P1-26: the same `pages/publish/fabu/index?id=&scope=` editor the 首页 template pages open (MPReviewedPageScreen).
    static func topicEditorDestination(session: AppSession) -> (Int, String?) -> AnyView {
        { topicID, scope in
            AnyView(MPReviewedPageScreen(page: "pages/publish/fabu/index", query: topicEditorQuery(topicID: topicID, scope: scope))
                .environmentObject(session))
        }
    }

    /// MP `publish/fabu` query for a copied draft: `id`, plus `scope` only when the template was adopted for a scope.
    nonisolated static func topicEditorQuery(topicID: Int, scope: String?) -> [String: String] {
        var query = ["id": String(topicID)]
        if let scope, !scope.isEmpty { query["scope"] = scope }
        return query
    }

    private func professionalEditor(_ product: ProjectEditProduct) -> some View {
        ProjectEditView(coordinator: session.projectEditor(product: product), sessionRevision: session.sessionRevision, publisherClient: session.publisherLifecycleContext?.client, publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) }, cloudDraftProjectsHost: { AnyView(SessionCreatorProjectsView(session: session)) })
            .id(session.projectEditorContextID)
    }
}

/// The three choices of the MP publish sheet.
enum PublishTabRoute: String, Hashable, Identifiable {
    case freeExplore, city, interaction
    /// fix/1128c-ai-showcase: Create with AI (theme draft, template fill, club design).
    case aiCreation
    var id: String { rawValue }
}
