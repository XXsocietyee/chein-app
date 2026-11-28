import SwiftUI

/// Ordinary composition obtains the existing concrete session reader. An unrelated or stale Roam
/// reader cannot be used to open another account's official participation. The session's existing
/// official-action coordinator is passed through; this view does not build another writer.
@MainActor struct RoamOfficialTasksDestination: View {
    let roamReader: any RoamExperienceReading
    var body: some View {
        if roamReader.isOfflineExample {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting-roam-experience") {
                RoamOfficialTasksFixtureDestination(roamReader: roamReader)
            } else { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.tasks.changed") }
            #else
            CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.tasks.changed")
            #endif
        } else { SessionRoamOfficialTasksDestination(roamReader: roamReader) }
    }
}
@MainActor private struct SessionRoamOfficialTasksDestination: View {
    @EnvironmentObject private var session: AppSession
    let roamReader: any RoamExperienceReading
    var body: some View {
        if ObjectIdentifier(roamReader) == ObjectIdentifier(session.roamExperienceReader), roamReader.identity != nil {
            RoamOfficialTasksView(roamReader: roamReader, reader: session.officialEventReader,
                                  actions: session.officialActionCoordinator)
                .id(session.sessionRevision)
        } else { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.tasks.changed") }
    }
}
/// Foreground visit admission only; the original Core model owns the two-list snapshot.
@MainActor final class RoamOfficialTasksViewModel: ObservableObject {
    let model: RoamOfficialTasksModel
    @Published private var revision = 0
    private var mounted = false
    private var foreground = false
    private var visit = UUID()
    private var work: Task<Void, Never>?
    var isVisible: Bool { mounted && foreground }
    init(roam: any RoamExperienceReading, official: any OfficialEventReading) {
        model = .init(roam: roam, official: official)
        model.onChange = { [weak self] in self?.revision &+= 1 }
    }
    func appear(foreground: Bool) {
        mounted = true; self.foreground = foreground
        retire(preservingSnapshot: false)
        if foreground { model.appear(); readAction()() }
    }
    func disappear(preservingSnapshot: Bool) {
        mounted = false; retire(preservingSnapshot: preservingSnapshot)
    }
    func setForeground(_ value: Bool, preservingSnapshot: Bool) {
        guard foreground != value else { return }
        foreground = value; retire(preservingSnapshot: preservingSnapshot)
        // The pushed detail keeps its original snapshot. Foreground cannot remount
        // or reload this hidden list and revoke the accepted detail target.
        if value && mounted { model.appear(); readAction()() }
    }
    func ownerChanged() {
        retire(preservingSnapshot: false)
        // Preserve the original keyed task's current-owner recovery, but only on
        // the mounted foreground list. A source notification cannot remount it.
        if isVisible { model.appear(); readAction()() }
    }
    private func retire(preservingSnapshot: Bool) {
        visit = UUID(); work?.cancel(); work = nil
        if preservingSnapshot { model.cancelPending() } else { model.invalidate() }
        revision &+= 1
    }
    private func accepts(_ offered: UUID, owner: RoamOfficialTasksOwner) -> Bool {
        isVisible && offered == visit && owner == model.owner && !Task.isCancelled
    }
    func readAction() -> () -> Void {
        let offered = visit, owner = model.owner
        return { [weak self] in
            guard let self, self.accepts(offered, owner: owner) else { return }
            self.work?.cancel()
            self.work = Task { [weak self] in
                guard let self else { return }
                await self.read(offered: offered, owner: owner)
            }
        }
    }
    func refreshAction() -> () async -> Void {
        let offered = visit, owner = model.owner
        return { [weak self] in
            guard let self else { return }
            await self.read(offered: offered, owner: owner)
        }
    }
    private func read(offered: UUID, owner: RoamOfficialTasksOwner) async {
        guard accepts(offered, owner: owner) else { return }
        await model.load()
    }
}
/// One detail factory for the official-task list and the first-discovery tasks card.
@MainActor enum RoamOfficialTaskDetail {
    static func make(eventID: Int, reader: any OfficialEventReading,
                     actions: OfficialActionCoordinator? = nil,
                     onLogin: (() -> Void)? = nil,
                     onOpenRoam: ((Int, String?) -> Void)? = nil) -> OfficialEventDetailView {
        OfficialEventDetailView(id: eventID, reader: reader, actions: actions, onLogin: onLogin, onOpenRoam: onOpenRoam)
    }
}
@MainActor struct RoamOfficialTasksView: View {
    let roamReader: any RoamExperienceReading
    let reader: any OfficialEventReading
    var actions: OfficialActionCoordinator? = nil
    var onLogin: (() -> Void)? = nil
    var onOpenRoam: ((Int, String?) -> Void)? = nil
    var body: some View {
        RoamOfficialTasksContent(roamReader: roamReader, reader: reader, actions: actions, onLogin: onLogin, onOpenRoam: onOpenRoam)
            .id(RoamOfficialTasksOwner(roam: roamReader, official: reader))
    }
}
@MainActor private struct RoamOfficialTasksContent: View {
    @Environment(\.scenePhase) private var scenePhase
    let reader: any OfficialEventReading
    var actions: OfficialActionCoordinator?
    var onLogin: (() -> Void)?
    var onOpenRoam: ((Int, String?) -> Void)?
    @StateObject private var viewModel: RoamOfficialTasksViewModel
    @State private var bucket: OfficialEventBucket = .live
    @State private var keyword = ""
    @State private var target: RoamOfficialTaskTarget?
    init(roamReader: any RoamExperienceReading, reader: any OfficialEventReading,
         actions: OfficialActionCoordinator? = nil, onLogin: (() -> Void)? = nil,
         onOpenRoam: ((Int, String?) -> Void)? = nil) {
        self.reader = reader
        self.actions = actions
        self.onLogin = onLogin
        self.onOpenRoam = onOpenRoam
        _viewModel = StateObject(wrappedValue: .init(roam: roamReader, official: reader))
    }
    private var model: RoamOfficialTasksModel { viewModel.model }
    /// MP `tabs: ['进行中', '即将', '我的']`.
    private static let tabs: [OfficialEventBucket] = [.live, .upcoming, .mine]
    /// MP `summary`: `<tab> · 共 N 个活动`, or the keyword result line while searching.
    private func summary(count: Int) -> Text {
        if query.isSearching { return Text("official.summary.search \(query.trimmedKeyword) \(count)") }
        switch bucket {
        case .live: return Text("official.summary.live \(count)")
        case .upcoming: return Text("official.summary.upcoming \(count)")
        case .ended: return Text("official.summary.ended \(count)")
        case .mine: return Text("official.summary.mine \(count)")
        }
    }
    private var query: OfficialEventBrowseQuery { .init(bucket: bucket, keyword: keyword) }
    var body: some View {
        // Destination sits outside the searchable list. iOS 27 drops a destination that follows
        // the navigation-bar search field, and a list-body swap during the push deinits it.
        Group { taskList }
            .navigationDestination(item: $target) { selection in
                if model.mayRemainOpen(selection) {
                    RoamOfficialTaskDetail.make(eventID: selection.eventID, reader: reader,
                                                actions: actions, onLogin: onLogin, onOpenRoam: onOpenRoam)
                } else { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.tasks.changed") }
            }
            .accessibilityIdentifier("roam.tasks.browser")
            .privacySensitive()
    }
    private var taskList: some View {
        let retry = viewModel.readAction(), refresh = viewModel.refreshAction()
        List {
            if viewModel.isVisible {
            Section {
                // MP scene-roam-task-list `task-tabs`: 进行中 / 即将 / 我的 (no 已结束 tab), shown as one segmented row.
                Picker("official.filter", selection: $bucket) {
                    ForEach(Self.tabs) { value in Text(LocalizedStringKey(value.tabTitleKey)).tag(value) }
                }.cyAdaptiveSegmented().accessibilityIdentifier("roam.tasks.filter")
                OfficialReadOnlyNotice(offline: reader.isOfflineExample)
            }
            if let snapshot = model.snapshot {
                let rows = snapshot.visible(query)
                // MP order: `task-summary` (进行中 · 共 N 个活动), then the stale / refreshing line, then the list.
                Section {
                    summary(count: rows.count)
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("roam.tasks.results")
                }
                if let error = model.error, OfficialScreenIssue(error).isFailed {
                    // MP wxml:11 `task-stale`: one line 活动列表更新失败，请稍后重试 · 重试 above the kept list.
                    if !rows.isEmpty { Section { RoamTasksStaleLine(retry: retry) }.accessibilityIdentifier("roam.tasks.stale") }
                } else if let error = model.error {
                    Section {
                        Text("roam.tasks.stale").cyText(.meta).foregroundStyle(.secondary)
                        OfficialIssueView(issue: .init(error), retry: retry)
                    }.accessibilityIdentifier("roam.tasks.stale")
                } else if model.isLoading {
                    Text("official.refreshing").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("roam.tasks.refreshing")
                }
                Section {
                    if rows.isEmpty, let error = model.error, OfficialScreenIssue(error).isFailed {
                        // MP wxml:10 cy-error 活动列表暂时无法更新 · sub staleError · 重试 (refresh failed, nothing to keep).
                        RoamTasksStaleEmpty(retry: retry)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("roam.tasks.staleEmpty")
                    } else if rows.isEmpty {
                        // MP `cy-empty size="lg"`: tab title (暂无进行中的活动 / 暂无即将开始的活动 / 还没有参与的活动),
                        // sub only while searching (没有找到相关活动 · 换个关键词试试).
                        ContentUnavailableView {
                            Label(LocalizedStringKey(query.emptyTitleKey), systemImage: query.isSearching ? "magnifyingglass" : "flag")
                        } description: {
                            if query.isSearching { Text(LocalizedStringKey(query.emptyDetailKey)) }
                        }
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("roam.tasks.empty")
                    }
                    ForEach(rows) { event in
                        Button {
                            guard viewModel.isVisible, target == nil else { return }
                            target = model.select(eventID: event.id, query: query, renderedSnapshotID: snapshot.id)
                        } label: { OfficialEventCard(event: event) }
                            .buttonStyle(QuestifyCardButtonStyle()).questifyCardListRow()
                            .disabled(model.isLoading)
                            .accessibilityIdentifier("roam.tasks.event.\(event.id)")
                    }
                }
            } else if let error = model.error {
                // MP scene-roam-task-list wxml:6 cy-error 活动列表没能打开 · 重试.
                let issue = OfficialScreenIssue(error)
                Section { OfficialIssueView(issue: issue, retry: retry, label: issue.isFailed ? "roam.tasks.failed" : nil) }
                    .accessibilityIdentifier("roam.tasks.error")
            }
            if model.snapshot == nil, model.isLoading || model.error == nil {
                // MP `cy-skeleton type="card" count="3"` before the first snapshot: the shared loading state with words.
                CYLoadingStateView(rows: 3, label: "official.loading")
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("roam.tasks.loading")
            }
            } else {
                CYLoadingStateView(rows: 3, label: "official.loading")
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("roam.tasks.loading")
            }
        }.cyGroupedSurface().navigationTitle("roam.tasks.title").navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.appear(foreground: scenePhase != .background) }
            .onDisappear { viewModel.disappear(preservingSnapshot: target != nil) }
            .onChange(of: scenePhase) { _, phase in
                // A push reports inactive. Only background retires the list.
                guard phase != .inactive else { return }
                viewModel.setForeground(phase == .active, preservingSnapshot: target != nil)
            }
            .refreshable { await refresh() }
            .cyAnimation(CYMotion.standard, value: bucket)
            .cyHaptic(.selection, trigger: bucket)
            .onChange(of: model.owner) { _, _ in bucket = .live; keyword = ""; target = nil; viewModel.ownerChanged() }
            // MP `task-search` keyword box, always visible above the tabs: the system search field.
            .searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("official.search"))
    }
}
/// MP scene-roam-task-list `task-stale`: 活动列表更新失败，请稍后重试 with 重试 beside it.
private struct RoamTasksStaleLine: View {
    let retry: () -> Void
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Label("roam.tasks.staleLine", systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                retryButton
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("roam.tasks.staleLine", systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.secondary)
                retryButton
            }
        }
    }
    private var retryButton: some View {
        Button(action: retry) {
            Text("official.retry")
                .frame(minHeight: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
        }
            .buttonStyle(.borderless).font(.footnote.weight(.semibold))
            .accessibilityLabel(Text("roam.tasks.staleRetryLabel"))
            .accessibilityIdentifier("roam.tasks.staleRetry")
    }
}
/// MP scene-roam-task-list wxml:10 cy-error 活动列表暂时无法更新 · sub · 重试.
private struct RoamTasksStaleEmpty: View {
    let retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("roam.tasks.staleTitle", systemImage: "exclamationmark.triangle")
        } description: {
            Text("roam.tasks.staleLine")
        } actions: {
            Button("official.retry", action: retry)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("roam.tasks.staleRetry")
        }
    }
}
#if DEBUG
/// Synthetic fixture stays in the already selected offline Roam harness; flags never enable a
/// production reader, endpoint, writer, account or capability.
@MainActor private struct RoamOfficialTasksFixtureDestination: View {
    let roamReader: any RoamExperienceReading
    @State private var official: OfficialFixtureReader
    init(roamReader: any RoamExperienceReading) {
        self.roamReader = roamReader
        let args = ProcessInfo.processInfo.arguments, index = args.firstIndex(of: "--uitesting-roam-tasks-scenario")
        let raw = index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        _official = State(initialValue: OfficialFixtureReader(scenario: raw.flatMap(OfficialFixtureReader.Scenario.init(rawValue:)) ?? .content))
    }
    var body: some View { RoamOfficialTasksView(roamReader: roamReader, reader: official) }
}
#endif
