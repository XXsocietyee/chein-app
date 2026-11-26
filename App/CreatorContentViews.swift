import SwiftUI

@MainActor private final class CreatorContentScreenModel<Value>: ObservableObject {
    @Published private var revision: UInt64 = 0
    let state = CreatorContentReadModel<Value>()
    /// PORT-6: rows of the previous successful load, kept visible (read-only) while the same list reloads.
    @Published private(set) var stale: (value: Value, query: CreatorContentQuery, scope: UUID)?
    func cancel() { state.cancelPending(); revision &+= 1 }
    func clear() { state.invalidate(); revision &+= 1 }
    func load(reader: any CreatorContentReading, query: CreatorContentQuery? = nil, operation: () async throws -> Value) async {
        let scope = reader.scope
        if let query, let previous = state.visibleValue(scope: scope) { stale = (previous, query, scope) }
        revision &+= 1
        await state.load(scope: scope, currentScope: { reader.scope }, operation: operation)
        stale = nil
        revision &+= 1
    }
}
struct CreatorContentLoadKey: Hashable {
    let scope: UUID
    let configured: Bool
    let authenticated: Bool
    let query: CreatorContentQuery
    /// Page entry. Empty is the personal list. A merchant entry reloads instead of reusing those rows.
    let entryScope: String
    @MainActor init(_ reader: any CreatorContentReading, query: CreatorContentQuery = .init(), entryScope: String? = nil) {
        scope = reader.scope; configured = reader.isConfigured; authenticated = reader.isAuthenticated; self.query = query
        self.entryScope = entryScope ?? ""
    }
}
private struct CreatorContentIssueView: View {
    let issue: CreatorContentIssue
    /// R7-PC-D1-7: page copy for the signed-out state (MP myproject `登录后查看我的项目`), plus its 登录 action.
    var loginTitleKey: String? = nil
    var onLogin: (() -> Void)? = nil
    /// Round 4 copy (MP myproject/index.wxml:22-23): 当前身份不能查看这些项目 for a denied read (no retry),
    /// 项目加载失败 as the title of a failed read with the reason underneath.
    var deniedTitleKey: String? = nil
    var failureTitleKey: String? = nil
    let retry: () -> Void
    private var isDenied: Bool { issue == .unavailable && deniedTitleKey != nil }
    /// A failed read with a page title shows that title, with the reason as the description.
    private var showsReasonBelow: Bool {
        !(issue == .login && loginTitleKey != nil) && !isDenied && issue != .notConfigured && failureTitleKey != nil
    }
    var body: some View {
        ContentUnavailableView {
            Label {
                Group {
                    if issue == .login, let loginTitleKey { Text(LocalizedStringKey(loginTitleKey)) }
                    else if isDenied, let deniedTitleKey { Text(LocalizedStringKey(deniedTitleKey)) }
                    else if showsReasonBelow, let failureTitleKey { Text(LocalizedStringKey(failureTitleKey)) }
                    else { reason }
                }
                .accessibilityIdentifier("creatorContent.issue")
            } icon: {
                Image(systemName: issue == .login || isDenied ? "lock" : "exclamationmark.circle")
            }
        } description: {
            if showsReasonBelow { reason }
        } actions: {
            if issue == .login, let onLogin {
                Button(action: onLogin) { Text("auth.signIn") }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("projects.signInAction")
            }
            if issue != .login && issue != .notConfigured && !isDenied {
                Button(action: retry) { Text("creatorContent.retry") }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("creatorContent.retry")
            }
        }
    }
    @ViewBuilder private var reason: some View {
        if case .server(let text) = issue { Text(verbatim: text) }
        else { Text(LocalizedStringKey(issue.localizationKey)) }
    }
}
/// Host must observe account/market revisions and reset this destination with .id(reader.scope).
@MainActor struct CreatorContentProjectsView: View {
    let reader: any CreatorContentReading
    /// Nil is the personal entry and does not send `scope`. `MERCHANT` is the merchant entry.
    var entryScope: String? = nil
    /// True only after access/me reported `merchant:project:manage` for this entry. Default closed.
    var canManageProjects: Bool = false
    /// MP myproject onLoad `type=`: the tab shown first. Applied once; the user's own tab taps win after that.
    var initialType: String = "topic"
    /// Third value is the entry scope, never `data.scope`.
    var onOpenProject: ((CreatorContentProject, UUID, String?) -> Void)? = nil
    let onOpen: (CreatorContentDestination) -> Void
    /// Set only after a server save receipt for this reader scope. Another account's token does not match.
    var listRefresh: MyProjectListRefreshRequest? = nil
    @StateObject private var model = CreatorContentScreenModel<CreatorContentProjectPage>()
    /// Nil while my-project writes are gated; then no row offers a write.
    @State private var mutation: MyProjectMutationModel?
    @State private var query = CreatorContentQuery(type: "topic")
    @State private var appliedInitialType = false
    @State private var toastMessage: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.myProjectTemplateShelf) private var templateShelf
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    private var key: CreatorContentLoadKey { .init(reader, query: query, entryScope: entryScope) }
    private var loadedAccess: MyProjectMerchantScopeAccess {
        MyProjectMerchantScopeExclusiveAdapter.access(entryScope: entryScope, canManageProjects: canManageProjects)
    }
    var body: some View {
        List {
            if reader.isOfflineExample { Label("creatorContent.offlineExample", systemImage: "testtube.2").foregroundStyle(.orange) }
            if !reader.isAuthenticated { issue(.login) }
            else if !reader.isConfigured { issue(.notConfigured) }
            else {
                // Mini-program myproject: three underline tabs 主题 / 活动 / 模板, no owner or state filters.
                Section {
                    typeTabs
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                if let mutation, reader.isAuthenticated {
                    MyProjectMutationStrip(model: mutation) { Task { await refresh() } }
                }
                // Mini myproject template tab reads the separate api/template/my-list own-shelf, never project/my rows.
                if query.type == "template" { MyProjectTemplateTabSection(shelf: templateShelf) }
                else if model.state.isLoading, let kept = model.stale,
                        MyProjectSyncPort.keepsStaleRows(isLoading: true, previousQuery: kept.query, currentQuery: query,
                                                        previousScope: kept.scope, currentScope: key.scope) {
                    Text("myProject.syncing").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityAddTraits(.updatesFrequently).accessibilityIdentifier("myProject.syncing")
                    ForEach(MyProjectListPresentation.sorted(kept.value.rows)) { project in
                        card(project).allowsHitTesting(false)
                    }
                }
                else if model.state.isLoading || model.state.loadedScope != key.scope { ProgressView().frame(maxWidth: .infinity).accessibilityLabel(Text("creatorContent.loading")) }
                else if let failure = model.state.visibleIssue(scope: key.scope) { issue(failure) }
                else if let page = model.state.visibleValue(scope: key.scope) {
                    if page.rows.isEmpty { MyProjectEmptyView(type: query.type) }
                    if page.isTruncated { Text("creatorContent.truncated").accessibilityIdentifier("creatorContent.truncated") }
                    let rowScope = key.scope
                    // PC-D-1-5: no 发布单场活动 row above a non-empty list (MP owner ruling m693; the empty state keeps it).
                    ForEach(MyProjectListPresentation.sorted(page.rows)) { project in
                        if let destination = project.destination {
                            Button {
                                guard model.state.loadedScope == rowScope, reader.scope == rowScope, reader.isAuthenticated,
                                      model.state.visibleValue(scope: rowScope)?.rows.contains(project) == true else { return }
                                if let onOpenProject { onOpenProject(project, rowScope, entryScope) } else { onOpen(destination) }
                            } label: { card(project) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("creatorContent.project.\(project.id)")
                                .contextMenu { MyProjectRowOperationsMenu(project: project) }
                                .overlay(alignment: .topTrailing) { MyProjectRowMoreButton(project: project) }
                            MyProjectSaveAsTemplateEntry(project: project) { Task { await refresh() } }
                            MyProjectAuditEntry(project: project)
                        } else {
                            card(project)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyDomainScreen(.topicEditor)
        .cyHideTabBar(true)
        .environment(\.myProjectMerchantScopeAccess, loadedAccess)
        .environment(\.myProjectMutation, loadedAccess.isBrowseOnly ? nil : mutation)
        .task(id: entryScope) { mutation = MyProjectMutationFactory.liveModel(scope: entryScope) }
        .cyPageTitle("creatorContent.projects") // PC-D-1-7
        .onAppear {
            guard !appliedInitialType else { return }
            appliedInitialType = true
            if ["topic", "activity", "template"].contains(initialType), initialType != query.type { query.type = initialType }
        }
        .modifier(CreatorContentReadLifecycle(key: key, refresh: refresh, cancel: model.cancel))
        .onChange(of: listRefresh) { _, request in
            guard let request, request.readerScope == reader.scope, reader.isAuthenticated else { return }
            Task { await refresh() }
        }
        .cyToast(verbatimMessage: $toastMessage)
    }
    private var typeTabs: some View {
        Picker(selection: $query.type) {
            ForEach(["topic", "activity", "template"], id: \.self) { value in
                Text(LocalizedStringKey("creatorContent.filter." + value))
                    .accessibilityIdentifier("creatorContent.type.\(value)")
                    .tag(value)
            }
        } label: { Text("creatorContent.type") }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: query.type)
    }
    private func issue(_ value: CreatorContentIssue) -> some View {
        CreatorContentIssueView(issue: value, loginTitleKey: "myProject.signInRequired",
                                onLogin: rootTabSwitch.isAvailable ? { rootTabSwitch(.mine) } : nil,
                                deniedTitleKey: "myProject.accessDenied", failureTitleKey: "myProject.loadFailed") { Task { await refresh() } }
    }
    /// Mini-program myproject row: cover tile, title (state top-right), hairline, then the stats footer.
    private func card(_ project: CreatorContentProject) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                let title = project.title.trimmingCharacters(in: .whitespacesAndNewlines)
                Color.clear.frame(width: 92, height: 92)
                    .overlay { E1CoverArt(seed: title, symbol: "map", imageURL: project.cover, debugLabel: false,
                                              fallbackImage: MPAsset.BannerCover.subpackageAImagesRouteFreeCover) } // MP myproject.wxml:38
                    .clipShape(.rect(cornerRadius: CYRadius.md, style: .continuous)) // image crop only
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    if let state = project.stateText { Text(verbatim: state).font(.footnote).foregroundStyle(.secondary) }
                    if let type = project.projectTypeText { Text(verbatim: type).font(.subheadline).foregroundStyle(.secondary) }
                    if title.isEmpty { Text("creatorContent.untitled").font(.headline).fixedSize(horizontal: false, vertical: true) }
                    else { Text(verbatim: title).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true) }
                    MyProjectCardMeta(project: project, chinese: locale.language.languageCode?.identifier == "zh")
                }
            }
            Divider()
            // Mini-program myproject footer: co-host acceptance text, otherwise always "N 报名 · N 浏览", then the owner identity.
            Group {
                if let pending = project.pendingVerifyCount { Text("myProject.pendingVerify \(pending)") }
                else if let acceptance = MyProjectListPresentation.acceptanceText(project) { Text(verbatim: acceptance) }
                // Missing counts read "—", never 0 (U03-03: unknown is not a default).
                else { Text("list.stats \(project.signupCountFact.displayText) \(project.viewCountFact.displayText)", tableName: PublishClarityText.table) }
            }
            .font(.subheadline).foregroundStyle(.secondary)
            if project.ownerType == "club" || project.ownerType == "merchant" {
                Text(LocalizedStringKey(project.ownerType == "club" ? "creatorContent.filter.club" : "creatorContent.filter.merchant"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
    private func refresh() async {
        guard reader.isAuthenticated, reader.isConfigured else { model.clear(); return }
        let captured = query
        guard captured.type != "template" else { model.clear(); return }
        await model.load(reader: reader, query: captured) {
            if let live = reader as? CreatorContentSessionReader {
                return try await live.projects(query: captured, operationScope: entryScope)
            }
            return try await reader.projects(query: captured)
        }
    }
}

@MainActor struct CreatorContentCenterView: View {
    let reader: any CreatorContentReading
    var publisherContext: PublisherLifecycleHostContext? = nil
    /// U08-03 / U08-04 rows; nil keeps them unmounted.
    var creatorStudio: CreatorStudioService? = nil
    @StateObject private var model = CreatorContentScreenModel<CreatorContentCenter>()
    @Environment(\.scenePhase) private var scenePhase
    private var key: CreatorContentLoadKey { .init(reader) }
    var body: some View {
        List {
            if reader.isOfflineExample { Label("creatorContent.offlineExample", systemImage: "testtube.2").foregroundStyle(.orange) }
            if !reader.isAuthenticated { issue(.login) }
            else if !reader.isConfigured { issue(.notConfigured) }
            else if model.state.isLoading || model.state.loadedScope != key.scope { ProgressView().frame(maxWidth: .infinity).accessibilityLabel(Text("creatorContent.loading")) }
            else if let failure = model.state.visibleIssue(scope: key.scope) { issue(failure) }
            else if let center = model.state.visibleValue(scope: key.scope) {
                Section {
                    Text(LocalizedStringKey("creatorContent.status." + center.status.rawValue))
                        .font(.headline).accessibilityIdentifier("creatorContent.status")
                    if let name = center.creatorName { Text(verbatim: name) }
                    if let bio = center.bio { Text(verbatim: bio).foregroundStyle(.secondary) }
                    if center.status == .rejected {
                        if let reason = center.rejectReason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(verbatim: reason) }
                        else { Text("creatorContent.noReason") }
                        Text("creatorContent.reapplyBlocked")
                    }
                }
                if let publisherContext {
                    CreatorApplicationHostLink(context: publisherContext, status: center.status, refreshCenter: { Task { await refresh() } })
                }
                if center.status == .approved {
                    Section("creatorContent.metrics") {
                        metric("creatorContent.contents", center.metric?.contentCount)
                        metric("creatorContent.views", center.metric?.viewCount)
                        metric("creatorContent.likes", center.metric?.likeCount)
                    }
                    Section("creatorContent.income") {
                        if center.recentIncome.isEmpty { Text("creatorContent.noIncome") }
                        ForEach(Array(center.recentIncome.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: row.amount ?? "—").monospacedDigit()
                                if let source = row.source { Text(verbatim: source).font(.subheadline).foregroundStyle(.secondary) }
                                if let date = row.date { Text(verbatim: date).font(.subheadline).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                if let creatorStudio { CreatorStudioEntrySection(service: creatorStudio, reader: reader) }
                Text("creatorContent.centerReadOnly").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .cyDomainScreen(.topicEditor)
        .cyHideTabBar(true)
        .appNavigationTitle("creatorContent.center").navigationBarTitleDisplayMode(.inline)
        .modifier(CreatorContentReadLifecycle(key: key, refresh: refresh, cancel: model.cancel))
    }
    private func metric(_ title: LocalizedStringKey, _ count: Int?) -> some View { LabeledContent { Text(verbatim: count.map(String.init) ?? "—").monospacedDigit() } label: { Text(title) } }
    private func issue(_ value: CreatorContentIssue) -> some View { CreatorContentIssueView(issue: value) { Task { await refresh() } } }
    private func refresh() async {
        guard reader.isAuthenticated, reader.isConfigured else { model.clear(); return }
        await model.load(reader: reader) { try await reader.center() }
    }
}

struct CreatorContentReadLifecycle: ViewModifier {
    let key: CreatorContentLoadKey
    let refresh: () async -> Void
    let cancel: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var needsRefresh = false
    func body(content: Content) -> some View {
        content
            .task(id: key) { await refresh() }
            .refreshable { await refresh() }
            .onAppear { visible = true; needsRefresh = false }
            .onDisappear { visible = false; cancel() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { needsRefresh = true }
                else if phase == .active, visible, needsRefresh {
                    needsRefresh = false
                    Task { await refresh() }
                }
            }
    }
}
