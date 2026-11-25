import SwiftUI

/// Optional ordinary-home navigation supplied by the account host. Nil leaves
/// the read surface usable without pretending to navigate or acquire location.
private struct GrowthExploreHomeActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}
extension EnvironmentValues {
    var growthExploreHomeAction: (() -> Void)? {
        get { self[GrowthExploreHomeActionKey.self] }
        set { self[GrowthExploreHomeActionKey.self] = newValue }
    }
    /// GROWTH-5: the signed-in viewer's own name and avatar (MP `app.getNickname()` / `app.getAvatar()`), set by the
    /// tab root. The growth person row reads it, so it shows even when the rank read fails.
    var growthSessionProfile: GrowthSessionProfile? {
        get { self[GrowthSessionProfileKey.self] }
        set { self[GrowthSessionProfileKey.self] = newValue }
    }
}

struct GrowthSessionProfile: Equatable {
    let name: String?
    /// Carried for when the owner allows the avatar fetch in Growth views; not drawn today.
    let avatar: String?
}
private struct GrowthSessionProfileKey: EnvironmentKey {
    static let defaultValue: GrowthSessionProfile? = nil
}

extension RootTabSwitch {
    /// GROWTH-6 / LEADER-8: an entry that injected no explore action still gets 去探索 when the root tabs can switch.
    @MainActor func growthExploreFallback(_ injected: (() -> Void)?) -> (() -> Void)? {
        if let injected { return injected }
        guard isAvailable else { return nil }
        return { MainActor.assumeIsolated { self(.home) } }
    }
}

@MainActor struct GrowthCenterView: View {
    let reader: any GrowthCenterReading
    @Environment(\.growthExploreHomeAction) private var injectedExploreHome
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.growthSessionProfile) private var sessionProfile
    private var onExploreHome: (() -> Void)? { rootTabSwitch.growthExploreFallback(injectedExploreHome) }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cyPalette) private var palette
    @State private var badgePresentationID = UUID()
    @State private var badgeVisible = false
    @State private var badgeExploreConsumed = false
    @State private var latestReaderID: ObjectIdentifier?
    @State private var unlockTracker = GrowthBadgeUnlockTracker()
    @State private var unlockTrackerKey: GrowthCenterLoadKey?
    @State private var newlyLitBadges: [String] = []
    @State private var celebrations = CYCelebrationCenter()
    @State private var lastKnownLevel: [GrowthCenterLoadKey: Int] = [:]
    /// Design hand-off r1 PL-45: a level increase is a full-screen moment, not a small dialog.
    @State private var levelUp: CYLevelUpPayload?
    private var reads: GrowthNormalReadTask { model.overviewReads }
    @StateObject private var model = GrowthCenterScreenModel<GrowthCenterOverview>()
    private var key: GrowthCenterLoadKey { GrowthCenterLoadKey(scope: reader.scope) }
    var body: some View {
        List {
            if reader.isOfflineExample { Text("growth.offlineExample").cyText(.meta) }
            if !reader.isAuthenticated { GrowthCenterIssueView(issue: .login) }
            else if !reader.isConfigured { GrowthCenterIssueView(issue: .notConfigured) }
            else if model.isLoading || model.loadedKey != key {
                CYSkeleton().padding(.vertical, CYSpacing.sm).accessibilityIdentifier("growth.loading")
            }
            else if let issue = model.issue(key: key) { GrowthCenterIssueView(issue: issue, retry: reload) }
            else if let overview = model.value(key: key) {
                if !newlyLitBadges.isEmpty {
                    Section {
                        HStack(alignment: .top) {
                            Image(systemName: "sparkles").symbolEffect(.bounce, value: newlyLitBadges.count).accessibilityHidden(true)
                            GrowthNewlyLitBadges(names: newlyLitBadges)
                        }
                        // The whole status is one announcement, never the SF Symbol's
                        // default "Sparkle" label instead of the newly earned badge names.
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("growth.badges.newlyLit") + Text(verbatim: ": " + newlyLitBadges.formatted(.list(type: .and))))
                        .accessibilityIdentifier("growth.badges.newlyLit")
                    }
                }
                score(overview)
                footprint(overview)
                badges(overview)
                // B68: the mini-program page ends with 我的徽章; missions, check-ins and streak live on the profile growth card.
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).cyDomainPageBackground()
        .appNavigationTitle("growth.title")
        .navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: reload) { Label("growth.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.isLoading || !reader.isAuthenticated || !reader.isConfigured)
                    .accessibilityIdentifier("growth.refresh")
            }
        }
        .cyCelebrations(celebrations)
        .fullScreenCover(item: $levelUp) { payload in
            CYLevelUpMoment(payload: payload) { levelUp = nil }
                .roleThemedPresentation()
        }
        .modifier(GrowthCenterReadLifecycle(key: key, refresh: load, cancel: model.cancelPending))
        .onAppear { badgeVisible = true; badgeExploreConsumed = false; badgePresentationID = UUID(); latestReaderID = ObjectIdentifier(reader) }
        .onDisappear { badgeVisible = false; badgePresentationID = UUID() }
        .onChange(of: scenePhase) { _, _ in badgePresentationID = UUID() }
        .onChange(of: ObjectIdentifier(reader)) { _, value in latestReaderID = value; badgePresentationID = UUID() }
    }
    @ViewBuilder private func score(_ overview: GrowthCenterOverview) -> some View {
        // B68 gc-score-card: avatar + name, the points on the right, then the 总积分榜 row.
        Section { scoreRows(overview) }
            .listRowBackground(palette.bgElevated)
    }
    @ViewBuilder private func scoreRows(_ overview: GrowthCenterOverview) -> some View {
        Group {
            if let board = overview.rank.value {
                CurA11yPair(
                    leading: person(fallbackName: board.me.nickname),
                    trailing: HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                        GrowthCenterInteger(value: board.me.score).cyText(.data2XL)
                            .foregroundStyle(palette.textPrimary)
                            .cyWrapText()
                        Group { if board.metric == .exp { Text("u10.growth.unit.exp") } else { Text("growth.unit.point") } }
                            .cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("growth.currentPoints"))
                    .accessibilityValue(pointsValue(board.me.score))
                    .accessibilityIdentifier("growth.points")
                )
                .padding(.vertical, CYSpacing.xs)
                leaderboardRow(rank: board.me.rank)
                if let percentage = GrowthCenterFormatting.nonempty(board.me.rankPercentage) { Text(verbatim: percentage).cyText(.meta) }
            } else if let issue = overview.rank.issue {
                // GROWTH-5: the person row does not depend on the rank read.
                if sessionProfile != nil { person(fallbackName: nil).padding(.vertical, CYSpacing.xs) }
                // Own-center points are not leaderboard score/rank and do not fall back
                // to the legacy identity-bearing leaderboard while that producer is HOLD.
                GrowthCenterMetricRow("profile.selfGrowth.points") { GrowthCenterInteger(value: overview.center.value?.points) }
                    .accessibilityIdentifier("growth.normal.points")
                if issue == .notConfigured { GrowthNormalLeaderboardHoldView() }
                // MP growthcenter index.js:337-354: the score card's failure reads 排行榜加载失败.
                else { GrowthCenterIssueView(issue: issue, retry: reload, failedTitle: "mp.growth.boardFailed") }
                if reader.offersLeaderboard { leaderboardRow(rank: nil, showsRank: false) }
            }
        }
    }
    /// gc-score-person: the session's avatar and name first, the rank read's nickname only as a fallback.
    private func person(fallbackName: String?) -> some View {
        let name = GrowthCenterFormatting.nonempty(sessionProfile?.name) ?? GrowthCenterFormatting.nonempty(fallbackName)
        return HStack(spacing: CYSpacing.md) {
            // The avatar image is not fetched here (test_growth_source_contract: no third-party media in Growth views);
            // the session name's initial stands in.
            GrowthProfileDisc(name: name)
            if let name {
                Text(verbatim: name).cyText(.bodyMedium).foregroundStyle(palette.textPrimary).cyWrapText()
            }
        }
    }
    /// 总积分榜 · 第 N 名 (or 总积分榜 when unranked), with 查看榜单 › opening the full board.
    @ViewBuilder private func leaderboardRow(rank: Int?, showsRank: Bool = true) -> some View {
        HStack(spacing: CYSpacing.sm) {
            Group {
                if let rank { Text("u10.growth.boardRank \(rank)") } else { Text("u10.growth.board") }
            }
            .cyText(.body).foregroundStyle(palette.textPrimary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("growth.myRank"))
            .accessibilityValue(rankValue(rank))
            .accessibilityIdentifier(showsRank ? "growth.myRank" : "u10.growth.boardRow")
            Spacer(minLength: CYSpacing.sm)
            if reader.offersLeaderboard {
                NavigationLink { GrowthLeaderboardView(reader: reader) } label: {
                    // GROWTH-9: the List row draws the system disclosure; no hand-made chevron beside it.
                    Text("growth.board.link")
                        .cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                }
                .frame(minHeight: 44).accessibilityIdentifier("growth.openLeaderboard")
            }
        }
        .frame(minHeight: 44)
    }
    private func growthHeader(_ key: LocalizedStringKey) -> some View {
        Text(key).cyText(.sectionTitle).textCase(nil).foregroundStyle(palette.textPrimary).padding(.top, 8)
    }
    /// GROWTH-8 (MP growthcenter index.js:513 `footprintEmpty`): when every read succeeded and every figure is 0,
    /// 我的足迹 is left out instead of a column of zeros. A failed read keeps the section (its issue row explains it).
    static func footprintEmpty(_ overview: GrowthCenterOverview) -> Bool {
        guard let center = overview.center.value, let progress = overview.progress.value, overview.completed.value != nil else { return false }
        let figures: [Double] = [Double(center.experience ?? 0), Double(center.badges.count),
                                 Double(overview.completedTopicCount ?? 0), progress.totalMileage ?? 0]
        return figures.allSatisfy { !$0.isFinite || $0 == 0 }
    }
    @ViewBuilder private func footprint(_ overview: GrowthCenterOverview) -> some View {
        // 我的足迹 in the mini-program order: 探索值, 徽章 (枚), 完成主题 (个), 累计距离 (km); level sits in the header.
        if !Self.footprintEmpty(overview) { Section {
            GrowthCenterMetricRow("growth.experience") { GrowthCenterInteger(value: overview.center.value?.experience) }.accessibilityIdentifier("growth.experience")
            GrowthCenterMetricRow("growth.badgeCount") { growthCount(overview.center.value?.badges.count, unit: "u10.growth.unit.badge") }
                .accessibilityIdentifier("growth.badgeCount")
            GrowthCenterMetricRow("growth.completedTopics") { growthCount(overview.completedTopicCount, unit: "u10.growth.unit.topic") }.accessibilityIdentifier("growth.completedTopics")
            GrowthCenterMetricRow("growth.mileage") {
                if let mileage = GrowthCenterFormatting.mileage(overview.progress.value?.totalMileage) {
                    HStack(spacing: 2) {
                        Text(mileage, format: .number.precision(.fractionLength(0...1))).monospacedDigit()
                        Text(verbatim: "km")   // GROWTH-4: one unit, beside the value (label is 累计距离)
                    }
                } else { Text("growth.unknown").accessibilityLabel(Text("growth.unknownValue")) }
            }.accessibilityIdentifier("growth.mileage")
            // MP index.js:501 overviewError: 部分成长数据暂时不可用.
            if let issue = overview.progress.issue { GrowthCenterIssueView(issue: issue, retry: reload, failedTitle: "mp.growth.overviewFailed") }
            if let issue = overview.completed.issue { GrowthCenterIssueView(issue: issue, retry: reload, failedTitle: "mp.growth.overviewFailed") }
        } header: {
            HStack {
                growthHeader("growth.overview")
                Spacer(minLength: 8)
                if let level = GrowthCenterFormatting.nonnegative(overview.center.value?.level) {
                    Text("growth.level.value \(max(1, level))").monospacedDigit()
                }
            }
        }
        .listRowBackground(palette.bgElevated)
        }
    }
    @ViewBuilder private func growthCount(_ value: Int?, unit: LocalizedStringKey) -> some View {
        if let value = GrowthCenterFormatting.nonnegative(value) {
            HStack(spacing: 2) { Text(value, format: .number).monospacedDigit(); Text(unit) }
        } else { Text("growth.unknown").accessibilityLabel(Text("growth.unknownValue")) }
    }
    @ViewBuilder private func badges(_ overview: GrowthCenterOverview) -> some View {
        Section { badgeRows(overview) } header: {
            HStack {
                growthHeader("growth.badges")
                Spacer(minLength: 8)
                if let count = overview.center.value?.badges.count { Text(count, format: .number).monospacedDigit().foregroundStyle(palette.textSecondary) }
            }
        }
        .listRowBackground(palette.bgElevated)
    }
    @ViewBuilder private func badgeRows(_ overview: GrowthCenterOverview) -> some View {
        Group {
            // MP wxml:69-70 (L09-050): 成长数据没有加载出来 + 重试.
            if let issue = overview.center.issue { GrowthCenterIssueView(issue: issue, retry: reload, failedTitle: "mp.growth.badgesFailed") }
            else if let center = overview.center.value {
                if center.badges.isEmpty {
                    CYEmptyState(systemImage: "star", "growth.badges.empty", messageIdentifier: "growth.badges.empty")
                    if let onExploreHome {
                        let selection = GrowthBadgeExploreSelection(readerID: ObjectIdentifier(reader), key: key,
                            center: center, presentationID: badgePresentationID)
                        Button("growthExplore.openHome") {
                            guard !badgeExploreConsumed, scenePhase == .active,
                                  selection.accepts(readerID: latestReaderID, key: key, center: model.value(key: key)?.center.value,
                                      presentationID: badgePresentationID, visible: badgeVisible,
                                      authenticated: reader.isAuthenticated, configured: reader.isConfigured,
                                      loading: model.isLoading, hasIssue: model.issue(key: key) != nil || model.value(key: key)?.center.issue != nil) else { return }
                            badgeExploreConsumed = true; badgePresentationID = UUID()
                            onExploreHome()
                        }.buttonStyle(.bordered).frame(minHeight: 44)
                            .disabled(badgeExploreConsumed || !badgeVisible || scenePhase != .active)
                            .accessibilityIdentifier("growthExplore.badges.openHome")
                    }
                }
                ForEach(Array(center.badges.enumerated()), id: \.offset) { index, badge in
                    GrowthBadgeMomentRow(badge: badge)
                        .accessibilityIdentifier("growth.badge.\(index)")
                }
            }
        }
    }
    private func pointsValue(_ value: Int?) -> Text {
        if let value = GrowthCenterFormatting.nonnegative(value) { return Text(value, format: .number) }
        return Text("growth.unknownValue")
    }
    private func rankValue(_ rank: Int?) -> Text {
        if let rank { return Text(rank, format: .number) }
        return Text("growth.unranked")
    }
    private func reload() { reads.start { await readOverview() } }
    private func load() async { await reads.run { await readOverview() } }
    private func readOverview() async {
        guard !Task.isCancelled else { return }
        badgePresentationID = UUID(); badgeExploreConsumed = false; latestReaderID = ObjectIdentifier(reader)
        guard reader.isAuthenticated, reader.isConfigured else { model.invalidate(); return }
        let captured = key, presentation = badgePresentationID
        if unlockTrackerKey != captured { unlockTracker.reset(); unlockTrackerKey = captured }
        newlyLitBadges = []
        await model.load(key: captured, currentKey: { key }) { try await reader.overview() }
        // Only a successful center section in the same scope can light a badge; failures keep the baseline.
        guard !Task.isCancelled, captured == key, presentation == badgePresentationID,
              let center = model.value(key: captured)?.center.value else { return }
        if let level = GrowthCenterFormatting.nonnegative(center.level) {
            if let previousLevel = lastKnownLevel[captured], level > previousLevel {
                UIKitHapticsDriver.ensureInstalled()
                HapticsService.shared.play(.levelUp)
                levelUp = CYLevelUpPayload(from: previousLevel, to: level)
            }
            lastKnownLevel[captured] = level
        }
        let lit = unlockTracker.observe(center.badges)
        newlyLitBadges = lit.compactMap(\.displayName)
        // The cover carries its own haptics; the queue plays one badge at a time and dedupes a re-read.
        for badge in lit {
            guard let name = badge.displayName else { continue }
            celebrations.enqueue(.badge(CYBadgePayload(id: GrowthBadgeUnlockTracker.code(badge) ?? name, name: name)))
        }
    }
}

/// Score-card avatar. MP growthcenter wxml:20 is `profile.avatarUrl || '/images/d_profile.png'`; remote avatars are
/// not loaded on Growth screens (third-party media), so the slot always shows the MP default `d_profile` (MP assets).
struct GrowthProfileDisc: View {
    @Environment(\.cyPalette) private var palette
    let name: String?
    @Environment(\.themeDomain) private var themeDomain
    var body: some View {
        MPAsset.AvatarDefault.dProfile
            .resizable()
            .scaledToFill()
            .frame(width: 48, height: 48)
            .background(palette.bgRaised)
            .clipShape(Circle())
            .overlay {
                if themeDomain == .player {
                    Circle().strokeBorder(palette.avatarRing, lineWidth: 2)
                }
            }
            .accessibilityHidden(true)
    }
}

/// gc-badge-row: initial tile, name and the obtained date shown directly (GROWTH-2: MP removed 查看获得时刻 / 查看 / 收起).
struct GrowthBadgeMomentRow: View {
    @Environment(\.cyPalette) private var palette
    let badge: GrowthCenterBadge
    var body: some View {
        HStack(spacing: CYSpacing.md) {
            Text(verbatim: badge.displayName.map { String($0.prefix(1)) } ?? "—")
                .cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 40, minHeight: 40)
                .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                GrowthCenterName(name: badge.displayName, fallback: "growth.badge.unnamed")
                    .cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                Group {
                    if let moment = GrowthCenterFormatting.badgeMoment(badge.obtainedAt) { Text("u10.growth.badge.obtained \(moment)") }
                    else { Text("u10.growth.badge.noTime") }
                }
                .cyText(.meta).foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// Only an explicitly decoded successful center record can establish no badges.
/// Missing/failed center sections never become an empty array or a navigation receipt.
struct GrowthBadgeExploreSelection {
    let readerID: ObjectIdentifier
    let key: GrowthCenterLoadKey
    let center: GrowthCenterRecord
    let presentationID: UUID
    func accepts(readerID: ObjectIdentifier?, key: GrowthCenterLoadKey, center: GrowthCenterRecord?,
                 presentationID: UUID, visible: Bool, authenticated: Bool, configured: Bool,
                 loading: Bool, hasIssue: Bool) -> Bool {
        visible && authenticated && configured && !loading && !hasIssue &&
            self.readerID == readerID && self.key == key && self.presentationID == presentationID &&
            self.center.badges.isEmpty && self.center == center
    }
}

/// Mirrors the source's 新徽章已点亮：A、B status line for badges new since the previous read.
struct GrowthNewlyLitBadges: View {
    let names: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("growth.badges.newlyLit").cyText(.bodyMedium, weight: .semibold)
            Text(verbatim: names.formatted(.list(type: .and))).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }
}
