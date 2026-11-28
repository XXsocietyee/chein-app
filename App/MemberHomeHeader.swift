import SwiftUI

/// 我的 identity card (mini-program `cy-profile viewer=self` header). Only server
/// values are shown; a failed or dormant read falls back to the signed-in
/// account's own name and level with an explicit unavailable note.
@MainActor struct MemberIdentityCardSection: View {
    let account: Account
    let reader: any MemberHomeReading
    var growth: (any GrowthCenterReading)? = nil
    var onOpenTickets: (() -> Void)? = nil
    /// 积分 opens the place its ledger lives (钱包 → 积分明细). Nil keeps the number static.
    var onOpenPoints: (() -> Void)? = nil
    /// A1-07: MP 如何获取积分 next to 积分 opens the earn/spend rules (积分任务). Nil hides the button.
    var onOpenPointsHelp: (() -> Void)? = nil
    /// A1-04: MP avatar (pen badge) opens 编辑个人资料 for the signed-in member. Nil keeps the avatar decorative.
    var onEditProfile: (() -> Void)? = nil
    /// A1-09: MP 账户余额 card opens the wallet. Nil keeps the balance display-only.
    var onOpenBalance: (() -> Void)? = nil
    /// Bump from the owning screen's pull-to-refresh to reload identity and growth together.
    var refreshToken: Int = 0
    var avatarAccess: MemberIdentityAvatarAccess? = nil
    /// mp-mine r3: hands the ready `/api/user/info` snapshot to the 关于 tab (MP reads one userInfo for both). Nil = not needed.
    var onSnapshot: ((MemberIdentitySnapshot?) -> Void)? = nil
    /// mp-mine r3 (14:13 visual check): false keeps 积分 and 连续打卡 out of the card; the 我的 page shows them on 成就.
    var showsMetrics = true
    /// MP cy-profile `pc-actions` (self): 开始探索 (goRoam) beside 票夹, same size; native look P22: 开始探索 filled, 票夹 bordered. Nil keeps the single 票夹.
    var onStartExplore: (() -> Void)? = nil
    /// The ··· menu after the two primary buttons. Nil hides it.
    var moreMenu: AnyView? = nil
    @State private var readOwner = MemberIdentityCardReadOwner()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Rows become columns at accessibility sizes so labels never truncate or overflow.
    private var rowLayout: AnyLayout { typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 16)) }
    enum Phase: Equatable { case loading, ready(MemberIdentitySnapshot), failed(signedOut: Bool) }
    @State private var phase: Phase = .loading
    @State private var failureOffline = false
    @State private var level: Int?
    @State private var streakDays: Int?
    /// 积分 from the growth center; nil until read, shown as "—".
    @State private var points: Int?
    @State private var contractHome: AccountPublishMPContract.HomeAccount?
    @State private var contractEarnings: AccountPublishMPContract.EarningsBalance?
    @ScaledMetric(relativeTo: .largeTitle) private var assetDivider: CGFloat = 40
    @Environment(\.locale) private var locale

    var body: some View {
        Section {
            // MP cy-profile `.pc-hero-bg` (index.js:399 `heroImg` default `/subpackageMember/images/mer1.jpg`): kept as the
            // one plain header image of the first section (native r2: no fade, no card).
            Color.clear
                .frame(height: 120)
                .overlay { MPAsset.BannerCover.subpackageMemberImagesMer1.resizable().scaledToFill() }
                .clipped()
                .listRowInsets(EdgeInsets())
                .accessibilityHidden(true)
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 16))) {
                avatarControl
                VStack(alignment: .leading, spacing: 4) {
                    name.font(.title2.bold()).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("member.card.name")
                    if let home = contractHome, !home.greeting.isEmpty {
                        Text(verbatim: home.greeting)
                            .font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("member.card.greeting")
                            .accessibilityValue(Text(verbatim: "\(home.role) userType:\(home.userType.map(String.init) ?? "") clubLeader:\(home.isClubLeader)"))
                    }
                    HStack(spacing: 6) {
                        // MP profile index.wxml:65-68: member level badge art for levelId 2…5.
                        if let badge = AccountPublishLevelBadge.image(levelID: snapshot?.levelID) {
                            badge.resizable().scaledToFit().frame(height: 16).accessibilityHidden(true)
                        }
                        Text(verbatim: levelText).monospacedDigit()
                            .accessibilityLabel(PageTemplateVoiceOver.spoken(levelText, locale: locale))
                        Text("member.card.levelTitle", tableName: "MemberProfile")
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("member.card.level")
                    Label { city } icon: { Image(systemName: "location").accessibilityHidden(true) }
                        .accessibilityIdentifier("member.card.city")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                // 23:20 sweep: the ··· menu sits on the identity row (card top-trailing), so [开始探索][票夹]
                // stay two equal buttons whether the row fits or stacks.
                moreButton
            }
            .padding(.vertical, 4)
            // xrefs-1 Adopt 6: the streak gets its own row under the name (native r2: a plain LabeledContent row).
            if showsMetrics, let streakDays {
                LabeledContent {
                    Text(verbatim: "\(streakDays)").monospacedDigit()
                } label: {
                    Label { Text("profile.selfGrowth.streak") } icon: { Image(systemName: "flame") }
                }
                .accessibilityIdentifier("member.card.streak")
            }
            // 我的资产 (design hand-off r1 PL-30, owner Q-B; P 210:8603): 积分 first and large, as a plain number with no tile.
            // 积分 is the only currency. The ¥ 账户余额 column appears only when this account holds real money (the server
            // sent a balance). Unknown 积分 reads "—", never 0.
            // MP cy-profile shows the metrics only when `profileMetricState === 'ready'`: an unknown 积分 hides the
            // block instead of reading "Points —" (18:15 sweep, e4-member).
            if showsMetrics, points != nil || balanceDisplay != nil { assets }
            // The three counters (好友 / 关注 / 粉丝) as one row of plain columns.
            // mp-mine r3 (MP cy-profile wxml:109, 1121 N5): one's own page hides the row while all three are a known 0.
            if showsCounters {
                HStack(spacing: 0) {
                    statCell(snapshot?.friendCountText, id: "friends", key: "member.card.friends")
                    Divider()
                    statCell(snapshot?.followCountText, id: "following", key: "member.card.following")
                    Divider()
                    statCell(snapshot?.fansCountText, id: "fans", key: "member.card.fans")
                }
            }
            // MP cy-profile `pc-actions`: [开始探索] [票夹] (same size; P22 filled + bordered) [···] under the counters.
            if let onOpenTickets, onStartExplore != nil {
                actionRow(onOpenTickets)
            } else if let onOpenTickets {
                // Mini-program member header: one full-width 票夹 button under the counters, drawn like the
                // paired one (glyph + centred label) so the glyph does not drop out (e4-member, 01:10 sweep).
                ticketsButton(onOpenTickets, fixedLabel: false)
            }
            identityState
        }
        .onAppear { readOwner.appear(active: scenePhase == .active) }
        .task(id: TaskKey(scope: reader.scope, refresh: refreshToken, active: scenePhase == .active)) { await load() }
        .onDisappear { readOwner.disappear() }
        .onChange(of: scenePhase) { _, value in readOwner.scene(active: value == .active) }
        .onChange(of: phase, initial: true) { _, _ in onSnapshot?(snapshot) }
    }
    private struct TaskKey: Equatable { let scope: UUID; let refresh: Int; let active: Bool }

    private var snapshot: MemberIdentitySnapshot? { if case .ready(let value) = phase { return value }; return nil }

    /// MP `pc-actions`: two equal buttons, 开始探索 filled and 票夹 bordered (P22) (the ··· menu is on the identity row). One-line labels; when
    /// the row does not fit (English "Start exploring" at 375 pt, accessibility sizes) both buttons stack, each
    /// full width, so the two rows always match.
    private func actionRow(_ onOpenTickets: @escaping () -> Void) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                stackedActions(onOpenTickets)
            } else {
                // The row's labels are fixed to their one-line width, so ViewThatFits sees the real need and
                // stacks instead of truncating ("Star…", "Tick…" in the 18:15 en sweep).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        startExploreButton(fixedLabel: true)
                        ticketsButton(onOpenTickets, fixedLabel: true, secondary: true)
                    }
                    stackedActions(onOpenTickets)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    private func stackedActions(_ onOpenTickets: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            startExploreButton(fixedLabel: false)
            ticketsButton(onOpenTickets, fixedLabel: false, secondary: true)
        }
    }
    /// MP `pc-primary` 开始探索 is a text-only button (no icon), unlike 票夹.
    @ViewBuilder
    private func startExploreButton(fixedLabel: Bool) -> some View {
        if let onStartExplore {
            Button(action: onStartExplore) {
                Text("member.card.startExplore")
                    .lineLimit(fixedLabel ? 1 : 2)
                    .fixedSize(horizontal: fixedLabel, vertical: false)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .accessibilityIdentifier("member.card.startExplore")
        }
    }
    /// `secondary`: beside 开始探索 the pair reads primary filled + secondary bordered (P22, ADA d2-me); alone it stays
    /// the one prominent action.
    private func ticketsButton(_ onOpenTickets: @escaping () -> Void, fixedLabel: Bool, secondary: Bool = false) -> some View {
        Button(action: onOpenTickets) {
            // Explicit icon + text: the system Label dropped the glyph inside the large prominent button and
            // left its gap, so 票夹 sat off centre (00:10 sweep, d2-me zh-Hans + en).
            HStack(spacing: 6) {
                Image(systemName: "ticket").accessibilityHidden(true)
                Text("member.card.tickets", tableName: "MemberProfile")
                    .lineLimit(fixedLabel ? 1 : 2)
                    .fixedSize(horizontal: fixedLabel, vertical: false)
            }
            .frame(maxWidth: .infinity)
        }
        .modifier(MemberCardActionStyle(secondary: secondary))
        .pageTemplateControl(label: Text("member.card.tickets", tableName: "MemberProfile"), traits: .isButton)
        .accessibilityIdentifier("member.card.tickets")
    }
    @ViewBuilder
    private var moreButton: some View {
        if let moreMenu {
            Menu {
                moreMenu
            } label: {
                Label { Text("member.card.more") } icon: { Image(systemName: "ellipsis") }
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered).buttonBorderShape(.circle).controlSize(.large)
            .accessibilityLabel(Text("member.card.more"))
            .accessibilityIdentifier("member.card.more")
        }
    }
    /// Unknown counters keep the row (em dashes); only three known zeros hide it, as the MP does.
    private var showsCounters: Bool {
        guard let value = snapshot else { return true }
        let zero = MemberHomeCountFact.value(0)
        return !(value.friendCountFact == zero && value.followCountFact == zero && value.fansCountFact == zero)
    }

    /// Growth or the identity snapshot when present. A failed read keeps the signed-in account level.
    /// Anything still unknown is an em dash, never a made-up zero.
    private var knownLevel: Int? {
        if let level { return level }
        if let id = snapshot?.levelID { return id }
        if case .failed = phase { return account.level }
        return nil
    }
    /// Grouped digits so a large balance stays readable (1,286 / 1,234,567); unknown is "—".
    private var pointsText: String { CYUnknownValue.text(points) { $0.formatted(.number.locale(locale)) } }
    /// ¥ 账户余额. A contract read uses `earningsBalance` (missing displays 0.00). It does not start a pay or withdrawal.
    private var balanceDisplay: String? {
        if let earnings = contractEarnings, let raw = earnings.display {
            return MemberBalanceDisplay.text(raw, locale: locale)
        }
        guard contractEarnings == nil, let raw = snapshot?.balancePreviewText, snapshot?.balanceText != nil else { return nil }
        return MemberBalanceDisplay.text(raw, locale: locale)
    }
    private var levelText: String {
        guard let knownLevel else { return MemberHomePageModel.unknownDisplay }
        return "Lv.\(knownLevel)"
    }
    @ViewBuilder private var identityState: some View {
        switch phase {
        case .loading:
            // mp-states r3: the one loading pattern — a labelled system ProgressView.
            ProgressView { Text("member.card.loading", tableName: "MemberProfile") }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("member.card.loading")
        case .failed(let signedOut) where failureOffline && !signedOut:
            VStack(alignment: .leading, spacing: 8) {
                Label { Text("cy.state.offline.title") } icon: { Image(systemName: "wifi.slash") }
                    .foregroundStyle(.secondary)
                Button { Task { await load() } } label: { Text("cy.state.offline.retry") }
                    .buttonStyle(.bordered)
            }
            .accessibilityIdentifier("member.card.offline")
        case .failed(let signedOut):
            // R1 error state (169:4754): the same inline error as 首页 (166:3280): one line with the warning glyph and one
            // secondary 重新加载. Signed out is not an error (no glyph, no retry); 积分 and 等级 stay "—", never 0.
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if signedOut { Text("member.card.signedOut", tableName: "MemberProfile") }
                    else {
                        Label {
                            if reader.isConfigured { Text("member.card.failed", tableName: "MemberProfile") }
                            else { Text("member.card.unavailable", tableName: "MemberProfile") }
                        } icon: { Image(systemName: "exclamationmark.triangle").accessibilityHidden(true) }
                    }
                }.font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if reader.isConfigured, !signedOut {
                    Button { Task { await load() } } label: { Text("member.card.retry", tableName: "MemberProfile") }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("member.card.retry")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("member.card.failed")
        case .ready:
            EmptyView()
        }
    }

    @ViewBuilder private var name: some View {
        let nickname = contractHome?.nickname ?? (AccountPublishContractLane.isInstalled ? "" : (snapshot?.nickname ?? account.nickname))
        if nickname.isEmpty { Text("member.card.defaultName", tableName: "MemberProfile") } else { Text(verbatim: nickname) }
    }
    @ViewBuilder private var city: some View {
        if let value = snapshot?.city, !value.isEmpty { Text(verbatim: value) }
        else { Text(verbatim: "—").accessibilityLabel(Text("curA11y.unknown", tableName: "CurA11y")) }
    }
    /// Remote avatar comes only from the already-loaded user-info `avatar` URL (https only);
    /// anything else, or a load failure, keeps the lettermark.
    static func remoteAvatarURL(_ raw: String?) -> URL? {
        let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.lowercased().hasPrefix("https://"), let url = URL(string: text), url.host != nil else { return nil }
        return url
    }
    /// MP profile: a player without an avatar falls back to `/images/d_profile.png` (`MPAsset.AvatarDefault.dProfile`),
    /// not a lettermark; the remote avatar draws over it once it loads.
    private var lettermark: some View {
        MPAsset.AvatarDefault.dProfile.resizable().scaledToFill().accessibilityHidden(true)
    }
    private var avatar: some View {
        ZStack {
            lettermark
            if let observation = readOwner.observation {
                MemberIdentityAvatarView(observation: observation, owner: readOwner, access: avatarAccess)
                    .id(AvatarKey(read: observation.readRevision, source: avatarAccess?.sourceRevision()))
            }
        }.frame(width: 72, height: 72).clipShape(Circle())
    }
    /// A1-04: self avatar is the MP `onAvatarTap` control (72 pt, pen badge, label 编辑个人资料).
    @ViewBuilder private var avatarControl: some View {
        if let onEditProfile {
            Button(action: onEditProfile) {
                avatar.overlay(alignment: .bottomTrailing) {
                    // MP profile index.wxml:51 `/subpackageMember/images/icon_pen.svg`.
                    AccountPublishMPGlyph(MPAsset.FeatureIcon.iconPen, side: 14)
                        .foregroundStyle(.tint)
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        .accessibilityHidden(true)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("profile.edit.avatarControl"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("member.card.avatar")
        } else {
            avatar.accessibilityHidden(true)
        }
    }
    private struct AvatarKey: Hashable { let read: UUID; let source: UUID? }
    /// One counter column: the number (rolls on change), then its label. Unknown reads "—".
    private func statCell(_ value: String?, id: String, key: LocalizedStringKey) -> some View {
        let shown = value ?? MemberHomePageModel.unknownDisplay
        return VStack(spacing: 2) {
            Text(verbatim: shown)
                .font(.title3.weight(.semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                .modifier(MemberAssetRoll(value: Double(shown)))
            Text(key, tableName: "MemberProfile")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("member.card.\(id)")
    }
    /// 积分 hero + optional ¥ column. Columns stack at accessibility sizes (no hairline then).
    private var assets: some View {
        rowLayout {
            if points != nil { pointsBlock }
            if let balance = balanceDisplay {
                if !typeSize.isAccessibilitySize {
                    Divider().frame(height: assetDivider).accessibilityHidden(true)
                }
                balanceBlock(balance)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("member.card.assets")
    }

    /// 积分: label (with a chevron when it opens the ledger), then the number in the stat-hero style. It rolls in
    /// tabular digits only when the value really changes (xrefs-1 Adopt 3), never on a plain visit.
    @ViewBuilder private var pointsBlock: some View {
        HStack(alignment: .top, spacing: 4) {
            pointsValueBlock
            if let onOpenPointsHelp {
                // A1-07: MP 如何获取积分 (cyp wxml:297) → 积分任务 sheet. 44 pt target.
                Button(action: onOpenPointsHelp) {
                    Image(systemName: "info.circle").imageScale(.medium)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("member.card.pointsHelp"))
                .accessibilityIdentifier("member.card.pointsHelp")
            }
        }
    }
    @ViewBuilder private var pointsValueBlock: some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("member.card.points", tableName: "DesignR1")
                if onOpenPoints != nil {
                    Image(systemName: "chevron.right").imageScale(.small).accessibilityHidden(true)
                }
            }
            .font(.subheadline).foregroundStyle(.secondary)
            Text(verbatim: pointsText)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(points == nil ? Color.secondary : Color.primary)
                .lineLimit(1).minimumScaleFactor(0.6)
                .modifier(MemberAssetRoll(value: points.map { Double($0) }))
                .accessibilityLabel(PageTemplateVoiceOver.spoken(pointsText, locale: locale))
                .accessibilityIdentifier("member.card.pointsValue")
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        if let onOpenPoints {
            Button(action: onOpenPoints) { content }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("member.card.points")
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("member.card.points")
        }
    }

    @ViewBuilder private func balanceBlock(_ balance: String) -> some View {
        if let onOpenBalance {
            // A1-09: MP whole 账户余额 card opens earnings (cyp wxml:219-231).
            Button(action: onOpenBalance) { balanceContent(balance).contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
        } else {
            balanceContent(balance)
        }
    }
    private func balanceContent(_ balance: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("member.card.balance", tableName: "MemberProfile")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(verbatim: balance)
                .font(.title3).monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityLabel(PageTemplateVoiceOver.spoken(balance, locale: locale))
                .accessibilityIdentifier("member.card.balanceValue")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("member.card.balance")
    }

    private func load() async {
        guard !Task.isCancelled, scenePhase == .active else { return }
        readOwner.scene(active: true)
        let scope = reader.scope
        guard let run = readOwner.begin(scope: scope) else { return }
        guard reader.isSignedIn else { phase = .failed(signedOut: true); return }
        guard reader.isConfigured else { phase = .failed(signedOut: false); return }
        if snapshot == nil { phase = .loading }
        failureOffline = false
        do {
            let value: MemberIdentitySnapshot
            if AccountPublishContractLane.isInstalled {
                let (data, status) = try await AccountPublishContractLane.userInfo()
                guard !Task.isCancelled, scope == reader.scope, readOwner.accepts(run, scope: reader.scope) else { return }
                if status == 401 {
                    readOwner.invalidate(run)
                    contractHome = nil
                    contractEarnings = nil
                    phase = .failed(signedOut: true)
                    return
                }
                contractHome = AccountPublishMPContract.homeAccount(from: data)
                contractEarnings = AccountPublishMPContract.earningsBalance(from: data)
                guard contractHome != nil, let decoded = Self.identitySnapshot(from: data) else {
                    readOwner.invalidate(run)
                    phase = .failed(signedOut: false)
                    return
                }
                value = decoded
            } else if let sessionReader = reader as? MemberHomeSessionReader {
                value = try await sessionReader.contractIdentity()
            } else {
                value = try await reader.identity()
            }
            guard !Task.isCancelled, scope == reader.scope, readOwner.accepts(run, scope: reader.scope) else { return }
            readOwner.publish(value, run: run, scope: reader.scope)
            phase = .ready(value)
            // Streak is shown only once the identity counters are ready, as the source does.
            if value.countersReady, let growth, growth.isConfigured, growth.isAuthenticated,
               let overview = try? await growth.overview(), !Task.isCancelled, scope == reader.scope,
               readOwner.accepts(run, scope: reader.scope) {
                level = overview.center.value?.level ?? overview.progress.value?.level
                streakDays = overview.progress.value?.streakDays
                points = overview.center.value?.points
            }
        } catch is CancellationError {
            readOwner.invalidate(run)
        } catch {
            guard !Task.isCancelled, scope == reader.scope, readOwner.accepts(run, scope: reader.scope) else { return }
            readOwner.invalidate(run)
            failureOffline = error is URLError
            phase = .failed(signedOut: error as? APIError == .unauthorized)
        }
    }

    private static func identitySnapshot(from body: Data) -> MemberIdentitySnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = root["data"] as? [String: Any],
              let encoded = try? JSONSerialization.data(withJSONObject: data) else { return nil }
        return try? JSONDecoder().decode(MemberIdentitySnapshot.self, from: encoded)
    }
}

/// mp-mine r3: MP cy-profile 关于 (self, player) top-to-bottom — 个人介绍 with 编辑, 兴趣标签 (添加兴趣 when none),
/// 加入时间 — from the identity card's own `/api/user/info` read (no second request). Nothing until that read is ready.
@MainActor struct MemberAboutSection: View {
    let snapshot: MemberIdentitySnapshot?
    @Environment(\.locale) private var locale
    var onEdit: (() -> Void)? = nil
    var body: some View {
        if let snapshot {
            Section("social.introduction") {
                if snapshot.introduction.isEmpty { Text("social.noIntroduction").foregroundStyle(.secondary) }
                else { Text(verbatim: snapshot.introduction).fixedSize(horizontal: false, vertical: true) }
                if let onEdit {
                    Button("profile.selfEdit.open", action: onEdit)
                        .accessibilityIdentifier("member.about.editIntro")
                }
            }
            Section("social.interests") {
                ForEach(snapshot.interests, id: \.self) { item in
                    Label { Text(verbatim: item) } icon: { Image(systemName: "tag") }
                }
                if snapshot.interests.isEmpty, let onEdit {
                    // MP `pc-tag--add` 添加兴趣: straight to the route preferences in 个人资料.
                    Button(action: onEdit) {
                        Label { Text("member.about.addInterest") } icon: { Image(systemName: "plus") }
                    }
                    .accessibilityIdentifier("member.about.addInterest")
                }
            }
            if let joinDate = snapshot.joinDate, !joinDate.isEmpty {
                Section {
                    LabeledContent("profile.about.joinDate") { Text(verbatim: LocaleDisplay.civil(joinDate, locale: locale)).monospacedDigit() }
                        .accessibilityIdentifier("member.about.joinDate")
                }
            }
        }
    }
}

/// 关于 → 当前权益, built from `/api/role/info` like the source `buildBenefits`.
@MainActor struct MemberBenefitsSection: View {
    let reader: any MemberHomeReading
    var earningsDestination: (() -> AnyView)?
    @State private var owner: MemberBenefitsReadOwner
    @Environment(\.scenePhase) private var scenePhase
    init(reader: any MemberHomeReading, earningsDestination: (() -> AnyView)? = nil) {
        self.reader = reader; self.earningsDestination = earningsDestination
        _owner = State(initialValue: .init(reader: reader))
    }
    var body: some View {
        Section {
            switch owner.phase {
            case .loading:
                ProgressView().accessibilityIdentifier("member.benefits.loading")
            case .unavailable:
                Text("member.benefits.unavailable", tableName: "MemberProfile").foregroundStyle(.secondary)
                    .accessibilityIdentifier("member.benefits.unavailable")
            case .failed:
                VStack(alignment: .leading) {
                    Text("member.benefits.failed", tableName: "MemberProfile").foregroundStyle(.secondary)
                    Button { owner.refresh() } label: { Text("member.card.retry", tableName: "MemberProfile") }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("member.benefits.retry")
                }.accessibilityIdentifier("member.benefits.failed")
            case .ready(let snapshot):
                // MP buildBenefits order. Lane G: a player in Release does not see locked merchant-only rows (ADA e4-member).
                ForEach(snapshot.rows.filter { !$0.isMerchantCapability || $0.unlocked || PlayerLaunch.merchantCenterEnabled }) { row in
                    if row.opensEarnings, let earningsDestination {
                        NavigationLink(isActive: owner.earningsBinding(snapshot)) {
                            if let offered = owner.navigation(for: snapshot) {
                                MemberBenefitsEarningsDestination(owner: owner, offered: offered, destination: earningsDestination)
                            } else { Text("member.benefits.unavailable", tableName: "MemberProfile") }
                        } label: { MemberBenefitRow(benefit: row) }
                        .accessibilityIdentifier("member.benefit.\(row.id)")
                    } else {
                        MemberBenefitRow(benefit: row).accessibilityIdentifier("member.benefit.\(row.id)")
                    }
                }
            }
        } header: { Text("member.benefits.title", tableName: "MemberProfile") }
        .onAppear { owner.appear(active: scenePhase == .active) }
        .onDisappear { owner.disappear() }
        .onChange(of: scenePhase) { _, phase in owner.scene(active: phase == .active) }
        .task(id: ReadKey(scope: reader.scope, active: scenePhase == .active)) {
            guard !Task.isCancelled, scenePhase == .active else { return }
            owner.scene(active: true)
            let work = owner.refresh()
            await withTaskCancellationHandler(operation: { await work?.value }, onCancel: { work?.cancel() })
        }

    }
    private struct ReadKey: Equatable { let scope: UUID; let active: Bool }
}

struct MemberBenefitRow: View {
    let benefit: MemberBenefit
    var body: some View {
        Label {
            label.foregroundStyle(benefit.unlocked ? Color.primary : Color.secondary)
        } icon: {
            Image(systemName: benefit.unlocked ? "checkmark.circle.fill" : "lock.fill")
                .accessibilityHidden(true).foregroundStyle(benefit.unlocked ? Color.green : Color.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(benefit.unlocked ? Text("member.benefit.unlocked", tableName: "MemberProfile")
                                              : Text("member.benefit.locked", tableName: "MemberProfile"))
    }
    @ViewBuilder private var label: some View {
        switch benefit.kind {
        case .publishRoutes:
            HStack(spacing: 4) {
                Text("member.benefit.publishRoutes", tableName: "MemberProfile")
                switch benefit.routeLimit {
                case .limited(let count): Text(verbatim: "\(count)")
                default: Text("member.benefit.unlimited", tableName: "MemberProfile")
                }
            }
        case .redeemCoupons: Text("member.benefit.redeemCoupons", tableName: "MemberProfile")
        case .branching: Text("member.benefit.branching", tableName: "MemberProfile")
        case .gameMechanics: Text("member.benefit.gameMechanics", tableName: "MemberProfile")
        case .openAsNode: Text("member.benefit.openAsNode", tableName: "MemberProfile")
        case .medalDesign: Text("member.benefit.medalDesign", tableName: "MemberProfile")
        case .createGroup: Text("member.benefit.createGroup", tableName: "MemberProfile")
        case .earnings: Text("member.benefit.earnings", tableName: "MemberProfile")
        }
    }
}


/// verify-r1 1.5 / Q8: the ¥ 账户余额 tile shows CNY with two decimals. Text the server sends that is not a number is
/// shown as sent (it is never turned into 0).
enum MemberBalanceDisplay {
    static func text(_ raw: String, locale: Locale) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        guard let value = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")) else { return raw }
        return value.formatted(.currency(code: "CNY").locale(locale).precision(.fractionLength(2)))
    }
}

/// Rolls a known number on change (`cyNumericRoll`); an unknown "—" is plain tabular text.
private struct MemberAssetRoll: ViewModifier {
    let value: Double?
    @ViewBuilder func body(content: Content) -> some View {
        if let value { content.cyNumericRoll(value) } else { content.monospacedDigit() }
    }
}

/// mp-mine r3 (14:13 visual check): MP cy-profile 成就 tab head (`pc-achievement-metrics`, wxml:288-321): 积分 (opens
/// 积分明细) with 如何获取积分, then 连续打卡 and 累计打卡; the caller adds the 总积分排名 → 成长中心 row. Unknown reads "—".
@MainActor struct MemberAchievementMetricsSection<Trailing: View>: View {
    let growth: any GrowthCenterReading
    var refreshToken: Int = 0
    var onOpenPoints: (() -> Void)? = nil
    var onOpenPointsHelp: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var points: Int?
    @State private var streakDays: Int?
    @State private var checkins: Int?

    var body: some View {
        Section {
            // MP `pc-achievement-metrics` is `wx:if="{{profileMetricState === 'ready'}}"`: unknown values hide their
            // row rather than showing "—" as data (18:15 sweep).
            if points != nil {
                HStack(alignment: .firstTextBaseline) {
                    pointsValue
                    Spacer(minLength: 8)
                    if let onOpenPointsHelp {
                        Button(action: onOpenPointsHelp) { Text("member.card.pointsHelp") }
                            .buttonStyle(.borderless)
                            .font(.subheadline)
                            .accessibilityIdentifier("member.achievements.pointsHelp")
                    }
                }
            }
            if let streakDays {
                LabeledContent {
                    Text(verbatim: "\(streakDays)").monospacedDigit()
                } label: {
                    Label { Text("profile.selfGrowth.streak") } icon: { Image(systemName: "flame") }
                }
                .accessibilityIdentifier("member.achievements.streak")
            }
            if let checkins {
                LabeledContent {
                    Text(verbatim: "\(checkins)").monospacedDigit()
                } label: {
                    Label { Text("profile.selfGrowth.checkins") } icon: { Image(systemName: "mappin.and.ellipse") }
                }
                .accessibilityIdentifier("member.achievements.checkins")
            }
            trailing()
        }
        .task(id: TaskKey(scope: growth.scope, refresh: refreshToken, active: scenePhase == .active)) { await load() }
    }
    private struct TaskKey: Equatable { let scope: UUID; let refresh: Int; let active: Bool }

    private var pointsText: String { CYUnknownValue.text(points) { $0.formatted(.number.locale(locale)) } }

    @ViewBuilder private var pointsValue: some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("member.card.points", tableName: "DesignR1")
                if onOpenPoints != nil {
                    Image(systemName: "chevron.right").imageScale(.small).accessibilityHidden(true)
                }
            }
            .font(.subheadline).foregroundStyle(.secondary)
            Text(verbatim: pointsText)
                .font(.largeTitle.weight(.semibold)).monospacedDigit()
                .foregroundStyle(points == nil ? Color.secondary : Color.primary)
                .lineLimit(1).minimumScaleFactor(0.6)
                .modifier(MemberAssetRoll(value: points.map { Double($0) }))
                .accessibilityLabel(PageTemplateVoiceOver.spoken(pointsText, locale: locale))
        }
        .contentShape(Rectangle())
        if let onOpenPoints {
            Button(action: onOpenPoints) { content }
                .buttonStyle(.borderless)
                .tint(.primary)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("member.achievements.points")
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("member.achievements.points")
        }
    }

    private func load() async {
        guard !Task.isCancelled, scenePhase == .active, growth.isConfigured, growth.isAuthenticated else { return }
        let scope = growth.scope
        guard let overview = try? await growth.overview(), !Task.isCancelled, scope == growth.scope else { return }
        points = overview.center.value?.points
        streakDays = overview.progress.value?.streakDays
        checkins = overview.progress.value?.totalCheckins
    }
}

extension MemberAchievementMetricsSection where Trailing == EmptyView {
    init(growth: any GrowthCenterReading, refreshToken: Int = 0, onOpenPoints: (() -> Void)? = nil, onOpenPointsHelp: (() -> Void)? = nil) {
        self.init(growth: growth, refreshToken: refreshToken, onOpenPoints: onOpenPoints, onOpenPointsHelp: onOpenPointsHelp, trailing: { EmptyView() })
    }
}

/// P22 action pair: the primary action is `.borderedProminent`, the secondary `.bordered`; both `.large`, equal width.
struct MemberCardActionStyle: ViewModifier {
    let secondary: Bool
    func body(content: Content) -> some View {
        if secondary {
            content.buttonStyle(.bordered).controlSize(.large)
        } else {
            content.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
}
