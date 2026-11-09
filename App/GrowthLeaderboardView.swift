import SwiftUI

@MainActor struct GrowthLeaderboardView: View {
    let reader: any GrowthCenterReading
    @Environment(\.cyPalette) private var palette
    @Environment(\.growthExploreHomeAction) private var onExploreHome
    @Environment(\.scenePhase) private var scenePhase
    private var reads: GrowthNormalReadTask { model.overviewReads }
    @State private var query = GrowthBoardQuery()
    @State private var explorePresentationID = UUID()
    @State private var exploreVisible = false
    @State private var exploreConsumed = false
    @State private var latestReaderID: ObjectIdentifier?
    @StateObject private var model = GrowthCenterScreenModel<GrowthLeaderboard>()
    private var key: GrowthCenterLoadKey { GrowthCenterLoadKey(scope: reader.scope, query: query) }
    var body: some View {
        List {
            Section { CYHeroHeader("growth.board.title") }.listRowBackground(Color.clear)
            if reader.isOfflineExample { Text("growth.offlineExample").font(CYTypography.caption).foregroundStyle(palette.textSecondary) }
            Section {
                Picker("growth.board.metric", selection: $query.metric) {
                    ForEach(GrowthBoardMetric.allCases) { option in Text(LocalizedStringKey("growth.metric." + option.rawValue)).tag(option) }
                }.pickerStyle(.segmented).accessibilityIdentifier("growth.board.metric")
                Picker("growth.board.period", selection: $query.period) {
                    ForEach(GrowthBoardPeriod.allCases) { option in Text(LocalizedStringKey("growth.period." + option.rawValue)).tag(option) }
                }.pickerStyle(.segmented).accessibilityIdentifier("growth.board.period")
            }
            if !reader.isAuthenticated { GrowthCenterIssueView(issue: .login) }
            else if !reader.isConfigured { GrowthCenterIssueView(issue: .notConfigured) }
            else if model.isLoading || model.loadedKey != key { CYSkeleton().accessibilityLabel(Text("growth.loading")) }
            else if let issue = model.issue(key: key) {
                if issue == .notConfigured { GrowthNormalLeaderboardHoldView() }
                else { GrowthCenterIssueView(issue: issue, retry: reload) }
            }
            else if let board = model.value(key: key) {
                if let rank = board.me.rank {
                    Section("growth.myRank") { GrowthLeaderboardRow(entry: board.me, fallback: "growth.me", metric: board.metric, isMe: true).accessibilityIdentifier("growth.board.me.\(rank)") }
                }
                if board.list.isEmpty {
                    VStack(spacing: CYSpacing.md) {
                        CYEmptyState(systemImage: "list.number", "growth.board.empty")
                        Text("growth.board.emptyHint")
                            .font(CYTypography.body)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                        if let onExploreHome {
                            let selection = GrowthLeaderboardExploreSelection(readerID: ObjectIdentifier(reader), key: key,
                                board: board, presentationID: explorePresentationID)
                            CYPillButton("growthExplore.openHome") {
                                guard !exploreConsumed, scenePhase == .active,
                                      selection.accepts(readerID: latestReaderID, key: key, board: model.value(key: key),
                                          presentationID: explorePresentationID, visible: exploreVisible,
                                          authenticated: reader.isAuthenticated, configured: reader.isConfigured,
                                          loading: model.isLoading, hasIssue: model.issue(key: key) != nil) else { return }
                                exploreConsumed = true; explorePresentationID = UUID()
                                onExploreHome()
                            }
                            .disabled(exploreConsumed || !exploreVisible || scenePhase != .active)
                            .accessibilityIdentifier("growthExplore.openHome")
                        }
                    }
                    .accessibilityIdentifier("growth.board.empty")
                } else {
                    Section("growth.board.leaders") {
                        ForEach(Array(board.list.enumerated()), id: \.offset) { index, row in
                            GrowthLeaderboardRow(entry: row, fallback: "growth.explorer", metric: board.metric, place: index < 3 ? index + 1 : nil)
                                .accessibilityIdentifier("growth.board.row.\(index)")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).cyDomainPageBackground()
        .appNavigationTitle("growth.board.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: reload) { Label("growth.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.isLoading || !reader.isAuthenticated || !reader.isConfigured)
                    .accessibilityIdentifier("growth.board.refresh")
            }
        }
        .modifier(GrowthCenterReadLifecycle(key: key, refresh: load, cancel: model.cancelPending))
        .onAppear { exploreVisible = true; exploreConsumed = false; explorePresentationID = UUID(); latestReaderID = ObjectIdentifier(reader) }
        .onDisappear { exploreVisible = false; explorePresentationID = UUID() }
        .onChange(of: scenePhase) { _, _ in explorePresentationID = UUID() }
        .onChange(of: ObjectIdentifier(reader)) { _, value in latestReaderID = value; explorePresentationID = UUID() }
    }
    private func reload() { reads.start { await readLeaderboard() } }
    private func load() async { await reads.run { await readLeaderboard() } }
    private func readLeaderboard() async {
        explorePresentationID = UUID(); exploreConsumed = false; latestReaderID = ObjectIdentifier(reader)
        guard reader.isAuthenticated, reader.isConfigured else { model.invalidate(); return }
        let captured = key, requested = query
        await model.load(key: captured, currentKey: { key }) { try await reader.leaderboard(query: requested) }
    }
}

/// A current successful empty-board presentation only. It carries no outbound
/// player/rank data; the action is the host's existing zero-argument home route.
struct GrowthLeaderboardExploreSelection {
    let readerID: ObjectIdentifier
    let key: GrowthCenterLoadKey
    let board: GrowthLeaderboard
    let presentationID: UUID
    func accepts(readerID: ObjectIdentifier?, key: GrowthCenterLoadKey, board: GrowthLeaderboard?,
                 presentationID: UUID, visible: Bool, authenticated: Bool, configured: Bool,
                 loading: Bool, hasIssue: Bool) -> Bool {
        visible && authenticated && configured && !loading && !hasIssue &&
            self.readerID == readerID && self.key == key && self.presentationID == presentationID &&
            self.board.list.isEmpty && self.board == board
    }
}
private struct GrowthLeaderboardRow: View {
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: GrowthLeaderboardEntry
    let fallback: LocalizedStringKey
    let metric: GrowthBoardMetric
    var place: Int? = nil
    var isMe = false
    var body: some View {
        // Mini-program order: rank, name, trailing score + unit. One tappable-height row;
        // at accessibility sizes the score drops under the name instead of squeezing it.
        let stacked = dynamicTypeSize.isAccessibilitySize
        HStack(alignment: stacked ? .top : .center, spacing: 12) {
            Group {
                if let place { GrowthPodiumMark(place: place) }
                else if let rank = entry.rank { Text(rank, format: .number).monospacedDigit() }
                else { Text("growth.unranked") }
            }
            .font(.headline).foregroundStyle(palette.textTertiary)
            .frame(minWidth: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    GrowthCenterName(name: entry.nickname, fallback: fallback).font(.headline)
                        .foregroundStyle(palette.textPrimary).lineLimit(2)
                    if isMe { CYStatusChip("growth.board.meTag") }
                }
                if let percentage = GrowthCenterFormatting.nonempty(entry.rankPercentage) {
                    Text(verbatim: percentage).font(.caption).foregroundStyle(palette.textSecondary)
                }
                if stacked { score(alignment: .leading) }
            }
            if !stacked {
                Spacer(minLength: 8)
                score(alignment: .trailing)
            }
        }.accessibilityElement(children: .combine).padding(.vertical, CYSpacing.xs)
            .cyDomainCard(padding: CYSpacing.md)
    }
    private func score(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            GrowthCenterInteger(value: entry.score).font(.headline).foregroundStyle(palette.textPrimary)
            Text(LocalizedStringKey("growth.unit." + metric.rawValue)).font(.caption).foregroundStyle(palette.textSecondary)
        }
    }
}

struct GrowthPodiumMark: View {
    @Environment(\.cyPalette) private var palette
    let place: Int
    private var tint: Color { place == 1 ? palette.warning : place == 2 ? palette.textSecondary : palette.textTertiary }
    private var label: LocalizedStringKey { place == 1 ? "growth.board.podium.first" : place == 2 ? "growth.board.podium.second" : "growth.board.podium.third" }
    var body: some View {
        Image(systemName: "medal.fill").foregroundStyle(tint)
            .accessibilityLabel(Text(label))
    }
}
