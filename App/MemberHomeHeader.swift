import SwiftUI

/// 我的 identity card (mini-program `cy-profile viewer=self` header). Only server
/// values are shown; a failed or dormant read falls back to the signed-in
/// account's own name and level with an explicit unavailable note.
@MainActor struct MemberIdentityCardSection: View {
    let account: Account
    let reader: any MemberHomeReading
    var growth: (any GrowthCenterReading)? = nil
    var onOpenTickets: (() -> Void)? = nil
    /// Bump from the owning screen's pull-to-refresh to reload identity and growth together.
    var refreshToken: Int = 0
    var avatarAccess: MemberIdentityAvatarAccess? = nil
    @State private var readOwner = MemberIdentityCardReadOwner()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Rows become columns at accessibility sizes so labels never truncate or overflow.
    private var rowLayout: AnyLayout { typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm)) : AnyLayout(HStackLayout(spacing: CYSpacing.sm)) }
    enum Phase: Equatable { case loading, ready(MemberIdentitySnapshot), failed(signedOut: Bool) }
    @State private var phase: Phase = .loading
    @State private var level: Int?
    @State private var streakDays: Int?

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.md)) : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.lg))) {
                avatar
                VStack(alignment: .leading, spacing: 6) {
                    name.font(.system(.title2, design: .rounded).weight(.heavy)).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("member.card.name")
                    HStack(spacing: 6) {
                        Text(verbatim: "Lv.\(level ?? snapshot?.levelID ?? account.level)").monospacedDigit()
                        Text("member.card.levelTitle", tableName: "MemberProfile")
                    }
                    .font(CYTypography.meta.weight(.semibold)).foregroundStyle(CYColor.textPrimary)
                    .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                    .background(CYColor.bgRaised, in: Capsule(style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("member.card.level")
                    HStack(spacing: 10) {
                        Label { city } icon: { Image(systemName: "mappin.and.ellipse") }
                            .accessibilityIdentifier("member.card.city")
                        if let streakDays {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill").symbolEffect(.pulse, options: .nonRepeating, value: streakDays)
                                Text("member.card.streak", tableName: "MemberProfile")
                                Text(verbatim: "\(streakDays)").monospacedDigit()
                                Text("member.card.days", tableName: "MemberProfile")
                            }.accessibilityElement(children: .combine).accessibilityIdentifier("member.card.streak")
                        }
                    }.font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            rowLayout {
                stat(snapshot?.friendCount, id: "friends") { Text("member.card.friends", tableName: "MemberProfile") }
                stat(snapshot?.followCount, id: "following") { Text("member.card.following", tableName: "MemberProfile") }
                stat(snapshot?.fansCount, id: "fans") { Text("member.card.fans", tableName: "MemberProfile") }
            }
            // Quick actions as tiles: tickets (opens) and balance (read-only preview, em dash when unknown).
            rowLayout {
                if let onOpenTickets {
                    Button(action: onOpenTickets) {
                        tile(symbol: "ticket.fill") { Text("member.card.tickets", tableName: "MemberProfile") } value: { Image(systemName: "chevron.right").font(.caption.weight(.bold)) }
                    }
                    .buttonStyle(CYPressScaleStyle())
                    .accessibilityIdentifier("member.card.tickets")
                }
                tile(symbol: "wallet.pass.fill") { Text("member.card.balance", tableName: "MemberProfile") } value: {
                    Text(verbatim: snapshot?.balancePreviewText ?? "—")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .accessibilityIdentifier("member.card.balanceValue")
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("member.card.balance")
            }
            switch phase {
            case .loading:
                HStack { ProgressView(); Text("member.card.loading", tableName: "MemberProfile").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                    .accessibilityIdentifier("member.card.loading")
            case .failed(let signedOut):
                VStack(alignment: .leading, spacing: 6) {
                    Group {
                        if signedOut { Text("member.card.signedOut", tableName: "MemberProfile") }
                        else if reader.isConfigured { Text("member.card.failed", tableName: "MemberProfile") }
                        else { Text("member.card.unavailable", tableName: "MemberProfile") }
                    }.font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    if reader.isConfigured, !signedOut {
                        Button { Task { await load() } } label: { Text("member.card.retry", tableName: "MemberProfile").frame(minHeight: CYSpacing.minTouchTarget) }
                            .accessibilityIdentifier("member.card.retry")
                    }
                }.accessibilityIdentifier("member.card.failed")
            case .ready: EmptyView()
            }
            }
            .padding(CYSpacing.lg)
            .background {
                ZStack {
                    CYCoverArt(seed: "member-" + account.nickname, symbol: "person", showsDebugLabel: false, showsGlyph: false).opacity(0.38)
                    LinearGradient(colors: [.clear, CYColor.bgElevated.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(CYColor.textPrimary.opacity(0.1), lineWidth: 1))
            }
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

    @ViewBuilder private var name: some View {
        let nickname = snapshot?.nickname ?? account.nickname
        if nickname.isEmpty { Text("member.card.defaultName", tableName: "MemberProfile") } else { Text(verbatim: nickname) }
    }
    @ViewBuilder private var city: some View {
        if let value = snapshot?.city, !value.isEmpty { Text(verbatim: value) } else { Text(verbatim: "—") }
    }
    /// Remote avatar comes only from the already-loaded user-info `avatar` URL (https only);
    /// anything else, or a load failure, keeps the lettermark.
    static func remoteAvatarURL(_ raw: String?) -> URL? {
        let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.lowercased().hasPrefix("https://"), let url = URL(string: text), url.host != nil else { return nil }
        return url
    }
    private var lettermark: some View {
        let nickname = snapshot?.nickname ?? account.nickname
        return ZStack {
            Circle().fill(CYColor.accentSoft)
            if let initial = nickname.first { Text(verbatim: String(initial)).font(CYTypography.sheetTitle).foregroundStyle(CYColor.accentText) }
            else { Image(systemName: "person.fill").font(CYTypography.sheetTitle).foregroundStyle(CYColor.accentText) }
        }
        // The lettermark sits in a fixed 56pt avatar; cap its growth so large Dynamic Type cannot overflow the circle.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
    private var avatar: some View {
        ZStack {
            lettermark
            if let observation = readOwner.observation {
                MemberIdentityAvatarView(observation: observation, owner: readOwner, access: avatarAccess)
                    .id(AvatarKey(read: observation.readRevision, source: avatarAccess?.sourceRevision()))
            }
        }.frame(width: 72, height: 72).clipShape(Circle())
        .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
    private struct AvatarKey: Hashable { let read: UUID; let source: UUID? }
    private func stat(_ value: Int?, id: String, label: () -> Text) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value.map(String.init) ?? "—").font(CYTypography.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary)
            label().font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("member.card.\(id)")
    }
    private func tile<Title: View, Value: View>(symbol: String, @ViewBuilder title: () -> Title, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Image(systemName: symbol).font(.title3).foregroundStyle(CYColor.textPrimary)
            title().font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
            value().foregroundStyle(CYColor.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(CYSpacing.md)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
    }

    private func load() async {
        guard !Task.isCancelled, scenePhase == .active else { return }
        readOwner.scene(active: true)
        let scope = reader.scope
        guard let run = readOwner.begin(scope: scope) else { return }
        guard reader.isSignedIn else { phase = .failed(signedOut: true); return }
        guard reader.isConfigured else { phase = .failed(signedOut: false); return }
        if snapshot == nil { phase = .loading }
        do {
            let value = try await reader.identity()
            guard !Task.isCancelled, scope == reader.scope, readOwner.accepts(run, scope: reader.scope) else { return }
            readOwner.publish(value, run: run, scope: reader.scope)
            phase = .ready(value)
            // Streak is shown only once the identity counters are ready, as the source does.
            if value.countersReady, let growth, growth.isConfigured, growth.isAuthenticated,
               let overview = try? await growth.overview(), !Task.isCancelled, scope == reader.scope,
               readOwner.accepts(run, scope: reader.scope) {
                level = overview.center.value?.level ?? overview.progress.value?.level
                streakDays = overview.progress.value?.streakDays
            }
        } catch is CancellationError {
            readOwner.invalidate(run)
        } catch {
            guard !Task.isCancelled, scope == reader.scope, readOwner.accepts(run, scope: reader.scope) else { return }
            readOwner.invalidate(run)
            phase = .failed(signedOut: error as? APIError == .unauthorized)
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
                Text("member.benefits.unavailable", tableName: "MemberProfile").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("member.benefits.unavailable")
            case .failed:
                VStack(alignment: .leading) {
                    Text("member.benefits.failed", tableName: "MemberProfile").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
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
                .foregroundStyle(benefit.unlocked ? CYColor.accentText : CYColor.textTertiary)
            label.font(CYTypography.body).foregroundStyle(benefit.unlocked ? CYColor.textPrimary : CYColor.textSecondary)
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
