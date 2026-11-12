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
    private var metricChips: some View {
        GrowthBoardChips(title: "growth.board.metric", selection: $query.metric, options: GrowthBoardMetric.allCases) { "growth.metric." + $0.rawValue }
            .accessibilityIdentifier("growth.board.metric")
    }
    var body: some View {
        List {
            if reader.isOfflineExample { Text("growth.offlineExample").font(CYTypography.caption).foregroundStyle(palette.textSecondary) }
            // Mini-program order: 周榜 / 总榜 chips first; 积分榜 / 成长榜 chips sit between the podium and the rows.
            Section {
                GrowthBoardChips(title: "growth.board.period", selection: $query.period, options: GrowthBoardPeriod.allCases) { "growth.period." + $0.rawValue }
                    .accessibilityIdentifier("growth.board.period")
                if model.value(key: key)?.list.isEmpty != false { metricChips }
            }
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
            if !reader.isAuthenticated { GrowthCenterIssueView(issue: .login) }
            else if !reader.isConfigured { GrowthCenterIssueView(issue: .notConfigured) }
            else if model.isLoading || model.loadedKey != key { CYSkeleton().accessibilityLabel(Text("growth.loading")) }
            else if let issue = model.issue(key: key) {
                if issue == .notConfigured { GrowthNormalLeaderboardHoldView() }
                else { GrowthCenterIssueView(issue: issue, retry: reload) }
            }
            else if let board = model.value(key: key) {
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
                    Section {
                        GrowthLeaderboardPodium(entries: Array(board.list.prefix(3)), metric: board.metric)
                        metricChips.frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    Section {
                        ForEach(Array(board.list.enumerated()), id: \.offset) { index, row in
                            if index >= 3 {
                                GrowthLeaderboardRow(entry: row, fallback: "growth.explorer", metric: board.metric)
                                    .accessibilityIdentifier("growth.board.row.\(index)")
                            }
                        }
                        // My own rank closes the list, highlighted, as in the mini-program.
                        if let rank = board.me.rank {
                            GrowthLeaderboardRow(entry: board.me, fallback: "growth.me", metric: board.metric, isMe: true)
                                .accessibilityIdentifier("growth.board.me.\(rank)")
                        }
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
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

/// Mini-program chip pair (周榜 / 总榜, 积分榜 / 成长榜): capsules, the selected one solid.
private struct GrowthBoardChips<Option: Hashable & Identifiable>: View {
    let title: LocalizedStringKey
    @Binding var selection: Option
    let options: [Option]
    let key: (Option) -> String
    init(title: LocalizedStringKey, selection: Binding<Option>, options: [Option], key: @escaping (Option) -> String) {
        self.title = title; self._selection = selection; self.options = options; self.key = key
    }
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            ForEach(options) { option in
                let selected = selection == option
                Button { selection = option } label: {
                    Text(LocalizedStringKey(key(option)))
                        .font(selected ? CYTypography.label.weight(.semibold) : CYTypography.label)
                        .foregroundStyle(selected ? CYColor.textInverse : CYColor.textPrimary)
                        .padding(.horizontal, CYSpacing.lg).frame(minHeight: 44)
                        .background(selected ? CYColor.textPrimary : CYColor.bgElevated, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }
}

/// Mini-program podium: 2 · 1 · 3, initial discs with a rank coin, name, score + unit. Unknown score is an em dash.
private struct GrowthLeaderboardPodium: View {
    let entries: [GrowthLeaderboardEntry]
    let metric: GrowthBoardMetric
    var body: some View {
        HStack(alignment: .bottom, spacing: CYSpacing.md) {
            ForEach([1, 0, 2], id: \.self) { index in
                if index < entries.count { column(entries[index], place: index + 1) }
                else { Color.clear.frame(maxWidth: .infinity) }
            }
        }
        .padding(.vertical, CYSpacing.md)
    }
    private func column(_ entry: GrowthLeaderboardEntry, place: Int) -> some View {
        let side: CGFloat = place == 1 ? 96 : 76
        let tint: Color = place == 1 ? CYNight.lantern : place == 2 ? CYNight.lanternHot : CYNight.ember
        let name = GrowthCenterFormatting.nonempty(entry.nickname)
        return VStack(spacing: CYSpacing.sm) {
            if place == 1 { Image(systemName: "star").foregroundStyle(CYNight.lantern).accessibilityHidden(true) }
            ZStack(alignment: .bottom) {
                Text(verbatim: name.map { String($0.prefix(1)) } ?? "—")
                    .font(.system(size: side * 0.38, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: side, height: side)
                    .background(CYNight.indigo, in: Circle())
                    .overlay(Circle().strokeBorder(tint, lineWidth: 3))
                Text(place, format: .number).font(CYTypography.label.weight(.bold)).foregroundStyle(CYNight.ink0)
                    .frame(width: 28, height: 28).background(tint, in: Circle())
                    .offset(y: 12)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 12)
            GrowthCenterName(name: entry.nickname, fallback: "growth.explorer").font(CYTypography.label.weight(.semibold))
                .foregroundStyle(CYColor.textPrimary).lineLimit(1)
            HStack(spacing: 4) {
                Circle().fill(tint).frame(width: 10, height: 10).accessibilityHidden(true)
                GrowthCenterInteger(value: entry.score).font(.subheadline.weight(.bold)).monospacedDigit()
                    .foregroundStyle(place == 1 ? CYNight.lantern : CYColor.textPrimary)
                Text(LocalizedStringKey("growth.unit." + metric.rawValue)).font(.caption).foregroundStyle(CYColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(place == 1 ? "growth.board.podium.first" : place == 2 ? "growth.board.podium.second" : "growth.board.podium.third"))
        .accessibilityIdentifier("growth.board.row.\(place - 1)")
    }
}
