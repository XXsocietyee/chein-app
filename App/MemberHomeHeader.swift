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
    @State private var readOwner = MemberIdentityCardReadOwner()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Rows become columns at accessibility sizes so labels never truncate or overflow.
    private var rowLayout: AnyLayout { typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm)) : AnyLayout(HStackLayout(spacing: CYSpacing.lg)) }
    enum Phase: Equatable { case loading, ready(MemberIdentitySnapshot), failed(signedOut: Bool) }
    @State private var phase: Phase = .loading
    @State private var failureOffline = false
    @State private var level: Int?
    @State private var streakDays: Int?
    /// 积分 from the growth center; nil until read, shown as "—".
    @State private var points: Int?
    @State private var contractHome: AccountPublishMPContract.HomeAccount?
    @State private var contractEarnings: AccountPublishMPContract.EarningsBalance?
    /// First-load entrance only (xrefs-1 motion rules): the card rises once per screen, never on a refresh.
    @State private var stagger = CYStaggerGate()
    @ScaledMetric(relativeTo: .largeTitle) private var assetDivider: CGFloat = 40
    @Environment(\.cyPalette) private var palette
    @Environment(\.themeDomain) private var themeDomain
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.md)) : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.lg))) {
                avatarControl
                VStack(alignment: .leading, spacing: 6) {
                    name.cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("member.card.name")
                    if let home = contractHome, !home.greeting.isEmpty {
                        Text(verbatim: home.greeting)
                            .cyText(.meta).foregroundStyle(palette.textSecondary)
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
                    .cyText(.meta, weight: .semibold).foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                    .background(palette.bgRaised, in: Capsule(style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("member.card.level")
                    Label { city } icon: { Image(systemName: "location").accessibilityHidden(true) }
                        .accessibilityIdentifier("member.card.city")
                        .cyText(.meta).foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            // xrefs-1 Adopt 6 (`Player/Streak Row`): the streak gets its own row under the name, not a caption.
            if let streakDays {
                CYStreakRow(streakDays: streakDays)
                    .transition(.opacity)
                    .accessibilityIdentifier("member.card.streak")
            }
            // 我的资产 (design hand-off r1 PL-30, owner Q-B; P 210:8603): 积分 first and large, as a plain number with no tile
            // (xrefs-1 Adopt 4: stats without a box). 积分 is the only currency. The ¥ 账户余额 column appears only when this
            // account holds real money (the server sent a balance), after a hairline. Unknown 积分 reads "—", never 0.
            assets
            // xrefs-1 Adopt 4: the three counters are a plain row with hairline dividers, no tiles.
            CYPlainStatRow(stats: [
                stat(snapshot?.friendCountText, id: "friends", key: "member.card.friends"),
                stat(snapshot?.followCountText, id: "following", key: "member.card.following"),
                stat(snapshot?.fansCountText, id: "fans", key: "member.card.fans")
            ])
            // Mini-program member header: one full-width 票夹 pill under the counters.
            if let onOpenTickets {
                Button(action: onOpenTickets) {
                    Label { Text("member.card.tickets", tableName: "MemberProfile") } icon: { Image(systemName: "ticket") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
                .pageTemplateControl(label: Text("member.card.tickets", tableName: "MemberProfile"), traits: .isButton)
                .accessibilityIdentifier("member.card.tickets")
            }
            identityState
            }
            // Late values (streak, 积分) arrive in place: the card grows on `standard`, nothing else moves.
            .cyAnimation(CYMotion.standard, value: streakDays)
            .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.lg)
            .cyStaggeredAppear(index: 0, gate: stagger)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: 0, bottom: CYSpacing.sm, trailing: 0))
        .onAppear { readOwner.appear(active: scenePhase == .active) }
        .task(id: TaskKey(scope: reader.scope, refresh: refreshToken, active: scenePhase == .active)) { await load() }
        .onDisappear { readOwner.disappear() }
        .onChange(of: scenePhase) { _, value in readOwner.scene(active: value == .active) }
    }
    private struct TaskKey: Equatable { let scope: UUID; let refresh: Int; let active: Bool }

    private var snapshot: MemberIdentitySnapshot? { if case .ready(let value) = phase { return value }; return nil }

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
    /// Player profile avatar ring. The reserved ring tint is allowed only here, on the selected tab, and on the result spinner.
    @ViewBuilder private var levelRing: some View {
        if themeDomain == .player {
            // xrefs-1 B.2: the ring is ink, not the reserved accent ring (it marked nothing on this page).
            Circle().strokeBorder(palette.textPrimary.opacity(0.85), lineWidth: 2).accessibilityHidden(true)
        }
    }

    @ViewBuilder private var identityState: some View {
        switch phase {
        case .loading:
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                CYSkeleton()
                Text("member.card.loading", tableName: "MemberProfile")
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("member.card.loading")
        case .failed(let signedOut) where failureOffline && !signedOut:
            CYOfflineBanner { Task { await load() } }
                .accessibilityIdentifier("member.card.offline")
        case .failed(let signedOut):
            // R1 error state (169:4754): the same inline error as 首页 (166:3280): one line with the warning glyph and one
            // secondary 重新加载. Signed out is not an error (no glyph, no retry); 积分 and 等级 stay "—", never 0.
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Group {
                    if signedOut { Text("member.card.signedOut", tableName: "MemberProfile") }
                    else {
                        Label {
                            if reader.isConfigured { Text("member.card.failed", tableName: "MemberProfile") }
                            else { Text("member.card.unavailable", tableName: "MemberProfile") }
                        } icon: { Image(systemName: "exclamationmark.triangle").accessibilityHidden(true) }
                    }
                }.cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if reader.isConfigured, !signedOut {
                    Button { Task { await load() } } label: { Text("member.card.retry", tableName: "MemberProfile") }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule)
                        .frame(minHeight: CYSpacing.minTouchTarget)
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
        ZStack {
            Circle().fill(palette.bgRaised)
            MPAsset.AvatarDefault.dProfile.resizable().scaledToFill().accessibilityHidden(true)
        }
    }
    private var avatar: some View {
        ZStack {
            lettermark
            if let observation = readOwner.observation {
                MemberIdentityAvatarView(observation: observation, owner: readOwner, access: avatarAccess)
                    .id(AvatarKey(read: observation.readRevision, source: avatarAccess?.sourceRevision()))
            }
        }.frame(width: 72, height: 72).clipShape(Circle())
        .overlay { levelRing }
    }
    /// A1-04: self avatar is the MP `onAvatarTap` control (72 pt, pen badge, label 编辑个人资料).
    @ViewBuilder private var avatarControl: some View {
        if let onEditProfile {
            Button(action: onEditProfile) {
                avatar.overlay(alignment: .bottomTrailing) {
                    // MP profile index.wxml:51 `/subpackageMember/images/icon_pen.svg`.
                    AccountPublishMPGlyph(MPAsset.FeatureIcon.iconPen, side: 12)
                        .foregroundStyle(palette.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(palette.bgRaised, in: Circle())
                        .overlay { Circle().strokeBorder(palette.borderSubtle, lineWidth: 1) }
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        .accessibilityHidden(true)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.cyPressable)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("profile.edit.avatarControl"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("member.card.avatar")
        } else {
            avatar.accessibilityHidden(true)
        }
    }
    private struct AvatarKey: Hashable { let read: UUID; let source: UUID? }
    private func stat(_ value: String?, id: String, key: String.LocalizationValue) -> CYPlainStat {
        let shown = value ?? MemberHomePageModel.unknownDisplay
        return CYPlainStat(id: id, value: shown,
                           label: String(localized: LocalizedStringResource(key, table: "MemberProfile", locale: locale)),
                           rollValue: Double(shown), accessibilityIdentifier: "member.card.\(id)")
    }
    /// 积分 hero + optional ¥ column. Columns stack at accessibility sizes (no hairline then).
    private var assets: some View {
        rowLayout {
            pointsBlock
            if let balance = balanceDisplay {
                if !typeSize.isAccessibilitySize {
                    Rectangle().fill(palette.borderSubtle).frame(width: 1, height: assetDivider).accessibilityHidden(true)
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
        HStack(alignment: .top, spacing: CYSpacing.xs) {
            pointsValueBlock
            if let onOpenPointsHelp {
                // A1-07: MP 如何获取积分 (cyp wxml:297) → 积分任务 sheet. 44 pt target.
                Button(action: onOpenPointsHelp) {
                    Image(systemName: "info.circle").imageScale(.medium)
                        .foregroundStyle(palette.textSecondary)
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("member.card.pointsHelp"))
                .accessibilityIdentifier("member.card.pointsHelp")
            }
        }
    }
    @ViewBuilder private var pointsValueBlock: some View {
        let content = VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            HStack(spacing: CYSpacing.xs) {
                Text("member.card.points", tableName: "DesignR1")
                if onOpenPoints != nil {
                    Image(systemName: "chevron.right").imageScale(.small).accessibilityHidden(true)
                }
            }
            .cyText(.meta).foregroundStyle(palette.textSecondary)
            Text(verbatim: pointsText)
                .cyText(.dataXL)
                .foregroundStyle(points == nil ? palette.textTertiary : palette.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
                .modifier(MemberAssetRoll(value: points.map { Double($0) }))
                .accessibilityLabel(PageTemplateVoiceOver.spoken(pointsText, locale: locale))
                .accessibilityIdentifier("member.card.pointsValue")
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
        if let onOpenPoints {
            Button(action: onOpenPoints) { content }
                .buttonStyle(.cyPressable)
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
                .buttonStyle(.cyPressable)
                .accessibilityAddTraits(.isButton)
        } else {
            balanceContent(balance)
        }
    }
    private func balanceContent(_ balance: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text("member.card.balance", tableName: "MemberProfile")
                .cyText(.meta).foregroundStyle(palette.textSecondary)
            Text(verbatim: balance)
                .cyText(.numericBody)
                .foregroundStyle(palette.textPrimary)
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
                Text("member.benefits.unavailable", tableName: "MemberProfile").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("member.benefits.unavailable")
            case .failed:
                VStack(alignment: .leading) {
                    Text("member.benefits.failed", tableName: "MemberProfile").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    Button { owner.refresh() } label: { Text("member.card.retry", tableName: "MemberProfile").frame(minHeight: CYSpacing.minTouchTarget) }
                        .accessibilityIdentifier("member.benefits.retry")
                }.accessibilityIdentifier("member.benefits.failed")
            case .ready(let snapshot):
                ForEach(snapshot.rows) { row in
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
        HStack(spacing: 10) {
            Image(systemName: benefit.unlocked ? "checkmark.circle.fill" : "lock.fill")
                .accessibilityHidden(true).foregroundStyle(benefit.unlocked ? CYColor.textPrimary : CYColor.textTertiary)
            label.cyText(.body).foregroundStyle(benefit.unlocked ? CYColor.textPrimary : CYColor.textSecondary)
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
        case .publishCoupons: Text("member.benefit.publishCoupons", tableName: "MemberProfile")
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
