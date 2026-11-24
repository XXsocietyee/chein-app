import SwiftUI

/// Separate public-topic list. It does not reuse governance authority, sessions,
/// reporting, group codes or management destinations from the calendar.
@MainActor struct ClubPublicActivityListView: View {
    let clubID: Int
    @ObservedObject var session: AppSession
    var onSignIn: (() -> Void)? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cyPalette) private var palette
    @StateObject private var model = ClubPublicActivityListModel()
    @State private var visible = false
    @State private var destination: ClubPublicTopicDestination?
    @State private var opening: UUID?
    @State private var selectedUnavailable = false
    /// Dedicated injected source; absence never borrows membership or governance approval.
    var source: ClubPublicTopicsReader? = nil
    private var scope: ClubPublicTopicsScope? { source?.scope(clubID: clubID) }
    private struct ReadKey: Hashable {
        let clubID: Int
        let sourceID: ObjectIdentifier?
        let scope: ClubPublicTopicsScope?
        let visible: Bool
        let foreground: Bool
    }
    private var readKey: ReadKey {
        .init(clubID: clubID, sourceID: source.map { ObjectIdentifier($0) }, scope: scope,
              visible: visible, foreground: scenePhase == .active)
    }
    private var accepted: ClubPublicTopicsSnapshot? {
        guard let source, let snapshot = model.snapshot, snapshot.scope == scope,
              source.isCurrent(snapshot), snapshot.scope.approval.clubID == clubID else { return nil }
        return snapshot
    }
    /// CLB-detail-02: the club page's 活动 tab embeds the list (MP detail wxml:163-216). The host owns the push.
    var embedded: ((Int) -> Void)? = nil
    var body: some View {
        if embedded != nil { embeddedBody } else { pageBody }
    }
    /// Current activities only (P-14: the MP no longer lists ended ones on the club page).
    private var embeddedBody: some View {
        Group {
            // The lifecycle lives on one stable zero-height row. Inside the club page's List a Group's modifiers sit on
            // each child, so on the state rows every loading → content swap fired onDisappear (suspend, snapshot dropped)
            // and onAppear (re-read) in a loop, and the first, empty state never appeared at all (combined-r5 verify,
            // CLB-detail-02: the 活动 tab stayed blank, then hung).
            Section {
                Color.clear.frame(height: 0)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .accessibilityHidden(true)
                    .task(id: readKey) {
                        // A zero-height List row may not report onAppear; .task runs only while the row is mounted.
                        // readKey includes visible, so this restarts once with the visible key.
                        if !visible { visible = true; return }
                        guard scenePhase == .active else { return }
                        await refresh()
                    }
                    .onAppear { visible = true }
                    .onDisappear { visible = false; opening = nil; model.suspend(keepingSnapshot: false) }
                    .onChange(of: scope) { _, _ in opening = nil; selectedUnavailable = false; model.retire() }
                    .onChange(of: scenePhase) { _, phase in
                        if phase != .active { opening = nil; selectedUnavailable = false; model.retire() }
                    }
            }
            // No issued reader, or a reader whose session no longer matches the scope (the grant is not issued in this
            // build, or the E2E host override), reads as unavailable, not as an endless loading row.
            if scope == nil || source == nil || source?.scope(clubID: clubID) != scope {
                Section {
                    CYEmptyState(systemImage: "lock.slash", "publicTopics.unavailable", tableName: "ClubPublicTopics", messageIdentifier: "club.publicTopics.unavailable")
                }
            } else if let snapshot = accepted, !model.loading {
                let renderedSnapshotID = model.snapshotID
                let rows = snapshot.rows.filter { $0.status != .ended }
                if rows.isEmpty {
                    Section {
                        CYEmptyState(systemImage: "calendar", "club.detail.events.empty", messageIdentifier: "club.detail.events.empty")
                            .listRowBackground(Color.clear)
                    }
                } else {
                    ClubActivityListContent(rows: rows, canOpen: visible && scenePhase == .active && opening == nil, open: { row in
                        select(row, from: snapshot, snapshotID: renderedSnapshotID)
                    })
                }
            } else if !model.loading, model.issueScope == scope, let issue = model.issue {
                issueSection(issue)
            } else {
                Section { activityLoading }
            }
        }
    }
    private var pageBody: some View {
        List {
            Section {
                CYHeroHeader("publicTopics.title", tableName: "ClubPublicTopics") {
                    ClubCloud14Banner(seed: "public-topics-\(clubID)", symbol: "list.bullet.rectangle")
                }
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                Text("publicTopics.scope", tableName: "ClubPublicTopics")
                    .cyText(.meta).foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !session.clubIdentity.isSignedIn {
                    Text("publicTopics.guestHandoff", tableName: "ClubPublicTopics")
                        .cyText(.meta).foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if selectedUnavailable {
                CYStatusChip(verbatim: topicsCopy("publicTopics.removed"), tone: .warning, systemImage: "eye.slash")
                    .accessibilityIdentifier("club.publicTopics.selectionRevoked")
            }
            if scope == nil {
                CYEmptyState(systemImage: "lock.slash", "publicTopics.unavailable", tableName: "ClubPublicTopics", messageIdentifier: "club.publicTopics.unavailable")
            } else if model.loading {
                activityLoading
            } else if let snapshot = accepted {
                let renderedSnapshotID = model.snapshotID
                ClubActivityListContent(rows: snapshot.rows, canOpen: visible && scenePhase == .active && opening == nil, open: { row in
                    select(row, from: snapshot, snapshotID: renderedSnapshotID)
                })
            } else if model.issueScope == scope, let issue = model.issue {
                issueSection(issue)
            }
        }
        .scrollContentBackground(.hidden).cyDomainPageBackground()
        .cyGroupedSurface()
        .cyHeroScreen()
        .cyHideTabBar()
        .refreshable { await refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("club.refresh", systemImage: "arrow.clockwise") { Task { await refresh() } }
                    .disabled(model.loading || scope == nil || !visible || scenePhase != .active)
                    .accessibilityIdentifier("club.publicTopics.refresh")
            }
        }
        .navigationDestination(item: $destination) { target in
            if current(target) {
                VStack(spacing: 0) {
                    // The existing ordinary detail owns its own auth/content gates.
                    // A list response is not a content-read or purchase entitlement.
                    SessionTopicDetailView(id: target.topicID, session: session)
                    if !session.clubIdentity.isSignedIn, let onSignIn {
                        CYPillButton("club.signIn", style: .secondary, action: onSignIn)
                            .padding(CYSpacing.pageHorizontal)
                            .padding(.bottom, CYSpacing.lg)
                            .accessibilityIdentifier("club.publicTopics.detail.signIn")
                    }
                }.id(target.id)
            } else {
                Color.clear.onAppear { if destination?.id == target.id { destination = nil } }
            }
        }
        .task(id: readKey) {
            guard visible, scenePhase == .active else { return }
            await refresh()
        }
        .onAppear { visible = true }
        .onDisappear {
            visible = false; opening = nil
            // Pushing an ordinary detail must not remove its source route. Back
            // triggers a new read; outstanding callbacks are still cancelled now.
            model.suspend(keepingSnapshot: destination != nil)
        }
        .onChange(of: scope) { _, _ in destination = nil; opening = nil; selectedUnavailable = false; model.retire() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { destination = nil; opening = nil; selectedUnavailable = false; model.retire() }
        }
        .cyDomainScreen(.player)
    }
    private func refresh() async {
        guard visible, scenePhase == .active, let source, let scope else { return }
        destination = nil; opening = nil; selectedUnavailable = false
        _ = await model.load(source: source, clubID: clubID, scope: scope)
    }
    private func select(_ row: ClubActivityRow, from snapshot: ClubPublicTopicsSnapshot, snapshotID: UUID) {
        guard visible, scenePhase == .active, destination == nil, opening == nil, !model.loading,
              snapshotID == model.snapshotID, accepted == snapshot, snapshot.rows.contains(row),
              let source, scope == snapshot.scope else { return }
        let ticket = UUID(); opening = ticket; selectedUnavailable = false
        Task {
            defer { if opening == ticket { opening = nil } }
            // A fresh original list validates that the real ID is still visible.
            // Never reopen a removed/hidden topic from an old card after revocation.
            guard let fresh = await model.load(source: source, clubID: clubID, scope: snapshot.scope),
                  opening == ticket, visible, scenePhase == .active, destination == nil, accepted == fresh else { return }
            guard fresh.rows.contains(where: { $0.id == row.id }) else { selectedUnavailable = true; return }
            if let embedded { embedded(row.id); return }
            destination = .init(topicID: row.id, scope: fresh.scope, snapshotID: model.snapshotID)
        }
    }
    private func current(_ target: ClubPublicTopicDestination) -> Bool {
        guard scenePhase == .active, target.snapshotID == model.snapshotID,
              let snapshot = accepted, snapshot.scope == target.scope else { return false }
        return snapshot.rows.contains { $0.id == target.topicID }
    }
    @Environment(\.locale) private var locale
    private func topicsCopy(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "ClubPublicTopics", locale: locale))
    }
    private var activityLoading: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYSkeleton().accessibilityHidden(true)
            Text("club.loading").cyText(.meta).foregroundStyle(palette.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("club.publicTopics.loading")
    }
    @ViewBuilder private func issueSection(_ issue: ClubLoadIssue) -> some View {
        Section {
            CYStatusChip(verbatim: String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: issue.titleKey), locale: locale)), tone: .danger, systemImage: "exclamationmark.triangle")
                .accessibilityIdentifier("club.publicTopics.error")
            if let message = issue.message {
                Text(verbatim: message).cyText(.body).foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(LocalizedStringKey(issue.hintKey)).cyText(.body).foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if issue.needsSignIn, let onSignIn {
                CYPillButton("club.signIn", systemImage: "person.crop.circle", action: onSignIn)
            }
            CYPillButton("action.retry", style: issue.needsSignIn ? .secondary : .primary, systemImage: "arrow.clockwise") { Task { await refresh() } }
                .accessibilityIdentifier("club.publicTopics.retry")
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
    }
}

/// Slim generated cover. The page title stays in `CYHeroHeader`, below the art.
private struct ClubCloud14Banner: View {
    let seed: String
    var symbol: String? = nil
    var body: some View {
        Color.clear
            .aspectRatio(2.4, contentMode: .fit)
            .overlay { CYCoverArt(seed: seed, symbol: symbol) }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct ClubPublicTopicDestination: Hashable, Identifiable {
    let topicID: Int
    let scope: ClubPublicTopicsScope
    let snapshotID: UUID
    var id: String { "\(snapshotID.uuidString):\(topicID)" }
}

@MainActor private final class ClubPublicActivityListModel: ObservableObject {
    @Published private(set) var snapshot: ClubPublicTopicsSnapshot?
    @Published private(set) var snapshotID = UUID()
    @Published private(set) var issue: ClubLoadIssue?
    @Published private(set) var issueScope: ClubPublicTopicsScope?
    @Published private(set) var loading = false
    private var generation: UInt64 = 0
    private var active = false
    private var task: Task<ClubPublicTopicsSnapshot, Error>?
    func suspend(keepingSnapshot: Bool) {
        active = false; generation &+= 1; task?.cancel(); task = nil; loading = false
        if !keepingSnapshot { snapshot = nil; snapshotID = UUID(); issue = nil; issueScope = nil }
    }
    func retire() { suspend(keepingSnapshot: false) }
    func load(source: ClubPublicTopicsReader, clubID: Int, scope: ClubPublicTopicsScope) async -> ClubPublicTopicsSnapshot? {
        guard source.scope(clubID: clubID) == scope, !Task.isCancelled else { return nil }
        task?.cancel(); generation &+= 1
        let revision = generation
        active = true; snapshot = nil; snapshotID = UUID(); issue = nil; issueScope = nil; loading = true
        func isCurrent() -> Bool {
            active && generation == revision && source.scope(clubID: clubID) == scope
        }
        let work = Task { try await source.read(clubID: clubID, isCurrent: isCurrent) }
        task = work
        defer { if generation == revision { loading = false; task = nil } }
        do {
            let result = try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() })
            guard !Task.isCancelled, isCurrent(), source.isCurrent(result), result.scope == scope else { return nil }
            snapshot = result
            return result
        } catch is CancellationError { return nil }
        catch {
            guard !Task.isCancelled, isCurrent() else { return nil }
            snapshot = nil; issue = ClubLoadIssue(error); issueScope = scope
            return nil
        }
    }
}
