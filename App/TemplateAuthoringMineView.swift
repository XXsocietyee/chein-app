import SwiftUI

/// Exact TemplateApi own-shelf. This is not the generic MyProjectApi manager.
@MainActor struct TemplateAuthoringMineView: View {
    let coordinator: TemplateAuthoringCoordinator
    let sessionRevision: UInt64
    var memberDetail: ((MemberPlayTemplateID) -> AnyView)? = nil
    var ownerConfiguration: ((MemberPlayTemplateID) -> AnyView)? = nil
    var creatorConsent: ((WorkshopCreatorConsentSelection) -> AnyView)? = nil
    var fixtureSignOut: (() -> Void)? = nil
    /// Query kept from `subpackageMember/mytemplate/mytemplate`. `scope=MERCHANT` is the merchant shelf.
    /// A player link omits it. `id` stays on this page and does not open another screen.
    var linkQuery: [String: String] = [:]
    /// R7-PC-D1-4: set when 我的项目's 模板 tab shows this shelf inline; the host's tab picker leads the list and the
    /// host keeps its own title and chrome.
    var embeddedHeader: AnyView? = nil
    /// mp-states r3: MP myproject cy-empty 还没有模板 · cta 做一个玩法 (`createTemplate` → `pages/publish/template-intro`).
    /// The argument is the shelf scope (`MERCHANT` or nil). Nil: the empty state shows no action.
    var createTemplate: ((String?) -> AnyView)? = nil
    @Environment(\.locale) private var creatorLocale
    @Environment(\.rootSignIn) private var rootSignIn
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @State private var selectedCreatorConsent: WorkshopCreatorConsentSelection?
    @State private var selectedMember: MemberPlayTemplateID?
    @State private var selectedConfiguration: MemberPlayTemplateID?
    @State private var keyword = ""
    @State private var appliedKeyword: String?
    @State private var hasMore = false
    @State private var readMessageKey: String?
    @State private var viewRequest = UUID()
    @State private var rows: [DiscoveryPlayTemplate] = []
    @State private var rowStates: [Int: TemplateOwnShelfStateProjection] = [:]
    @State private var cardFacts: [Int: TemplateOwnShelfCardFacts] = [:]
    @State private var messageKey: String?
    @State private var review: TemplateOwnShelfReview?
    @State private var busy = false
    @State private var locked = true
    @State private var readSnapshot = false
    @State private var toastMessage: LocalizedStringKey?
    @Environment(\.themeDomain) private var themeDomain
    @Environment(\.roleTheme) private var roleTheme
    /// MP `mytemplate` writes `scope=MERCHANT` only for the merchant theme. A player page omits it.
    /// A kept link query with `scope=MERCHANT` selects the same shelf; any other value does not.
    private var shelfOperationScope: String? {
        if linkQuery["scope"] == "MERCHANT" { return "MERCHANT" }
        return (themeDomain == .merchant || roleTheme == .merchant) ? "MERCHANT" : nil
    }
    private var pageDomain: ThemeDomain { shelfOperationScope == "MERCHANT" ? .merchant : .player }
    var body: some View {
        List {
            if let embeddedHeader { Section { embeddedHeader } }
            // PLY-26-3: the title is the bar's inline title. X12: no 刷新 pill next to pull-to-refresh.
            Section {
                // PLY-26-2: the mini-program shelf search is gone. The page stays; the keyword field does not.
                readStateCopy
            }
            ForEach(appliedKeyword == keyword ? rows : []) { row in
                Section {
                    // PLY-26-4: MP card cover (imgUrl, else the title-initial fallback) with the N 次引用 overlay.
                    TemplateMineCover(title: row.title, imageURL: QuestifyCardArtwork.safeURL(row.imgUrl), useNum: row.useNum)
                        .listRowInsets(EdgeInsets())
                    // Mini-program 我的节点玩法 card: title (opens the detail), status and facts, then actions.
                    if let id = MemberPlayTemplateID(rawValue: row.id), memberDetail != nil {
                        Button { selectedMember = id } label: {
                            HStack {
                                Text(verbatim: row.title).font(.headline).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityLabel(Text(verbatim: row.title))
                        .accessibilityIdentifier("memberTemplate.mine.\(row.id)")
                    } else {
                        Text(verbatim: row.title).font(.headline)
                    }
                    if let id = MemberPlayTemplateID(rawValue: row.id), ownerConfiguration != nil {
                        Button { selectedConfiguration = id } label: {
                            Label("templateOwnerConfig.open", systemImage: "slider.horizontal.3")
                        }
                        .accessibilityIdentifier("templateOwnerConfig.open.\(row.id)")
                    }
                    if let id = MemberPlayTemplateID(rawValue: row.id), creatorConsent != nil {
                        Button { selectedCreatorConsent = WorkshopCreatorConsentSelection(source: id) } label: {
                            Label(workshopCreatorLocalized("workshopCreator.open", locale: creatorLocale), systemImage: "person.badge.shield.checkmark")
                        }
                        .accessibilityIdentifier("workshopCreator.open.\(row.id)")
                    }
                    if let text = row.description, !text.isEmpty { Text(verbatim: text).foregroundStyle(.secondary) }
                    let state = rowStates[row.id] ?? .unknown
                    LabeledContent("templateShelfState.personal.title") { Text(LocalizedStringKey(state.personal.rawValue)) }
                        .accessibilityIdentifier("templateShelfState.personal.\(row.id)")
                    LabeledContent("templateShelfState.market.title") { Text(LocalizedStringKey(state.market.rawValue)) }
                        .accessibilityIdentifier("templateShelfState.market.\(row.id)")
                    if let reason = state.marketReason {
                        LabeledContent("templateShelfState.market.feedback") { Text(verbatim: reason).textSelection(.enabled) }
                            .accessibilityIdentifier("templateShelfState.feedback.\(row.id)")
                    }
                    TemplateOwnShelfCardSection(facts: cardFacts[row.id], state: state, rowID: row.id)
                    // PLY-26-1: the marketplace action comes from the mini-program marketView over the server's
                    // review and square columns, never from the personal publishStatus.
                    // PLY-26-4: one ⋯ menu per card (handoff full-member-club: destructive last), 44 pt target.
                    // Both actions still open their own review sheet before anything is sent.
                    Menu {
                        if let market = TemplateOwnShelfMarketPlan(state).action {
                            Button(LocalizedStringKey(market.labelKey)) {
                                prepare(row.id, market.shelfAction, marketStatusTarget: market.statusTarget)
                            }.disabled(!coordinator.canSubmit || locked || busy || !coordinator.rows.contains(row)).accessibilityIdentifier("templateOwnShelf.market.\(row.id)")
                                .disabled(readSnapshot)
                        }
                        Button(role: .destructive) { prepare(row.id, .remove) } label: { Label("templateAuthor.shelf.delete", systemImage: "trash") }
                            .disabled(!coordinator.canSubmit || locked || busy || !coordinator.rows.contains(row)).accessibilityIdentifier("templateAuthor.shelf.delete.\(row.id)")
                            .disabled(readSnapshot)
                    } label: {
                        Label("templateAuthor.shelf.more", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("templateAuthor.shelf.more.\(row.id)")
                }
            }
            if hasMore, appliedKeyword == keyword { loadMoreCopy }
            if appliedKeyword == keyword, let readMessageKey, !Self.replacesReadKey(readMessageKey) {
                Text(LocalizedStringKey(readMessageKey)).accessibilityIdentifier("templateAuthor.shelf.readStatus")
            }
            if appliedKeyword == keyword, let messageKey { Text(LocalizedStringKey(messageKey)).accessibilityIdentifier("templateAuthor.shelf.status") }
        // PLY-26-5: MP `mytemplate` uses theme-merchant for the merchant scope, theme-dark otherwise.
        }.listStyle(.insetGrouped).themeDomain(pageDomain)
            .modifier(TemplateMineChrome(embedded: embeddedHeader != nil, domain: pageDomain))
            .refreshable { await refresh() }
            // Stable typed destination survives invalidation of its source list on push.
            .navigationDestination(item: $selectedMember) { id in
                if let memberDetail { memberDetail(id) }
            }
            .p04LifecycleSurface()
            .navigationDestination(item: $selectedConfiguration) { id in
                if let ownerConfiguration { ownerConfiguration(id) }
            }
            .navigationDestination(item: $selectedCreatorConsent) { selection in
                if let creatorConsent { creatorConsent(selection) }
            }
            .onChange(of: keyword) { _, newValue in
                review = nil
                coordinator.cancelShelfReview()
                // An empty field is a submitted clear. Non-empty drafts stay unapplied.
                guard newValue.isEmpty, appliedKeyword?.isEmpty == false else { return }
                let stamp = viewRequest
                Task { await refreshClearedKeyword(stamp: stamp) }
            }
            .onChange(of: sessionRevision) { _, _ in selectedCreatorConsent = nil }
            .onChange(of: sessionRevision) { _, _ in selectedConfiguration = nil }
            .onChange(of: sessionRevision) { _, _ in selectedMember = nil }
            .onChange(of: selectedMember) { previous, next in
                guard previous != nil, next == nil else { return }
                Task { await refresh() }
            }
            .task(id: sessionRevision) { viewRequest = UUID(); busy = false; rows = []; cardFacts = [:]; review = nil; rowStates = [:]; await refresh() }
            .onDisappear { viewRequest = UUID(); coordinator.shelfReader.leave(); coordinator.leaveShelfScreen(); rows = []; review = nil; busy = false; rowStates = [:]; cardFacts = [:] }
            .cySheet(item: $review, onDismiss: { coordinator.cancelShelfReview() }) { value in
                NavigationStack {
                    Form {
                        Section {
                            if value.action == .remove {
                                Text("templateOwnShelf.delete.title \(value.title)")
                                    .font(.headline)
                                    .accessibilityIdentifier("templateOwnShelf.delete.title")
                                Text("templateOwnShelf.delete.irreversible")
                            } else if let question = Self.marketQuestion(value) {
                                question
                                    .font(.headline)
                                    .accessibilityIdentifier("templateAuthor.shelf.question")
                            } else if value.desiredPublishStatus == 1 {
                                Text("templateAuthor.shelf.addQuestion \(value.title)")
                                    .font(.headline)
                                    .accessibilityIdentifier("templateAuthor.shelf.question")
                            } else {
                                Text("templateAuthor.shelf.removeQuestion \(value.title)")
                                    .font(.headline)
                                    .accessibilityIdentifier("templateAuthor.shelf.question")
                            }
                        }
                        if coordinator.canSimulate { Text("templateAuthor.fixtureNotice") }
                        if coordinator.canSubmit {
                            Section {
                                Button(LocalizedStringKey(coordinator.canSimulate ? "templateAuthor.confirmSimulation" : value.action == .remove ? "templateOwnShelf.delete.confirm" : Self.marketActionLabel(value) ?? (value.desiredPublishStatus == 1 ? "templateAuthor.shelf.addConfirm" : "templateAuthor.shelf.removeConfirm")), role: value.action == .remove || value.marketStatusTarget == 3 ? .destructive : nil) {
                                    busy = true; locked = true
                                    Task {
                                        let stamp = viewRequest
                                        await coordinator.confirmShelf(value)
                                        guard stamp == viewRequest, !Task.isCancelled else { return }
                                        if let done = Self.marketKey(value, "done") {
                                            // Mini-program toast says what happened and how to undo it; only after a verified write.
                                            if coordinator.shelfMessageKey == "templateAuthor.shelf.verified" { toastMessage = LocalizedStringKey(done) }
                                        } else {
                                            toastMessage = value.action == .remove ? "templateOwnShelf.delete.confirm" : (value.desiredPublishStatus == 1 ? "templateAuthor.shelf.addConfirm" : "templateAuthor.shelf.removeConfirm")
                                        }
                                        review = nil
                                        await coordinator.shelfReader.refresh(keyword: keyword)
                                        guard stamp == viewRequest, !Task.isCancelled else { return }
                                        sync(); busy = false
                                    }
                                }.disabled(busy).accessibilityIdentifier("templateAuthor.shelf.confirm")
                            }
                        } else { Text("templateAuthor.unavailable").foregroundStyle(.secondary) }
                    }.navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("templateAuthor.cancel") { coordinator.cancelShelfReview(); review = nil }
                                    .accessibilityIdentifier("templateAuthor.shelf.cancel")
                            }
                            #if DEBUG
                            ToolbarItem(placement: .topBarTrailing) {
                                if let fixtureSignOut {
                                    Button("templateAuthor.fixture.signOut", action: fixtureSignOut)
                                        .accessibilityIdentifier("fixtureTemplate.review.signOut")
                                }
                            }
                            #endif
                        }
                }
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
            .cyToast(message: $toastMessage, tone: .success)
    }
    /// Marketplace review wording (mini-program `tplSubmitMarket` / `tplToggle`); nil for library and delete reviews.
    private static func marketSuffix(_ value: TemplateOwnShelfReview) -> String? {
        switch (value.action, value.marketStatusTarget) {
        case (.marketSubmit, _): return "submit"
        case (.marketStatus, 2?): return "withdraw"
        case (.marketStatus, 3?): return "delist"
        case (.marketStatus, 1?): return "list"
        default: return nil
        }
    }
    private static func marketKey(_ value: TemplateOwnShelfReview, _ kind: String) -> String? {
        marketSuffix(value).map { "templateOwnShelf.market.\(kind).\($0)" }
    }
    private static func marketActionLabel(_ value: TemplateOwnShelfReview) -> String? {
        marketSuffix(value).map { "templateOwnShelf.market.\($0)" }
    }
    private static func marketQuestion(_ value: TemplateOwnShelfReview) -> Text? {
        switch marketSuffix(value) {
        case "submit"?: return Text("templateOwnShelf.market.question.submit \(value.title)")
        case "withdraw"?: return Text("templateOwnShelf.market.question.withdraw \(value.title)")
        case "delist"?: return Text("templateOwnShelf.market.question.delist \(value.title)")
        case "list"?: return Text("templateOwnShelf.market.question.list \(value.title)")
        default: return nil
        }
    }
    private static func replacesReadKey(_ key: String) -> Bool {
        key == "templateAuthor.signIn" || key == "templateAuthor.listUnavailable" || key == "templateAuthor.shelf.empty" || key == "templateAuthor.shelf.moreFailed" || key == "templateOwnShelf.read.denied"
    }
    @ViewBuilder private var readStateCopy: some View {
        if readMessageKey == "templateAuthor.signIn" {
            // MP cy-empty no-permission · 登录: the sign-in sheet opens over this page; no host → no dead button.
            TemplateOwnShelfReadCopy(title: "templateOwnShelf.read.signIn", subtitle: "templateOwnShelf.read.signInHint", action: "templateOwnShelf.read.signInAction",
                                     identifier: "templateOwnShelf.read.signIn", systemImage: "person.crop.circle.badge.questionmark", prominent: true,
                                     perform: rootSignIn.signedOutAction(fallback: rootTabSwitch))
        } else if readMessageKey == "templateOwnShelf.read.denied" || !coordinator.canRead {
            // MP myproject.wxml:110 cy-empty no-permission has no CTA; pull to refresh stays.
            TemplateOwnShelfReadCopy(title: "templateOwnShelf.read.denied", subtitle: "templateOwnShelf.read.deniedHint", systemImage: "lock")
        } else if appliedKeyword == keyword, busy, rows.isEmpty, readMessageKey == nil {
            ProgressView { Text("templateOwnShelf.read.loading") }.frame(maxWidth: .infinity).accessibilityIdentifier("templateOwnShelf.read.loading")
        } else if appliedKeyword == keyword, readMessageKey == "templateAuthor.listUnavailable", rows.isEmpty {
            TemplateOwnShelfReadCopy(title: "templateOwnShelf.read.failed", action: "templateOwnShelf.read.retry", identifier: "templateOwnShelf.read.retry", systemImage: "exclamationmark.triangle") { Task { await refresh() } }
        } else if appliedKeyword == keyword, readMessageKey == "templateAuthor.listUnavailable" {
            Text("templateOwnShelf.read.failedKept").accessibilityIdentifier("templateOwnShelf.read.failedKept")
        } else if appliedKeyword == keyword, readMessageKey == "templateAuthor.shelf.empty" {
            TemplateOwnShelfEmptyState(destination: createTemplate.map { make in make(shelfOperationScope) })
        }
    }
    @ViewBuilder private var loadMoreCopy: some View {
        if busy {
            Text("templateOwnShelf.read.loadingMore").accessibilityIdentifier("templateOwnShelf.read.loadingMore")
        } else if readMessageKey == "templateAuthor.shelf.moreFailed" {
            TemplateOwnShelfReadCopy(title: "templateOwnShelf.read.moreFailed", subtitle: "templateOwnShelf.read.moreFailedHint", action: "templateOwnShelf.read.retry", identifier: "templateAuthor.shelf.loadMore", systemImage: "exclamationmark.triangle", inline: true) { Task { await loadMore() } }
        } else {
            Button { Task { await loadMore() } } label: { Text("templateOwnShelf.read.loadMore") }
                .disabled(busy)
                .accessibilityIdentifier("templateAuthor.shelf.loadMore")
                .accessibilityLabel(Text("templateOwnShelf.read.loadMoreLabel"))
        }
    }
    private func sync() {
        coordinator.synchronizeSession(); coordinator.shelfReader.synchronizeSession()
        rows = coordinator.shelfReader.rows; hasMore = coordinator.shelfReader.hasMore
        rowStates = coordinator.shelfReader.rowStates
        cardFacts = coordinator.shelfReader.cardFacts
        readSnapshot = coordinator.shelfReader.isShowingRefreshSnapshot
        readMessageKey = coordinator.shelfReader.messageKey; messageKey = coordinator.shelfMessageKey; locked = coordinator.shelfLocked
    }
    private func applyShelfScope() {
        let scope = shelfOperationScope
        coordinator.operationScope = scope
        coordinator.shelfReader.operationScope = scope
    }
    private func prepare(_ id: Int, _ action: TemplateOwnShelfAction, marketStatusTarget: Int? = nil) {
        guard !busy, appliedKeyword == keyword, !coordinator.shelfReader.isShowingRefreshSnapshot else { return }
        applyShelfScope()
        coordinator.prepareShelf(templateID: id, action: action, marketStatusTarget: marketStatusTarget); review = coordinator.shelfReview; sync()
    }
    private func loadMore() async {
        guard !busy, appliedKeyword == keyword else { return }
        applyShelfScope()
        let stamp = viewRequest; busy = true; review = nil; coordinator.cancelShelfReview()
        await coordinator.shelfReader.loadMore()
        guard stamp == viewRequest, !Task.isCancelled else { return }
        sync(); busy = false
    }
    private func refreshClearedKeyword(stamp: UUID, refreshUnfiltered: Bool = false) async {
        guard stamp == viewRequest, keyword.isEmpty, !Task.isCancelled else { return }
        // Explicit Clear still refreshes an already-unfiltered shelf. The first
        // refresh rotates viewRequest before suspension, retiring a duplicate listener task.
        guard refreshUnfiltered || appliedKeyword?.isEmpty == false else { return }
        await refresh()
    }
    private func refresh() async {
        guard !busy else { return }
        applyShelfScope()
        appliedKeyword = keyword
        let stamp = UUID(); viewRequest = stamp
        defer {
            if stamp == viewRequest, Task.isCancelled {
                rows = []; hasMore = false; readSnapshot = false; busy = false; rowStates = [:]; cardFacts = [:]
            }
        }
        busy = true; review = nil; hasMore = false; readMessageKey = nil; messageKey = nil
        coordinator.synchronizeSession(); coordinator.cancelShelfReview()
        rows = coordinator.shelfReader.refreshSnapshot(keyword: keyword)
        rowStates = rows.isEmpty ? [:] : coordinator.shelfReader.rowStates
        cardFacts = rows.isEmpty ? [:] : coordinator.shelfReader.cardFacts
        readSnapshot = !rows.isEmpty
        await coordinator.shelfReader.refresh(keyword: keyword)
        guard stamp == viewRequest, !Task.isCancelled else { return }
        // Preserve the independent, unfiltered first-100 write preflight and reconciliation.
        if coordinator.canSubmit { await coordinator.loadMine() }
        guard stamp == viewRequest, !Task.isCancelled else { return }
        sync(); busy = false
    }
}

/// Read-state wording for 我的节点玩法. The action closure is an existing read; login has none.
/// mp-states r3: one shelf state pattern. Full-list states are a system `ContentUnavailableView` (MP cy-empty /
/// cy-error: title, sub, one CTA); the load-more failure under the rows stays an inline row. An action without a
/// handler renders nothing (no dead 登录 text).
private struct TemplateOwnShelfReadCopy: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var action: LocalizedStringKey? = nil
    var identifier: String? = nil
    let systemImage: String
    var prominent: Bool = false
    var inline: Bool = false
    var perform: (() -> Void)? = nil
    var body: some View {
        if inline {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
                actionButton
            }
        } else {
            ContentUnavailableView {
                Label { Text(title) } icon: { Image(systemName: systemImage) }
            } description: {
                if let subtitle { Text(subtitle) }
            } actions: {
                actionButton
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }
    @ViewBuilder private var actionButton: some View {
        if let action, let perform {
            if prominent {
                Button(action: perform) { Text(action) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(identifier ?? "templateOwnShelf.read.action")
            } else {
                Button(action: perform) { Text(action) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(identifier ?? "templateOwnShelf.read.action")
            }
        }
    }
}

/// MP `subpackageA/pages/myproject/index.wxml:114` cy-empty 还没有模板 · cta 做一个玩法 → template intro.
private struct TemplateOwnShelfEmptyState: View {
    let destination: AnyView?
    var body: some View {
        ContentUnavailableView {
            Label { Text("templateOwnShelf.read.empty") } icon: { Image(systemName: "square.stack.3d.up") }
        } description: {
            Text("templateOwnShelf.read.emptyHint")
        } actions: {
            if let destination {
                NavigationLink { destination } label: { Text("templateOwnShelf.read.create") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("templateOwnShelf.read.create")
            }
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .accessibilityIdentifier("templateOwnShelf.read.empty")
    }
}

/// PLY-26-4: MP `item-pic` (mytemplate.wxml:18-32 before retirement): gradient + first character of the title, the
/// https cover on top when it loads, and `{useNum} 次引用` bottom-left. The ★ rating is not decoded yet (Core).
private struct TemplateMineCover: View {
    let title: String
    let imageURL: URL?
    let useNum: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color(.secondarySystemFill)
                    .overlay {
                        Text(verbatim: title.first.map(String.init) ?? appLocalized("templateAuthor.mine.coverInitial", locale: Locale.current))
                            .font(.largeTitle.bold()).foregroundStyle(.secondary)
                    }
                if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color.clear }
                    }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 120)
            .clipped()
            if let useNum {
                Text("templateAuthor.mine.useNum \(useNum)")
                    .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                    .padding(.horizontal).padding(.vertical, CYSpacing.sm)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(useNum.map { Text("templateAuthor.mine.useNum \($0)") } ?? Text(verbatim: ""))
        .accessibilityHidden(useNum == nil)
    }
}

/// Standalone shelf: pushed chrome and its own title. Embedded in 我的项目: the host's chrome and title stay.
private struct TemplateMineChrome: ViewModifier {
    let embedded: Bool
    let domain: ThemeDomain
    @ViewBuilder func body(content: Content) -> some View {
        if embedded { content } else { content.cyPushedChrome(domain: domain).cyPageTitle("templateAuthor.mine") }
    }
}
