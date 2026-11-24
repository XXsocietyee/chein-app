import SwiftUI

// Mini-program `subpackageMember/market/membership` (platform pass), `market/library` (playable theme library) and
// `subpackagePass/reveal` (key reveal intro). Opening / renewing the pass is a payment and stays OFF (`MPCommerceGate`):
// plans and prices are shown read-only. Merchant accounts have no pass: one sentence only.

// MARK: - Membership

struct PassPlanCard: Identifiable, Equatable {
    enum Line: Equatable {
        /// Year plan: "under ¥X a month".
        case year(monthlyText: String)
        case month
        case custom(title: String, days: Int?)
    }
    let code: String
    let priceText: String
    let line: Line
    let best: Bool
    var id: String { code }

    var lineText: Text {
        switch line {
        case .year(let monthly): Text("mp.member.plan.year \(monthly)")
        case .month: Text("mp.member.plan.month")
        case .custom(let title, let days):
            if let days { Text(verbatim: "\(title) · ") + Text("mp.member.plan.days \(days)") } else { Text(verbatim: title) }
        }
    }
}

enum PassBuyBlock: Equatable {
    /// No plans on sale.
    case notOnSale
    /// No usable channel on this device.
    case deviceUnavailable
}

struct PassMembershipContent: Equatable {
    var active: Bool
    var untilText: String?
    /// Library theme count (`libraryCount`); nil hides the count line, never 0.
    var themeCount: Int?
    var plans: [PassPlanCard]
    var selectedPlan: String?
    var buyBlock: PassBuyBlock?
    /// Plan code → server `validDays`, for the 有效期 fact of the selected plan.
    var validDays: [String: Int] = [:]
    /// MKT-4-4: active-pass card facts. Nil / false leaves the fact off the card.
    var planLabel: String? = nil
    var teammate = false
    var expiring = false
    var daysLeft: Int? = nil
    var daysTotal: Int? = nil
    /// Server `overview.terms` (OR-024). Server text wins over the fixed renewal / refund lines.
    var terms: PlatformPassTermFacts = .empty
}

enum PassMembershipPhase: Equatable {
    case loading
    case failed
    case merchant
    case notEnabled
    case ready(PassMembershipContent)
}

/// Logic stub for Cursor: `GET /api/platform-pass` (+ merchant role). Purchase (`platform-pass-pay`) stays unbound.
@MainActor protocol PassMembershipBinding: AnyObject, Observable {
    var phase: PassMembershipPhase { get }
    func load()
    func selectPlan(_ code: String)
}

@MainActor struct PassMembershipHost: View {
    let binding: any PassMembershipBinding
    @State private var route: MPParityRoute?
    @Environment(\.mpParity) private var bindings
    var body: some View {
        PassMembershipView(phase: binding.phase, onRetry: { binding.load() }, onSelectPlan: { binding.selectPlan($0) },
                           onOpenLibrary: bindings.passLibrary == nil ? nil : { route = .library(kind: .all) })
            .task { binding.load() }
            .mpParityRouteDestination($route)
    }
}

struct PassMembershipView: View {
    let phase: PassMembershipPhase
    let onRetry: () -> Void
    let onSelectPlan: (String) -> Void
    let onOpenLibrary: (() -> Void)?
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        Group {
            switch phase {
            case .loading:
                CYLoadingStateView(rows: 3).padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityIdentifier("membership.loading")
            case .failed:
                CYErrorState("mp.common.loadFailed", onRetry: onRetry).frame(maxHeight: .infinity).accessibilityIdentifier("membership.error")
            case .merchant:
                CYEmptyState(systemImage: "key", "mp.member.merchant", messageIdentifier: "membership.merchant").frame(maxHeight: .infinity)
            case .notEnabled:
                CYEmptyState(systemImage: "key", "mp.member.off", messageIdentifier: "membership.off").frame(maxHeight: .infinity)
            case .ready(let content):
                ready(content)
            }
        }
        .cyPushedChrome(domain: .player)
        .cyPageTitle("mp.member.title")
    }

    private func ready(_ content: PassMembershipContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                card(content)
                if let onOpenLibrary {
                    Button(action: onOpenLibrary) {
                        MPCard {
                            MPRow(title: Text("mp.member.library"),
                                  sub: content.themeCount.map { Text("mp.member.library.count \($0)") },
                                  chevron: true,
                                  leading: AnyView(Image(systemName: "seal.fill").cyText(.cardTitle).foregroundStyle(CYNight.lantern).frame(width: 32)))
                        }
                    }
                    .buttonStyle(.cyPressable)
                    .accessibilityIdentifier("membership.library")
                }
                if !content.plans.isEmpty { plans(content) }
                if content.active && !content.plans.isEmpty { renewNote(content) }
                if !content.plans.isEmpty { termFacts(content) }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.jumbo)
        }
        .safeAreaInset(edge: .bottom) {
            MPBottomBar {
                if content.active {
                    // Active footer is always 去主题库 (pp__foot); without a library binding it stays read-only, never a buy label.
                    if let onOpenLibrary {
                        CYPillButton("mp.member.toLibrary", action: onOpenLibrary).accessibilityIdentifier("membership.toLibrary")
                    }
                } else {
                    buyLabel(content).cyText(.bodyMedium).foregroundStyle(CYColor.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(CYColor.bgElevated, in: Capsule())
                        .accessibilityAddTraits(.isStaticText)
                        .accessibilityIdentifier("membership.buy")
                    MPGatedNote(text: Text("mp.gate.purchase"), identifier: "membership.purchaseOff")
                }
            }
        }
    }

    /// `platform-pass.js` `factRows`: 购买前须知 from server facts; a missing fact is left out, never invented.
    /// 可玩主题 = library count, else `terms.coverage`; 适用范围 = `terms.seat`; 有效期 = `terms.period`, else plan days.
    /// 续费 / 退款规则 use the server text when `overview.terms` sent it, else the fixed OR-024 lines (`termRows`).
    private func termFacts(_ content: PassMembershipContent) -> some View {
        var rows: [(Text, Text)] = []
        let terms = content.terms
        func server(_ value: String?) -> String? {
            guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }
        if let count = content.themeCount { rows.append((Text("mp.member.fact.themes"), Text("mp.member.fact.themes.value \(count)"))) }
        else if let coverage = server(terms.coverage) { rows.append((Text("mp.member.fact.themes"), Text(verbatim: coverage))) }
        if let seat = server(terms.seat) { rows.append((Text("mp.member.fact.seat"), Text(verbatim: seat))) }
        if let period = server(terms.period) {
            rows.append((Text("mp.member.fact.period"), Text(verbatim: period)))
        } else if let code = content.selectedPlan, let days = content.validDays[code] {
            rows.append((Text("mp.member.fact.period"), Text("mp.member.plan.days \(days)")))
        }
        rows.append((Text("mp.member.fact.renewal"), server(terms.renewal).map { Text(verbatim: $0) } ?? Text("mp.member.fact.renewal.value")))
        rows.append((Text("mp.member.fact.refund"), server(terms.refund).map { Text(verbatim: $0) } ?? Text("mp.member.fact.refund.value")))
        return VStack(alignment: .leading, spacing: CYSpacing.sm) {
            MPSectionHeader(title: "mp.member.fact.title")
            MPCard {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { MPDivider() }
                    MPRow(title: row.0, value: row.1)
                }
            }
        }
        .accessibilityIdentifier("membership.terms")
    }

    private func buyLabel(_ content: PassMembershipContent) -> Text {
        switch content.buyBlock {
        case .notOnSale: Text("mp.member.buy.notOnSale")
        case .deviceUnavailable: Text("mp.member.buy.device")
        case nil: content.active ? Text("mp.member.buy.renew") : Text("mp.member.buy.open")
        }
    }

    private func card(_ content: PassMembershipContent) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("mp.member.eyebrow").cyText(.caption).tracking(0.6).foregroundStyle(CYColor.textSecondary)
                    (content.active ? Text("mp.member.active") : Text("mp.member.inactive")).cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                    if content.active, let until = content.untilText {
                        Text("mp.pass.member.until \(until)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    // MKT-4-4: plan tag, 同行可用 and 即将到期 (membership/index.wxml:20-24).
                    if content.planLabel != nil || content.teammate || content.expiring {
                        HStack(spacing: CYSpacing.xs) {
                            if let label = content.planLabel { CYStatusChip(verbatim: label) }
                            if content.teammate { CYStatusChip("mp.member.teammate") }
                            if content.expiring { CYStatusChip("mp.member.expiring", tone: .warning) }
                        }
                    }
                }
                Spacer()
                PassKeyEmblem(size: 92, lit: content.active)
            }
            // 剩余 N 天 / 共 M 天 (membership/index.wxml:30-33); hidden when either number is unknown.
            if let left = content.daysLeft, let total = content.daysTotal, total > 0 {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    ProgressView(value: Double(left), total: Double(total)).tint(CYColor.brand)
                    Text("mp.member.daysLeft \(left) \(total)").cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary)
                }
                .accessibilityIdentifier("membership.card.progress")
            }
        }
        .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("membership.card")
    }

    private func plans(_ content: PassMembershipContent) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CYSpacing.md) { planButtons(content) }
            VStack(spacing: CYSpacing.md) { planButtons(content) }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func planButtons(_ content: PassMembershipContent) -> some View {
        ForEach(content.plans) { plan in
            let on = plan.code == content.selectedPlan
            Button { onSelectPlan(plan.code) } label: {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: plan.priceText).cyText(.dataXL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                    plan.lineText.cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                .padding(CYSpacing.lg)
                .background(on ? CYColor.bgRaised : CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
                    .strokeBorder(on ? CYColor.selection : Color.clear, lineWidth: on ? 2 : 0))
                .overlay(alignment: .topTrailing) {
                    if plan.best {
                        Text("mp.member.best").cyText(.micro).foregroundStyle(CYNight.ink0)
                            .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                            .background(CYNight.lantern, in: Capsule())
                            .offset(x: -CYSpacing.sm, y: -CYSpacing.sm)
                    }
                }
                .scaleEffect(on && !reduceMotion ? 1.02 : 1)
                .cyAnimation(.spring(response: 0.3, dampingFraction: 0.7), value: on)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(on ? [.isSelected] : [])
            .accessibilityIdentifier("membership.plan.\(plan.code)")
            .cyHaptic(.selection, trigger: on)
        }
    }

    private func renewNote(_ content: PassMembershipContent) -> some View {
        buyLabel(content).cyText(.label).foregroundStyle(CYColor.textTertiary)
            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
            .background(CYColor.bgElevated, in: Capsule())
            .accessibilityIdentifier("membership.renew")
    }
}

/// Glass key emblem (the reward object). Lantern light only once the pass is active.
struct PassKeyEmblem: View {
    var size: CGFloat = 92
    var lit = true
    @State private var sway = false
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        ZStack {
            if lit { Circle().fill(CYNight.glow(radius: size / 2)).frame(width: size * 1.6, height: size * 1.6) }
            Image(systemName: "key.fill")
                .resizable().scaledToFit()
                .frame(width: size * 0.62)
                .foregroundStyle(lit ? AnyShapeStyle(LinearGradient(colors: [CYNight.lanternHot, CYNight.lantern, CYNight.ember], startPoint: .top, endPoint: .bottom))
                                     : AnyShapeStyle(CYColor.textTertiary))
                .rotationEffect(.degrees(sway ? 8 : -8))
                .animation(reduceMotion || !lit ? nil : .easeInOut(duration: 3).repeatForever(autoreverses: true), value: sway)
        }
        .frame(width: size, height: size)
        .onAppear { sway = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Library

enum PassLibraryKind: String, CaseIterable, Identifiable, Hashable {
    case all, city, free
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .all: "mp.library.kind.all"
        case .city: "mp.library.kind.city"
        case .free: "mp.library.kind.free"
        }
    }
}

struct PassLibraryCard: Identifiable, Equatable {
    let id: String
    let title: String
    let coverURL: String?
    let city: String?
    /// 1 city orienteering, 2 free explore.
    let kind: PassLibraryKind?
    /// Minutes, already rounded; nil hides the duration.
    let minutes: Int?
    /// "¥0 with pass" only when the server stated coverage (`covered == true`).
    let freeWithPass: Bool
}

enum PassLibraryPhase: Equatable {
    case loading
    case failed(String?)
    case merchant
    case off
    case ready([PassLibraryCard])
}

/// Logic stub for Cursor: `GET /api/platform-pass/library?productType=`.
@MainActor protocol PassLibraryBinding: AnyObject, Observable {
    var phase: PassLibraryPhase { get }
    func load(kind: PassLibraryKind)
}

@MainActor struct PassLibraryHost: View {
    let binding: any PassLibraryBinding
    var initialKind: PassLibraryKind = .all
    var onOpenTopic: ((String) -> Void)? = nil
    @State private var route: MPParityRoute?
    var body: some View {
        PassLibraryView(phase: binding.phase, initialKind: initialKind, onLoad: { binding.load(kind: $0) },
                        onOpenTopic: onOpenTopic ?? openTopic)
            .mpParityRouteDestination($route)
    }

    /// `market/library` card → `pages/topic/index/index?id=` (the topic detail).
    private func openTopic(_ id: String) {
        guard let value = Int(id), value > 0, String(value) == id else { return }
        route = .screen(page: "pages/topic/index/index", query: ["id": id])
    }
}

struct PassLibraryView: View {
    let phase: PassLibraryPhase
    var initialKind: PassLibraryKind = .all
    let onLoad: (PassLibraryKind) -> Void
    let onOpenTopic: ((String) -> Void)?
    @State private var kind: PassLibraryKind = .all
    @State private var loadedKind: PassLibraryKind?
    @State private var started = false

    private var showsKinds: Bool {
        switch phase {
        case .merchant, .off: false
        default: true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if showsKinds {
                    MPChipTabs(tabs: PassLibraryKind.allCases, selection: $kind, title: { Text($0.title) }, identifier: { "passLibrary.kind.\($0.rawValue)" })
                }
                Group {
                    switch phase {
                    case .loading:
                        CYLoadingStateView(rows: 3).accessibilityIdentifier("passLibrary.loading")
                    case .failed(let message):
                        CYStateLayout(kind: .failure, title: message.map { Text(verbatim: $0) } ?? Text("mp.library.error"),
                                      primary: (title: "action.retry", action: { onLoad(kind) }), primaryStyle: .secondary, primaryIdentifier: "passLibrary.retry")
                            .accessibilityIdentifier("passLibrary.error")
                    case .merchant:
                        CYEmptyState(systemImage: "key", "mp.member.merchant", messageIdentifier: "passLibrary.merchant")
                    case .off:
                        CYEmptyState(systemImage: "key", "mp.member.off", messageIdentifier: "passLibrary.off")
                    case .ready(let cards) where cards.isEmpty:
                        CYEmptyState(systemImage: "map", "mp.library.empty", messageIdentifier: "passLibrary.empty")
                    case .ready(let cards):
                        LazyVStack(spacing: CYSpacing.md) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                Group {
                                    if let onOpenTopic {
                                        Button { onOpenTopic(card.id) } label: { PassLibraryCardView(card: card) }.buttonStyle(.cyPressable)
                                    } else {
                                        PassLibraryCardView(card: card)
                                    }
                                }
                                .cyStaggerAppear(min(index, 7))
                                .accessibilityIdentifier("passLibrary.card.\(card.id)")
                            }
                        }
                    }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
            }
            .padding(.vertical, CYSpacing.lg)
        }
        .refreshable { onLoad(kind) }
        .cyPushedChrome(domain: .player)
        .cyPageTitle("mp.library.title")
        .onAppear { if !started { kind = initialKind; loadedKind = initialKind; started = true; onLoad(initialKind) } }
        .onChange(of: kind) { _, new in if started && new != loadedKind { loadedKind = new; onLoad(new) } }
    }
}

/// Club-style photo card: cover, bottom ink gradient, top row (city mark + "¥0 with pass" + city), title, one data line, tags.
struct PassLibraryCardView: View {
    let card: PassLibraryCard

    private var kindText: Text? {
        switch card.kind {
        case .city: Text("mp.library.kind.city")
        case .free: Text("mp.library.kind.free")
        default: nil
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CYCachedAsyncImage(card.coverURL, role: .cover)
                .overlay(LinearGradient(colors: [.clear, CYNight.ink0.opacity(0.92)], startPoint: .center, endPoint: .bottom))
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: card.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).lineLimit(2)
                HStack(spacing: CYSpacing.xs) {
                    if let kindText { kindText }
                    if kindText != nil && card.minutes != nil { Text(verbatim: "·") }
                    if let minutes = card.minutes { Text("mp.library.minutes \(minutes)") }
                }
                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                // photo-card__bottom: tag chips (kind, city) + chevron, as on the club card.
                HStack(spacing: CYSpacing.xs) {
                    if let kindText { tag(kindText) }
                    if let city = card.city { tag(Text(verbatim: city)) }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.top, CYSpacing.xxs)
            }
            .padding(CYSpacing.lg)
        }
        .overlay(alignment: .top) {
            HStack(spacing: CYSpacing.sm) {
                // photo-card__logo: the 城 mark.
                Text("mp.library.cityMark").cyText(.caption, weight: .bold).foregroundStyle(CYColor.textPrimary)
                    .frame(width: 28, height: 28)
                    .cyNightGlass(in: RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous))
                    .accessibilityHidden(true)
                if card.freeWithPass {
                    Text("mp.library.free").cyText(.caption).foregroundStyle(CYNight.ink0)
                        .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                        .background(CYNight.lantern, in: Capsule())
                }
                Spacer()
                if let city = card.city {
                    Label { Text(verbatim: city) } icon: { Image(systemName: "mappin") }
                        .cyText(.caption).foregroundStyle(CYColor.textPrimary)
                        .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                        .cyNightGlass(in: Capsule())
                }
            }
            .padding(CYSpacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("mp.library.open \(card.title)"))
    }

    private func tag(_ text: Text) -> some View {
        text.cyText(.caption).foregroundStyle(CYColor.textPrimary)
            .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
            .background(CYColor.textPrimary.opacity(0.14), in: Capsule())
    }
}

// MARK: - Reveal

/// Facts the membership page passes after a PAID order (count and until only when the server gave them).
struct PassRevealPaidFacts: Hashable {
    let count: Int?
    let untilText: String?
}

/// Key reveal (l-icons ps-key): shards fly in and fuse into the key, a warm gradient rises, then eyebrow / title / line /
/// button follow. The full version plays the first time per account and after a paid order; later visits land on the
/// idle state. Reduce Motion: the end state at once. "Skip" appears shortly after the start, only in the full version.
@MainActor struct PassRevealView: View {
    let paid: PassRevealPaidFacts?
    let accountKey: String?
    var isMerchant = false
    @Environment(\.mpParity) private var bindings
    @AppStorage("pass_reveal_seen_v1") private var seenAccount = ""
    @QuestifyReduceMotion private var reduceMotion
    @State private var step = 0
    @State private var full = false
    @State private var route: MPParityRoute?
    @State private var timeline: Task<Void, Never>?
    @State private var skipVisible = false

    /// 1 shards in, 2 key fused, 4 gradient, 5 eyebrow, 6 title, 7 line, 8 button. "Skip" shows at 600 ms.
    private static let schedule: [(step: Int, ms: UInt64)] = [(1, 60), (2, 900), (4, 1500), (5, 1800), (6, 1950), (7, 2150), (8, 2450)]
    private static let skipAt: UInt64 = 600

    var body: some View {
        Group {
            if isMerchant {
                CYEmptyState(systemImage: "key", "mp.member.merchant", messageIdentifier: "passReveal.merchant").frame(maxHeight: .infinity)
            } else {
                stage
            }
        }
        .background(CYNight.ink0.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if full && skipVisible && step < 8 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("mp.reveal.skip") { finish() }.accessibilityIdentifier("passReveal.skip")
                }
            }
        }
        // B-PR-06-r7: the MP stage runs behind a transparent nav bar.
        .toolbarBackground(.hidden, for: .navigationBar)
        .mpParityRouteDestination($route)
        .onAppear(perform: start)
        .onDisappear { timeline?.cancel() }
    }

    private var stage: some View {
        VStack(spacing: CYSpacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(CYNight.glow(radius: 110)).frame(width: 360, height: 360).opacity(step >= 2 ? 1 : 0)
                ForEach(0..<8, id: \.self) { index in
                    let angle = Double(index) / 8 * 2 * .pi
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(colors: [CYNight.lanternHot, CYNight.lantern], startPoint: .top, endPoint: .bottom))
                        .frame(width: 14, height: 26)
                        .rotationEffect(.radians(angle))
                        .offset(x: step >= 2 ? 0 : cos(angle) * 160, y: step >= 2 ? 0 : sin(angle) * 220)
                        .opacity(step >= 1 && step < 2 ? 0.9 : 0)
                        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.75).delay(Double(index) * 0.03), value: step)
                }
                PassKeyEmblem(size: 180, lit: true)
                    .scaleEffect(step >= 2 ? 1 : 0.4)
                    .opacity(step >= 2 ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.62), value: step >= 2)
                    // B-PR-02: after the reveal the key keeps a slow idle breath (MP idle frame loop); Reduce Motion stays still.
                    .phaseAnimator([false, true]) { view, phase in
                        view.scaleEffect(step >= 8 && !reduceMotion && phase ? 1.04 : 1)
                            .shadow(color: CYNight.passGold2.opacity(step >= 8 && !reduceMotion && phase ? 0.55 : 0.2), radius: phase ? 28 : 12)
                    } animation: { _ in .easeInOut(duration: 1.6) }
            }
            .frame(height: 320)
            .accessibilityHidden(true)
            Spacer()
            VStack(spacing: CYSpacing.md) {
                // B-PR-04: MP eyebrow is spaced caps (≈0.32 em) in white 72%, text sits on the gold wash with a soft shadow.
                eyebrow.cyText(.label).tracking(3.5).foregroundStyle(Color.white.opacity(0.72)).revealIn(step >= 5, reduceMotion: reduceMotion)
                title.cyText(.display).foregroundStyle(Color.white).multilineTextAlignment(.center).revealIn(step >= 6, reduceMotion: reduceMotion)
                if let line { line.cyText(.body).foregroundStyle(Color.white.opacity(0.78)).multilineTextAlignment(.center).revealIn(step >= 7, reduceMotion: reduceMotion) }
                Button(action: go) {
                    Text(LocalizedStringKey(paid == nil ? "mp.reveal.start" : "mp.reveal.toLibrary"))
                        .cyText(.bodyMedium, weight: .semibold)
                        .foregroundStyle(CYNight.ink0)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.white, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                    // B-PR-01: no destination bound → the CTA says so by being disabled, never a silent no-op.
                    .disabled(paid == nil ? bindings.membership == nil : bindings.passLibrary == nil)
                    .accessibilityIdentifier("passReveal.start")
                    .revealIn(step >= 8, reduceMotion: reduceMotion)
                    .allowsHitTesting(step >= 8)
                    .padding(.top, CYSpacing.sm)
            }
        .padding(.horizontal, CYSpacing.xxl)
        .padding(.bottom, CYSpacing.xxl)
        .accessibilityElement(children: .contain)
        .shadow(color: CYNight.passGold0.opacity(0.45), radius: 8, y: 1)
        }
        // B-PR-05: only the toolbar 跳过 skips; the stage has no tap/drag skip and no press dim.
        .background(alignment: .bottom) {
            // B-PR-02: MP gold wash over the lower 62 % of the stage.
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: CYNight.passGold0, location: 0.30),
                        .init(color: CYNight.passGold1, location: 0.55),
                        .init(color: CYNight.passGold2, location: 0.80),
                        .init(color: CYNight.passGold3, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                    .frame(height: proxy.size.height * 0.62)
                    .offset(y: step >= 4 ? 0 : proxy.size.height * 0.62)
                }
            }
            .animation(reduceMotion ? nil : .timingCurve(0.2, 0.7, 0.2, 1, duration: 1.1), value: step >= 4)
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
    }

    private var eyebrow: Text { paid == nil ? Text("mp.reveal.eyebrow") : Text("mp.reveal.eyebrowPaid") }
    private var title: Text {
        guard let paid else { return Text("mp.reveal.title") }
        if let count = paid.count { return Text("mp.reveal.titlePaid \(count)") }
        return Text("mp.member.active")
    }
    private var line: Text? {
        guard let paid else { return Text("mp.reveal.line") }
        return paid.untilText.map { Text("mp.reveal.linePaid \($0)") }
    }

    private func start() {
        guard !isMerchant, step == 0 else { return }
        let key = accountKey.flatMap { $0.isEmpty ? nil : $0 } ?? "guest"
        let firstTime = seenAccount != key
        full = !reduceMotion && (paid != nil || firstTime)
        seenAccount = key
        guard full else { finish(); return }
        timeline = Task { @MainActor in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.skipAt * 1_000_000)
                if !Task.isCancelled { skipVisible = true }
            }
            var elapsed: UInt64 = 0
            for item in Self.schedule {
                try? await Task.sleep(nanoseconds: (item.ms - elapsed) * 1_000_000)
                elapsed = item.ms
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.35)) { step = max(step, item.step) }
            }
        }
    }

    private func finish() {
        timeline?.cancel()
        withAnimation(CYMotion.resolve(.easeOut(duration: 0.3), reduceMotion: reduceMotion)) { step = 8 }
    }

    private func go() {
        if paid != nil {
            if bindings.passLibrary != nil { route = .library(kind: .all) }
        } else if bindings.membership != nil {
            route = .membership
        }
    }
}

private extension View {
    func revealIn(_ on: Bool, reduceMotion: Bool) -> some View {
        opacity(on ? 1 : 0).offset(y: on || reduceMotion ? 0 : 12)
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: on)
    }
}
