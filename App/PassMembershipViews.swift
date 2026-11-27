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
    /// MKT-4-6: month price for the footer label (platform-pass.js:138 `开通通行证 ¥X` / `续买30天 ¥X`).
    var buyPrice: String? = nil
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
    @Environment(\.locale) private var locale
    let phase: PassMembershipPhase
    let onRetry: () -> Void
    let onSelectPlan: (String) -> Void
    let onOpenLibrary: (() -> Void)?

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("membership.loading")
            case .failed:
                ContentUnavailableView {
                    Label("mp.common.loadFailed", systemImage: "exclamationmark.triangle")
                } description: {
                    EmptyView()
                } actions: {
                    Button("action.retry", action: onRetry)
                        .buttonStyle(.bordered)
                }
                .accessibilityIdentifier("membership.error")
            case .merchant:
                ContentUnavailableView("mp.member.merchant", systemImage: "tray")
                    .accessibilityIdentifier("membership.merchant")
            case .notEnabled:
                ContentUnavailableView("mp.member.off", systemImage: "tray")
                    .accessibilityIdentifier("membership.off")
            case .ready(let content):
                ready(content)
            }
        }
        .cyPushedChrome(domain: .player)
        .cyPageTitle("mp.member.title")
    }

    /// Native r2: an inset-grouped List (Settings / Wallet style). Section order follows the MP page:
    /// pass card, library row, plans (+ renewal note), 购买前须知 facts; the gated buy label stays pinned at the bottom.
    private func ready(_ content: PassMembershipContent) -> some View {
        List {
            Section { card(content) }
            if let onOpenLibrary {
                Section {
                    Button(action: onOpenLibrary) {
                        LabeledContent {
                            if let count = content.themeCount { Text("mp.member.library.count \(count)") }
                        } label: {
                            Label("mp.member.library", systemImage: "seal.fill")
                        }
                        .contentShape(Rectangle())
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("membership.library")
                }
            }
            if !content.plans.isEmpty {
                Section {
                    planButtons(content)
                } footer: {
                    if content.active { renewNote(content) }
                }
                termFacts(content)
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                // MKT-4-6: membership/index.wxml:62-65 `pp__foot` is one pill for both states, labelled by
                // platform-pass.js:138 (开通通行证 ¥X, or 续买30天 ¥X when active). 去主题库 stays on the library row.
                // Paying is money, so the label stays inert (static text) with the gate note until "money on".
                buyLabel(content).font(.body.weight(.semibold)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("membership.buy")
                Label { Text("mp.gate.purchase") } icon: { Image(systemName: "lock") }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("membership.purchaseOff")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
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
        return Section {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                LabeledContent { row.1 } label: { row.0 }
            }
        } header: {
            Text("mp.member.fact.title")
        }
        .accessibilityIdentifier("membership.terms")
    }

    private func buyLabel(_ content: PassMembershipContent) -> Text {
        switch content.buyBlock {
        case .notOnSale: return Text("mp.member.buy.notOnSale")
        case .deviceUnavailable: return Text("mp.member.buy.device")
        case nil:
            if let price = content.buyPrice {
                return content.active ? Text("mp.member.buy.renew.price \(price)") : Text("mp.member.buy.open.price \(price)")
            }
            return content.active ? Text("mp.member.buy.renew") : Text("mp.member.buy.open")
        }
    }

    private func card(_ content: PassMembershipContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("mp.member.eyebrow").font(.caption).foregroundStyle(.secondary)
                    (content.active ? Text("mp.member.active") : Text("mp.member.inactive")).font(.title2.bold())
                    if content.active, let until = content.untilText {
                        Text("mp.pass.member.until \(until)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    // MKT-4-4: plan tag, 同行可用 and 即将到期 (membership/index.wxml:20-24).
                    if content.planLabel != nil || content.teammate || content.expiring {
                        HStack(spacing: 8) {
                            if let label = content.planLabel { Text(verbatim: label) }
                            if content.teammate { Label("mp.member.teammate", systemImage: "person.2") }
                            if content.expiring {
                                Label { Text("mp.member.expiring") } icon: {
                                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                                }
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if NativeR2Flags.motion2, let index = content.plans.firstIndex(where: { $0.code == content.selectedPlan }) {
                    MotionR2PlanSymbol(index: index) // motion r2 R18: the plan symbol morphs with the selection
                }
                // MP membership/index.wxml:27 `cy-frames` glass key (184 rpx = 92 pt).
                PassGlassKeyFrames(size: 92)
            }
            // 剩余 N 天 / 共 M 天 (membership/index.wxml:30-33); hidden when either number is unknown.
            if let left = content.daysLeft, let total = content.daysTotal, total > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Double(left), total: Double(total))
                    Text("mp.member.daysLeft \(left) \(total)").font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("membership.card.progress")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("membership.card")
    }

    /// Plans as a Settings-style single choice: one row per plan, a checkmark on the selected one.
    @ViewBuilder private func planButtons(_ content: PassMembershipContent) -> some View {
        ForEach(content.plans) { plan in
            let on = plan.code == content.selectedPlan
            Button { onSelectPlan(plan.code) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: LocaleDisplay.yuanAmounts(in: plan.priceText, locale: locale)).font(.title3.bold()).monospacedDigit()
                        plan.lineText.font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if plan.best {
                        Text("mp.member.best").font(.footnote.weight(.semibold)).foregroundStyle(.tint)
                    }
                    if on {
                        Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .tint(.primary)
            .accessibilityAddTraits(on ? [.isSelected] : [])
            .accessibilityIdentifier("membership.plan.\(plan.code)")
            .sensoryFeedback(.selection, trigger: on)
        }
    }

    private func renewNote(_ content: PassMembershipContent) -> some View {
        buyLabel(content)
            .accessibilityIdentifier("membership.renew")
    }
}

/// MP `cy-frames` with `subpackageMember/images/frames/glass-key` (`MPAsset.Other.glassKey`): 24 frames on a
/// 6 × 4 sheet, 10 fps, loop, 500 ms start delay. Reduced motion holds frame 0 (cy-frames `still` for `loop`).
struct PassGlassKeyFrames: View {
    var size: CGFloat = 92
    @QuestifyReduceMotion private var reduceMotion
    @State private var start = Date().addingTimeInterval(0.5)
    private static let columns = 6
    private static let rows = 4
    private static let count = 24
    private static let fps = 10.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / Self.fps, paused: reduceMotion)) { context in
            cell(reduceMotion ? 0 : Self.frame(at: context.date.timeIntervalSince(start)))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static func frame(at elapsed: TimeInterval) -> Int {
        guard elapsed > 0 else { return 0 }
        return Int(elapsed * fps) % count
    }

    private func cell(_ frame: Int) -> some View {
        MPAsset.Other.glassKey
            .resizable()
            .interpolation(.high)
            .frame(width: size * CGFloat(Self.columns), height: size * CGFloat(Self.rows))
            .offset(x: -size * CGFloat(frame % Self.columns), y: -size * CGFloat(frame / Self.columns))
            .frame(width: size, height: size, alignment: .topLeading)
            .clipped()
    }
}

/// Glass key emblem (the reward object). Tinted only once the pass is active. Native r2: an SF Symbol, no glow or sway.
struct PassKeyEmblem: View {
    var size: CGFloat = 92
    var lit = true

    var body: some View {
        Image(systemName: "key.fill")
            .resizable().scaledToFit()
            .frame(width: size * 0.62)
            .foregroundStyle(lit ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            .frame(width: size, height: size)
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
        List {
            if showsKinds {
                // Native r2: a segmented Picker replaces the MP chip tabs (same kinds, same selection).
                Section {
                    Picker(selection: $kind) {
                        ForEach(PassLibraryKind.allCases) { option in
                            Text(option.title).tag(option)
                                .accessibilityIdentifier("passLibrary.kind.\(option.rawValue)")
                        }
                    } label: {
                        Text("mp.library.title")
                    }
                    .cyAdaptiveSegmented()
                    .labelsHidden()
                    .accessibilityIdentifier("passLibrary.kinds")
                }
            }
            switch phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("passLibrary.loading")
            case .failed(let message):
                ContentUnavailableView {
                    Label {
                        if let message { Text(verbatim: message) } else { Text("mp.library.error") }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } description: {
                    EmptyView()
                } actions: {
                    Button("action.retry") { onLoad(kind) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("passLibrary.retry")
                }
                .accessibilityIdentifier("passLibrary.error")
            case .merchant:
                ContentUnavailableView("mp.member.merchant", systemImage: "key")
                    .accessibilityIdentifier("passLibrary.merchant")
            case .off:
                ContentUnavailableView("mp.member.off", systemImage: "key")
                    .accessibilityIdentifier("passLibrary.off")
            case .ready(let cards) where cards.isEmpty:
                ContentUnavailableView("mp.library.empty", systemImage: "tray")
                    .accessibilityIdentifier("passLibrary.empty")
            case .ready(let cards):
                Section {
                    ForEach(cards) { card in
                        Group {
                            if let onOpenTopic {
                                Button { onOpenTopic(card.id) } label: { PassLibraryCardView(card: card) }
                                    .tint(.primary)
                            } else {
                                PassLibraryCardView(card: card)
                            }
                        }
                        .accessibilityIdentifier("passLibrary.card.\(card.id)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { onLoad(kind) }
        .cyPushedChrome(domain: .player)
        .cyPageTitle("mp.library.title")
        .onAppear { if !started { kind = initialKind; loadedKind = initialKind; started = true; onLoad(initialKind) } }
        .onChange(of: kind) { _, new in if started && new != loadedKind { loadedKind = new; onLoad(new) } }
    }
}

/// Native r2: a list row (Music / Books style): cover thumbnail, title, kind · minutes, "¥0 with pass" and the city.
struct PassLibraryCardView: View {
    let card: PassLibraryCard
    @ScaledMetric(relativeTo: .caption) private var pinSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var thumbWidth: CGFloat = 88

    private var kindText: Text? {
        switch card.kind {
        case .city: Text("mp.library.kind.city")
        case .free: Text("mp.library.kind.free")
        default: nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cover
                .frame(width: thumbWidth, height: thumbWidth * 0.75)
                .clipped()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: card.title).font(.headline).lineLimit(2)
                if kindText != nil || card.minutes != nil {
                    HStack(spacing: 4) {
                        if let kindText { kindText }
                        if kindText != nil && card.minutes != nil { Text(verbatim: "·") }
                        if let minutes = card.minutes { Text("mp.library.minutes \(minutes)") }
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                }
                if card.freeWithPass {
                    Text("mp.library.free").font(.footnote.weight(.semibold)).foregroundStyle(.tint)
                }
                if let city = card.city {
                    // MP `/images/cards/pin.svg`.
                    Label { Text(verbatim: city) } icon: { MPAsset.FeatureIcon.pin.resizable().scaledToFit().frame(width: pinSize, height: pinSize) }
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("mp.library.open \(card.title)"))
    }

    /// MP library/index.wxml:15 `item.cover || '/images/route_city_cover.png'`.
    @ViewBuilder private var cover: some View {
        if let url = card.coverURL, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            CYCachedAsyncImage(url, role: .cover)
        } else {
            MPAsset.BannerCover.routeCityCover.resizable().scaledToFill()
        }
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
/// MP `cy-frames` for the pass key (subpackagePass/reveal/frames.js): 3-column sprite sheets of 585×780 px frames.
/// Intro: 14 sheets, 83 frames, 18 fps, played once. Idle: 12 sheets, 72 frames, 12 fps, looped.
struct PassKeyFrames: View {
    let introStart: Date?
    let idleStart: Date
    let still: Bool

    static let frameAspect: CGFloat = 585.0 / 780.0
    static let columns = 3, rows = 2, perSheet = 6
    static let introCount = 83, introFPS = 18.0
    static let idleCount = 72, idleFPS = 12.0
    static var introDuration: TimeInterval { Double(introCount) / introFPS }
    static let introSheets: [Image] = [
        MPAsset.Other.keyIntro0,
        MPAsset.Other.keyIntro1,
        MPAsset.Other.keyIntro2,
        MPAsset.Other.keyIntro3,
        MPAsset.Other.keyIntro4,
        MPAsset.Other.keyIntro5,
        MPAsset.Other.keyIntro6,
        MPAsset.Other.keyIntro7,
        MPAsset.Other.keyIntro8,
        MPAsset.Other.keyIntro9,
        MPAsset.Other.keyIntro10,
        MPAsset.Other.keyIntro11,
        MPAsset.Other.keyIntro12,
        MPAsset.Other.keyIntro13
    ]
    static let idleSheets: [Image] = [
        MPAsset.Other.keyIdle0,
        MPAsset.Other.keyIdle1,
        MPAsset.Other.keyIdle2,
        MPAsset.Other.keyIdle3,
        MPAsset.Other.keyIdle4,
        MPAsset.Other.keyIdle5,
        MPAsset.Other.keyIdle6,
        MPAsset.Other.keyIdle7,
        MPAsset.Other.keyIdle8,
        MPAsset.Other.keyIdle9,
        MPAsset.Other.keyIdle10,
        MPAsset.Other.keyIdle11
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / Self.introFPS, paused: still)) { context in
            let (sheets, index) = frame(at: context.date)
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                let sheet = min(index / Self.perSheet, sheets.count - 1)
                let cell = index % Self.perSheet
                sheets[sheet]
                    .resizable()
                    .interpolation(.high)
                    .frame(width: w * CGFloat(Self.columns), height: h * CGFloat(Self.rows))
                    .offset(x: -w * CGFloat(cell % Self.columns), y: -h * CGFloat(cell / Self.columns))
                    .frame(width: w, height: h, alignment: .topLeading)
                    .clipped()
            }
            .aspectRatio(Self.frameAspect, contentMode: .fit)
        }
        .accessibilityHidden(true)
    }

    private func frame(at date: Date) -> ([Image], Int) {
        if still { return (Self.idleSheets, 0) }
        if let introStart {
            let elapsed = max(0, date.timeIntervalSince(introStart))
            if elapsed < Self.introDuration { return (Self.introSheets, min(Int(elapsed * Self.introFPS), Self.introCount - 1)) }
            let idle = elapsed - Self.introDuration
            return (Self.idleSheets, Int(idle * Self.idleFPS) % Self.idleCount)
        }
        let idle = max(0, date.timeIntervalSince(idleStart))
        return (Self.idleSheets, Int(idle * Self.idleFPS) % Self.idleCount)
    }
}

@MainActor struct PassRevealView: View {
    let paid: PassRevealPaidFacts?
    let accountKey: String?
    var isMerchant = false
    @Environment(\.mpParity) private var bindings
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pass_reveal_seen_v1") private var seenAccount = ""
    /// B-PR-03: set once 开始 / 跳过 has left for membership or the library (MP `wx.redirectTo`).
    @State private var redirected = false
    @QuestifyReduceMotion private var reduceMotion
    @State private var step = 0
    @State private var full = false
    @State private var route: MPParityRoute?
    @State private var timeline: Task<Void, Never>?
    @State private var skipVisible = false
    @State private var introStart: Date?
    @State private var idleStart = Date()

    /// Round 4: the MP DOM timeline (reveal/index.js `TL`): 4 gradient 3000, 5 eyebrow 3400, 6 title 3550,
    /// 7 line 3750, 8 button 4050 ms. "Skip" shows at 600 ms and goes away when the intro frames end (MP `idleOn`).
    private static let schedule: [(step: Int, ms: UInt64)] = [(4, 3000), (5, 3400), (6, 3550), (7, 3750), (8, 4050)]
    private static let skipAt: UInt64 = 600

    var body: some View {
        Group {
            if isMerchant {
                // Round 4 image parity: MP `cy-empty kind="empty"` draws the two-layer empty art (empty_state_bg + figure).
                ContentUnavailableView("mp.member.merchant", systemImage: "tray")
                    .accessibilityIdentifier("passReveal.merchant")
            } else {
                stage
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if full && skipVisible {
                ToolbarItem(placement: .topBarTrailing) {
                    // Round 4 flow (reveal/index.js `onSkip` → `_go`): 跳过 leaves the reveal for the same page as the
                    // CTA (membership, or the library after a paid order). With no destination bound it ends the intro.
                    Button("mp.reveal.skip") { skip() }.accessibilityIdentifier("passReveal.skip")
                }
            }
        }
        .mpParityRouteDestination($route)
        // B-PR-03 (MP `_go` uses redirectTo): the reveal is an interstitial, so coming back from the page it opened
        // closes it too and lands on the page underneath, instead of replaying the reveal.
        .onChange(of: route) { _, next in
            if redirected && next == nil { dismiss() }
        }
        .onAppear(perform: start)
        .onDisappear { timeline?.cancel() }
    }

    /// Native r2: the MP key frames (MPAsset sheets) over the system background, system text styles and one
    /// `.borderedProminent` CTA. The gold wash, shadow and white-on-dark stage are gone; the reveal timeline stays
    /// because it gates the CTA (`allowsHitTesting(step >= 8)`).
    private var stage: some View {
        VStack(spacing: 16) {
            Spacer()
            // MP assets (subpackagePass/reveal/frames.js): the key is the MP's baked frame sheets, not a drawn emblem.
            // Full reveal plays the 83-frame intro once at 18 fps, then the 72-frame idle loop at 12 fps; a repeat
            // visit, a skip or Reduce Motion lands on the idle loop (still frame 0 under Reduce Motion).
            PassKeyFrames(introStart: introStart, idleStart: idleStart, still: reduceMotion)
                .frame(maxHeight: 420)
            Spacer()
            VStack(spacing: 12) {
                eyebrow.font(.footnote.weight(.semibold)).foregroundStyle(.secondary).revealIn(step >= 5, reduceMotion: reduceMotion)
                title.font(.largeTitle.bold()).multilineTextAlignment(.center).revealIn(step >= 6, reduceMotion: reduceMotion)
                if let line { line.font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).revealIn(step >= 7, reduceMotion: reduceMotion) }
                Button(action: go) {
                    Text(LocalizedStringKey(paid == nil ? "mp.reveal.start" : "mp.reveal.toLibrary"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                    // B-PR-01: no destination bound → the CTA says so by being disabled, never a silent no-op.
                    .disabled(paid == nil ? bindings.membership == nil : bindings.passLibrary == nil)
                    .accessibilityIdentifier("passReveal.start")
                    .revealIn(step >= 8, reduceMotion: reduceMotion)
                    .allowsHitTesting(step >= 8)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .accessibilityElement(children: .contain)
        }
        // B-PR-05: only the toolbar 跳过 skips; the stage has no tap/drag skip and no press dim.
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
        introStart = Date()
        timeline = Task { @MainActor in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.skipAt * 1_000_000)
                if Task.isCancelled || introStart == nil { return }
                skipVisible = true
                try? await Task.sleep(nanoseconds: UInt64(PassKeyFrames.introDuration * 1000 - Double(Self.skipAt)) * 1_000_000)
                if !Task.isCancelled { skipVisible = false }
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

    private func skip() {
        let bound = paid == nil ? bindings.membership != nil : bindings.passLibrary != nil
        if bound { go() } else { finish() }
    }

    private func finish() {
        timeline?.cancel()
        skipVisible = false
        if introStart != nil { introStart = nil; idleStart = Date() }
        withAnimation(CYMotion.resolve(.easeOut(duration: 0.3), reduceMotion: reduceMotion)) { step = 8 }
    }

    private func go() {
        if paid != nil {
            if bindings.passLibrary != nil { redirected = true; route = .library(kind: .all) }
        } else if bindings.membership != nil {
            redirected = true; route = .membership
        }
    }
}

private extension View {
    /// System cross-fade only (no slide); Reduce Motion shows the end state at once.
    func revealIn(_ on: Bool, reduceMotion: Bool) -> some View {
        opacity(on ? 1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: on)
    }
}
