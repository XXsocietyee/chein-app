import SwiftUI

@MainActor struct GrowthLeaderboardView: View {
    @Environment(\.locale) private var locale
    let reader: any GrowthCenterReading
    @Environment(\.cyPalette) private var palette
    @Environment(\.growthExploreHomeAction) private var injectedExploreHome
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    private var onExploreHome: (() -> Void)? { rootTabSwitch.growthExploreFallback(injectedExploreHome) }
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
            if reader.isOfflineExample { Text("growth.offlineExample").cyText(.caption).foregroundStyle(palette.textSecondary) }
            // Mini-program order: 周榜 / 总榜 chips first; 积分榜 / 成长榜 chips sit between the podium and the rows.
            Section {
                GrowthBoardChips(title: "growth.board.period", selection: $query.period, options: GrowthBoardPeriod.allCases) { "growth.period." + $0.rawValue }
                    .accessibilityIdentifier("growth.board.period")
                if model.value(key: key)?.isAbsentGrowthBoard != false { metricChips }
            }
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
            if !reader.isAuthenticated { GrowthCenterIssueView(issue: .login) }
            else if !reader.isConfigured { GrowthCenterIssueView(issue: .notConfigured) }
            else if model.isLoading || model.loadedKey != key {
                // P10: MP cy-skeleton list ×3, with words saying what loads.
                ProgressView { Text("growth.board.loading") }
                    .frame(maxWidth: .infinity)
            }
            else if let issue = model.issue(key: key) {
                if issue == .notConfigured { GrowthNormalLeaderboardHoldView() }
                // MP leaderboard wxml cy-error: 当前内容无法查看 (denied) / 排行榜加载失败, 重新加载.
                else { GrowthCenterIssueView(issue: issue, retry: reload, failedTitle: "mp.growth.boardFailed", deniedTitle: "mp.growth.boardDenied") }
            }
            else if let board = model.value(key: key) {
                if board.isAbsentGrowthBoard {
                    // MP wxml: !loading && !top3[0] && !rest.length && !me. Text scales with Dynamic Type;
                    // the cy-empty figure is not drawn.
                    VStack(spacing: CYSpacing.md) {
                        Text("growth.board.empty")
                            .cyText(.sectionTitle)
                            .foregroundStyle(palette.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        // LEADER-4: MP 完成一次城市探索即可累计{{unit}} — the unit follows the selected board.
                        Text("growth.board.emptyHint \(appLocalized(String.LocalizationValue(stringLiteral: "growth.unit." + board.metric.rawValue), locale: locale))")
                            .cyText(.body)
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
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
                        GrowthLeaderboardPodiumView(entries: Array(board.list.prefix(3)), metric: board.metric)
                        metricChips.frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    Section {
                        // LEADER-1: the viewer's own row in the list is highlighted, and the closing 我 row is added only
                        // when the viewer is not already listed (matched by memberId).
                        let meID = board.me.memberID
                        let listed = meID != nil && board.list.contains { $0.memberID == meID }
                        ForEach(Array(board.list.enumerated()), id: \.offset) { index, row in
                            if index >= 3 {
                                GrowthLeaderboardRow(entry: row, fallback: "growth.explorer", metric: board.metric,
                                                     isMe: meID != nil && row.memberID == meID)
                                    .accessibilityIdentifier("growth.board.row.\(index)")
                            }
                        }
                        if !listed, let rank = board.me.rank {
                            GrowthLeaderboardRow(entry: board.me, fallback: "growth.me", metric: board.metric, isMe: true)
                                .accessibilityIdentifier("growth.board.me.\(rank)")
                        }
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).cyDomainPageBackground()
        // MP onPullDownRefresh: pull to read again, like the toolbar refresh.
        .refreshable { await load() }
        .appNavigationTitle("growth.board.title")
        .navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
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
/// Top 3 and the rest come from `list`. 我 is absent only when `me.rank` is absent,
/// the same gate as the closing row. A failed read never builds this selection.
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
            self.board.isAbsentGrowthBoard && self.board == board
    }
}
extension GrowthLeaderboard {
    /// Mini-program empty board: no first-place row, no rows after third, and no 我.
    /// `list` is top 3 plus the rest. 我 is the unlisted row, drawn only when `me.rank` exists.
    fileprivate var isAbsentGrowthBoard: Bool { list.isEmpty && me.rank == nil }
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
            // LEADER-5: MP `.gc-row-rank` subtitle size, semibold, secondary.
            .cyText(.cardTitle, monospacedDigit: true).foregroundStyle(palette.textSecondary)
            .frame(minWidth: 28, alignment: .leading)
            GrowthRankedAvatar(entry: entry)
            VStack(alignment: .leading, spacing: 4) {
                let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    GrowthCenterName(name: entry.nickname, fallback: fallback).cyText(.bodyMedium)
                        .foregroundStyle(palette.textPrimary).lineLimit(2)
                    if isMe { CYStatusChip("growth.board.meTag") }
                }
                if let percentage = GrowthCenterFormatting.nonempty(entry.rankPercentage) {
                    Text(verbatim: percentage).cyText(.meta).foregroundStyle(palette.textSecondary)
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
            GrowthCenterInteger(value: entry.score).cyText(.label, weight: .semibold, monospacedDigit: true).foregroundStyle(palette.textPrimary)
            Text(LocalizedStringKey("growth.unit." + metric.rawValue)).cyText(.caption).foregroundStyle(palette.textSecondary)
        }
    }
}

/// LEADER-6: a ranked person's own photo goes through `CYAvatarView`. A missing or non-HTTPS
/// avatar uses the existing leaderboard initial (`GrowthLeaderboardAvatarBadge`, 「匿」 when blank).
private struct GrowthRankedAvatar: View {
    @Environment(\.cyPalette) private var palette
    let entry: GrowthLeaderboardEntry
    var size: CYAvatarSize = .md
    @ScaledMetric(relativeTo: .body) private var scaleFactor: CGFloat = 1

    private var remoteAvatar: URL? {
        guard let raw = GrowthCenterFormatting.nonempty(entry.avatar)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: raw), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty, url.user == nil else { return nil }
        return url
    }

    /// Same clamp as `CYAvatarView`, so the initial stays one disc at every Dynamic Type step.
    private var dimension: CGFloat { size.rawValue * min(max(scaleFactor, 0.85), 1.35) }

    private var monogram: String { GrowthLeaderboardAvatarBadge(entry: entry).monogram }

    private var monogramStyle: CYTextStyle {
        switch size {
        case .lg, .xl: return .sectionTitle
        case .xs, .sm, .md: return .label
        }
    }

    var body: some View {
        Group {
            if let remoteAvatar {
                let name = GrowthCenterFormatting.nonempty(entry.nickname)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? monogram
                CYAvatarView(url: remoteAvatar, name: name, size: size)
            } else {
                Text(verbatim: monogram)
                    .cyText(monogramStyle, weight: .semibold)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: dimension, height: dimension)
                    .background(palette.bgRaised, in: Circle())
            }
        }
        .accessibilityHidden(true)
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

/// Mini-program chip pair (周榜 / 总榜, 积分榜 / 成长榜) on the shared chip tabs.
private struct GrowthBoardChips<Option: Hashable & Identifiable>: View {
    @Environment(\.cyPalette) private var palette
    let title: LocalizedStringKey
    @Binding var selection: Option
    let options: [Option]
    let key: (Option) -> String
    init(title: LocalizedStringKey, selection: Binding<Option>, options: [Option], key: @escaping (Option) -> String) {
        self.title = title; self._selection = selection; self.options = options; self.key = key
    }
    @Environment(\.locale) private var locale
    /// N-GROWTH (r10): a segmented system Picker (MP subpackageP3/leaderboard tab row).
    var body: some View {
        Picker(selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(verbatim: appLocalized(String.LocalizationValue(key(option)), locale: locale)).tag(option)
            }
        } label: { Text(title) }
            .cyAdaptiveSegmented()
            .sensoryFeedback(.selection, trigger: selection)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(title))
    }
}

/// Mini-program podium: 2 · 1 · 3, avatar discs with the existing crown and rings, name, score + unit. Unknown score is an em dash.
private struct GrowthLeaderboardPodiumView: View {
    @Environment(\.cyPalette) private var palette
    let entries: [GrowthLeaderboardEntry]
    let metric: GrowthBoardMetric
    /// a11y-dt r3: the podium place grows with Dynamic Type instead of clipping in a fixed 28 pt circle.
    @ScaledMetric(relativeTo: .caption) private var placeBadge: CGFloat = 28
    @Environment(\.themeDomain) private var themeDomain
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
        // LEADER-6 (MP RING_BG): gold / pale gold / bronze rings for 1 · 2 · 3.
        // N-GROWTH (r10): no hand-mixed RGB. ds-consistency r3 run 50: the shared medal tiers (one podium hue).
        let ring: Color = place == 1 ? CYColor.medalGold : place == 2 ? CYColor.medalSilver : CYColor.medalBronze
        let name = GrowthCenterFormatting.nonempty(entry.nickname)
        return VStack(spacing: CYSpacing.sm) {
            // LEADER-6: MP `gc-crown` star above the first place (decorative).
            if place == 1 {
                Image(systemName: "star.fill").foregroundStyle(ring).accessibilityHidden(true)
            }
            ZStack(alignment: .bottom) {
                GrowthRankedAvatar(entry: entry, size: place == 1 ? .xl : .lg)
                    .overlay(Circle().strokeBorder(ring, lineWidth: 3))
                Text(place, format: .number).cyText(.label, weight: .bold).foregroundStyle(palette.textInverse)
                    .frame(width: placeBadge, height: placeBadge).background(palette.textPrimary, in: Circle())
                    .offset(y: 12)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 12)
            GrowthCenterName(name: entry.nickname, fallback: "growth.explorer").cyText(.label, weight: .semibold)
                .foregroundStyle(palette.textPrimary).cyWrapText(alignment: .center)
            HStack(spacing: 4) {
                // LEADER-5: `dataXL` overflowed a ⅓ column; MP `.gc-num` is label-sized.
                GrowthCenterInteger(value: entry.score).cyText(.numericBody)
                    .foregroundStyle(palette.textPrimary)
                Text(LocalizedStringKey("growth.unit." + metric.rawValue)).cyText(.caption).foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        // LEADER-2: the place is the label; the combined name + score stay as the value.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(place == 1 ? "growth.board.podium.first" : place == 2 ? "growth.board.podium.second" : "growth.board.podium.third"))
        .accessibilityValue(Text(verbatim: (name ?? "—") + "，" + (GrowthCenterFormatting.nonnegative(entry.score).map(String.init) ?? "—") + " ")
                                + Text(LocalizedStringKey("growth.unit." + metric.rawValue)))
        .accessibilityIdentifier("growth.board.row.\(place - 1)")
    }
}
