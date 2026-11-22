import SwiftUI

/// Exact TemplateApi own-shelf. This is not the generic MyProjectApi manager.
@MainActor struct TemplateAuthoringMineView: View {
    let coordinator: TemplateAuthoringCoordinator
    let sessionRevision: UInt64
    var memberDetail: ((MemberPlayTemplateID) -> AnyView)? = nil
    var ownerConfiguration: ((MemberPlayTemplateID) -> AnyView)? = nil
    var creatorConsent: ((WorkshopCreatorConsentSelection) -> AnyView)? = nil
    var fixtureSignOut: (() -> Void)? = nil
    @Environment(\.locale) private var creatorLocale
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
    var body: some View {
        List {
            Section { CYHeroHeader("templateAuthor.mine") }.e1HeroRow()
            Section {
                readStateCopy
                TextField("templateAuthor.shelf.keyword", text: $keyword)
                    .submitLabel(.search)
                    .onSubmit { Task { await refresh() } }
                    .disabled(busy).accessibilityIdentifier("templateAuthor.shelf.keyword")
                if !keyword.isEmpty {
                    CYPillButton("templateAuthor.shelf.clearSearch", style: .tertiary, systemImage: "xmark.circle") {
                        guard !busy else { return }
                        let stamp = viewRequest
                        keyword = ""
                        Task { await refreshClearedKeyword(stamp: stamp, refreshUnfiltered: true) }
                    }.disabled(busy).accessibilityIdentifier("templateAuthor.shelf.clearSearch").e1ActionRow()
                }
                CYPillButton("templateAuthor.shelf.refresh", style: .secondary, systemImage: "arrow.clockwise") { Task { await refresh() } }
                    .disabled(busy).accessibilityIdentifier("templateAuthor.shelf.refresh").e1ActionRow()
            }
            ForEach(appliedKeyword == keyword ? rows : []) { row in
                Section {
                    // Mini-program 我的节点玩法 card: title (opens the detail), status and facts, then actions.
                    if let id = MemberPlayTemplateID(rawValue: row.id), memberDetail != nil {
                        Button { selectedMember = id } label: {
                            HStack {
                                Text(verbatim: row.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityLabel(Text(verbatim: row.title))
                        .accessibilityIdentifier("memberTemplate.mine.\(row.id)")
                    } else {
                        Text(verbatim: row.title).cyText(.cardTitle)
                    }
                    if let id = MemberPlayTemplateID(rawValue: row.id), ownerConfiguration != nil {
                        Button { selectedConfiguration = id } label: {
                            CYListRow("templateOwnerConfig.open") { CYRowIcon(systemImage: "slider.horizontal.3") }
                        }
                        .accessibilityIdentifier("templateOwnerConfig.open.\(row.id)")
                    }
                    if let id = MemberPlayTemplateID(rawValue: row.id), creatorConsent != nil {
                        Button { selectedCreatorConsent = WorkshopCreatorConsentSelection(source: id) } label: {
                            CYListRow(verbatim: workshopCreatorLocalized("workshopCreator.open", locale: creatorLocale)) { CYRowIcon(systemImage: "person.badge.shield.checkmark") }
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
                    LabeledContent("templateAuthor.shelf.libraryTitle") {
                        Text(LocalizedStringKey(row.publishStatus == 1 ? "templateAuthor.shelf.inLibrary" : "templateAuthor.shelf.outLibrary"))
                            .accessibilityIdentifier("templateAuthor.shelf.libraryState.\(row.id)")
                    }
                    Button(LocalizedStringKey(row.publishStatus == 1 ? "templateAuthor.shelf.removeLibrary" : "templateAuthor.shelf.addLibrary")) {
                        prepare(row.id, .libraryStatus)
                    }.disabled(!coordinator.canSubmit || locked || busy || !coordinator.rows.contains(row)).accessibilityIdentifier("templateAuthor.shelf.library.\(row.id)")
                        .disabled(readSnapshot)
                    Button(role: .destructive) { prepare(row.id, .remove) } label: { Text("templateAuthor.shelf.delete").foregroundStyle(.red) }
                        .disabled(!coordinator.canSubmit || locked || busy || !coordinator.rows.contains(row)).accessibilityIdentifier("templateAuthor.shelf.delete.\(row.id)")
                        .disabled(readSnapshot)
                }
            }
            if hasMore, appliedKeyword == keyword { loadMoreCopy }
            if appliedKeyword == keyword, let readMessageKey, !Self.replacesReadKey(readMessageKey) {
                Text(LocalizedStringKey(readMessageKey)).accessibilityIdentifier("templateAuthor.shelf.readStatus")
            }
            if appliedKeyword == keyword, let messageKey { Text(LocalizedStringKey(messageKey)).accessibilityIdentifier("templateAuthor.shelf.status") }
        }.listStyle(.insetGrouped).cyGroupedSurface().cyDomainScreen(.player).cyHeroScreen()
            .refreshable { await refresh() }
            // Stable typed destination survives invalidation of its source list on push.
            .navigationDestination(item: $selectedMember) { id in
                if let memberDetail { memberDetail(id) }
            }
            .p04LifecycleSurface()
            .preferredColorScheme(.dark)
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
            .sheet(item: $review, onDismiss: { coordinator.cancelShelfReview() }) { value in
                NavigationStack {
                    Form {
                        Section {
                            if value.action == .remove {
                                Text("templateOwnShelf.delete.title \(value.title)")
                                    .cyText(.sectionTitle)
                                    .accessibilityIdentifier("templateOwnShelf.delete.title")
                                Text("templateOwnShelf.delete.irreversible")
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
                                Button(LocalizedStringKey(coordinator.canSimulate ? "templateAuthor.confirmSimulation" : value.action == .remove ? "templateOwnShelf.delete.confirm" : value.desiredPublishStatus == 1 ? "templateAuthor.shelf.addConfirm" : "templateAuthor.shelf.removeConfirm"), role: value.action == .remove ? .destructive : nil) {
                                    busy = true; locked = true
                                    Task {
                                        let stamp = viewRequest
                                        await coordinator.confirmShelf(value)
                                        guard stamp == viewRequest, !Task.isCancelled else { return }
                                        toastMessage = value.action == .remove ? "templateOwnShelf.delete.confirm" : (value.desiredPublishStatus == 1 ? "templateAuthor.shelf.addConfirm" : "templateAuthor.shelf.removeConfirm")
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
                .cyDomainSheet(detents: [.half, .full])
            }
            .cyToast(message: $toastMessage, tone: .success)
    }
    private static func replacesReadKey(_ key: String) -> Bool {
        key == "templateAuthor.signIn" || key == "templateAuthor.listUnavailable" || key == "templateAuthor.shelf.empty" || key == "templateAuthor.shelf.moreFailed" || key == "templateOwnShelf.read.denied"
    }
    @ViewBuilder private var readStateCopy: some View {
        if readMessageKey == "templateAuthor.signIn" {
            TemplateOwnShelfReadCopy(title: "templateOwnShelf.read.signIn", subtitle: "templateOwnShelf.read.signInHint", action: "templateOwnShelf.read.signInAction")
        } else if readMessageKey == "templateOwnShelf.read.denied" || !coordinator.canRead {
            TemplateOwnShelfReadCopy(title: "templateOwnShelf.read.denied", subtitle: "templateOwnShelf.read.deniedHint", action: "templateOwnShelf.read.retry", identifier: "templateOwnShelf.read.retry") { Task { await refresh() } }
        } else if appliedKeyword == keyword, busy, rows.isEmpty, readMessageKey == nil {
            CYLoadingStateView(rows: 2).accessibilityLabel(Text("templateOwnShelf.read.loading")).accessibilityIdentifier("templateOwnShelf.read.loading")
        } else if appliedKeyword == keyword, readMessageKey == "templateAuthor.listUnavailable", rows.isEmpty {
            TemplateOwnShelfReadCopy(title: "templateOwnShelf.read.failed", action: "templateOwnShelf.read.retry", identifier: "templateOwnShelf.read.retry") { Task { await refresh() } }
        } else if appliedKeyword == keyword, readMessageKey == "templateAuthor.listUnavailable" {
            Text("templateOwnShelf.read.failedKept").accessibilityIdentifier("templateOwnShelf.read.failedKept")
        } else if appliedKeyword == keyword, readMessageKey == "templateAuthor.shelf.empty" {
            TemplateOwnShelfReadCopy(title: "templateOwnShelf.read.empty", subtitle: "templateOwnShelf.read.emptyHint")
        }
    }
    @ViewBuilder private var loadMoreCopy: some View {
        if busy {
            Text("templateOwnShelf.read.loadingMore").accessibilityIdentifier("templateOwnShelf.read.loadingMore")
        } else if readMessageKey == "templateAuthor.shelf.moreFailed" {
            TemplateOwnShelfReadCopy(title: "templateOwnShelf.read.moreFailed", subtitle: "templateOwnShelf.read.moreFailedHint", action: "templateOwnShelf.read.retry", identifier: "templateAuthor.shelf.loadMore") { Task { await loadMore() } }
        } else {
            CYPillButton("templateOwnShelf.read.loadMore", style: .secondary) { Task { await loadMore() } }
                .disabled(busy).e1ActionRow()
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
    private func prepare(_ id: Int, _ action: TemplateOwnShelfAction) {
        guard !busy, appliedKeyword == keyword, !coordinator.shelfReader.isShowingRefreshSnapshot else { return }
        coordinator.prepareShelf(templateID: id, action: action); review = coordinator.shelfReview; sync()
    }
    private func loadMore() async {
        guard !busy, appliedKeyword == keyword else { return }
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
private struct TemplateOwnShelfReadCopy: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var action: LocalizedStringKey? = nil
    var identifier: String? = nil
    var perform: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(title).cyText(.cardTitle)
            if let subtitle { Text(subtitle).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
            if let action {
                if let perform { CYPillButton(action, style: .secondary, action: perform).accessibilityIdentifier(identifier ?? "templateOwnShelf.read.action").padding(.top, CYSpacing.xs) }
                else { Text(action).cyText(.meta) }
            }
        }
    }
}
