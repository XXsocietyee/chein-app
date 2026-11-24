import SwiftUI

// G6 entries mounted where the mini program mounts them. Each entry reads `\.g6Capabilities`; when the source,
// token, or member is nil the entry draws nothing. Money stays off: no view here buys, pays, claims, or redeems.

struct G6Capabilities {
    var source: @MainActor () -> G6CapabilitySource? = { nil }
    var token: @MainActor () -> String? = { nil }
    var member: @MainActor () -> String? = { nil }
    var flags: @MainActor () -> LaunchFeatureFlagsReader? = { nil }

    static let none = G6Capabilities()

    /// Source and token for one call, or nil (entry hidden).
    @MainActor func live() -> (source: G6CapabilitySource, token: String)? {
        guard let source = source(), let token = token() else { return nil }
        return (source, token)
    }
}

private struct G6CapabilitiesKey: EnvironmentKey {
    static let defaultValue = G6Capabilities.none
}

extension EnvironmentValues {
    var g6Capabilities: G6Capabilities {
        get { self[G6CapabilitiesKey.self] }
        set { self[G6CapabilitiesKey.self] = newValue }
    }
}

// MARK: - §17.5 promotion catalog (activity sign-up)

/// Per-screen G6 results. Loaders run on an always-drawn container (a hidden section never appears, so it cannot
/// load itself); sections read the result here. Keys are the activity id and the topic's chapter ids.
@MainActor @Observable final class G6SectionStore {
    static let shared = G6SectionStore()
    var catalogs: [Int: G6PromotionCatalog] = [:]
    var characters: [[Int]: [G6StoryCharacters.Character]] = [:]
}

/// Loads the activity's promotion catalog. Attach to the sign-up form itself.
struct G6PromotionCatalogLoader: ViewModifier {
    let activityID: Int
    @Environment(\.g6Capabilities) private var g6

    func body(content: Content) -> some View {
        content.task(id: activityID) {
            guard let live = g6.live(), activityID > 0 else { G6SectionStore.shared.catalogs[activityID] = nil; return }
            let envelope = try? await live.source.promotionCatalog(activityID: activityID, token: live.token)
            guard !Task.isCancelled else { return }
            G6SectionStore.shared.catalogs[activityID] = envelope.map(G6PromotionCatalog.init(envelope:)) ?? .empty
        }
    }
}

/// `pages/activity/baoming` 优惠 block: offers, promotions, and people tiers. Nothing is drawn when all are empty
/// or the read failed. Amounts are server text; no price is computed here.
struct G6PromotionCatalogSection: View {
    let activityID: Int
    @Environment(\.g6Capabilities) private var g6

    var body: some View {
        let catalog = G6SectionStore.shared.catalogs[activityID] ?? .empty
        if catalog.show, g6.live() != nil {
            Section("g6.promo.title") {
                ForEach(catalog.offers) { offer in
                    LabeledContent {
                        if offer.available {
                            if let save = offer.saveYuan { Text("g6.promo.save \(save)").foregroundStyle(CYColor.textPrimary) }
                        } else {
                            Text(G6Copy.promoReason(offer.reasonCode)).foregroundStyle(CYColor.textTertiary)
                        }
                    } label: { Text(verbatim: offer.name) }
                }
                ForEach(catalog.promotions) { promotion in
                    LabeledContent {
                        if promotion.eligible {
                            if let remain = promotion.remain { G6RemainText(remain: remain).foregroundStyle(CYColor.textPrimary) }
                        } else {
                            Text(G6Copy.promoReason(promotion.reasonCode)).foregroundStyle(CYColor.textTertiary)
                        }
                    } label: { Text(verbatim: promotion.name) }
                }
                ForEach(catalog.tiers) { tier in
                    LabeledContent {
                        Text("g6.promo.tier.price \(tier.unitPrice)").monospacedDigit()
                    } label: { G6TierRangeText(range: tier.range) }
                }
            }
            .accessibilityIdentifier("g6.promo.catalog")
        }
    }
}

private struct G6RemainText: View {
    let remain: G6PromotionCatalog.Remain
    var body: some View {
        switch remain {
        case .days(let days): Text("g6.promo.remain.days \(days)")
        case .hours(let hours): Text("g6.promo.remain.hours \(hours)")
        case .minutes(let minutes): Text("g6.promo.remain.minutes \(minutes)")
        }
    }
}

private struct G6TierRangeText: View {
    let range: G6PromotionCatalog.Range
    var body: some View {
        switch range {
        case .exact(let count): Text("g6.promo.tier.exact \(count)")
        case .span(let low, let high): Text("g6.promo.tier.span \(low) \(high)")
        case .from(let low): Text("g6.promo.tier.from \(low)")
        }
    }
}

enum G6Copy {
    static func promoReason(_ code: String?) -> LocalizedStringKey {
        guard let code, G6PromotionCatalog.reasonCodes.contains(code) else { return "g6.promo.unavailable" }
        return LocalizedStringKey("g6.promo.reason." + code)
    }

    static func revenueStatus(_ status: String) -> LocalizedStringKey {
        LocalizedStringKey("g6.revenue.status." + (G6RevenueAllocations.statuses.contains(status) ? status : "unknown"))
    }

    static func revenueOrder(_ type: Int?) -> LocalizedStringKey {
        switch type {
        case 1: return "g6.revenue.order.signup"
        case 2: return "g6.revenue.order.pass"
        default: return "g6.revenue.order.other"
        }
    }

    static func revenueRole(_ role: String?) -> LocalizedStringKey {
        switch role {
        case "author": return "g6.revenue.role.author"
        case "referrer": return "g6.revenue.role.referrer"
        default: return "g6.revenue.role.other"
        }
    }

    static let productReasons: Set<String> = [
        "PRODUCT_NOT_FOUND", "PRODUCT_NOT_ON_SALE", "SALE_NOT_STARTED", "SALE_ENDED", "PERIOD_ENDED", "PRODUCT_HAS_NO_CONTENT"
    ]

    /// `market-view.js` `reasonText` for the detail read. No reason keeps the generic load-failed title.
    @MainActor static func productReason(_ code: String?) -> String? {
        guard let code, !code.isEmpty else { return nil }
        let key = productReasons.contains(code) ? "g6.product.reason." + code : "g6.product.reason.other"
        return appLocalized(String.LocalizationValue(stringLiteral: key), locale: .current)
    }

    static func aiState(_ state: String) -> LocalizedStringKey {
        G6AIThemeDraft.states.contains(state) ? LocalizedStringKey("g6.ai.state." + state) : "g6.ai.state.UNKNOWN"
    }
}

// MARK: - §19 author revenue allocations (income detail)

@MainActor @Observable final class G6RevenueAllocationsModel {
    private(set) var state: G6RevenueAllocations.State = .hidden
    private(set) var loading = false
    private var generation = 0

    func load(_ g6: G6Capabilities) async {
        generation += 1
        let stamp = generation
        guard let live = g6.live() else { state = .hidden; return }
        loading = true
        defer { if stamp == generation { loading = false } }
        let envelope = try? await live.source.authorRevenue(token: live.token)
        guard stamp == generation, !Task.isCancelled else { return }
        state = envelope.map(G6RevenueAllocations.state) ?? .error
    }
}

/// Income detail 分佣 entry (`subpackageA/components/revenue-allocations`). Hidden for non-participants and empty lists.
/// A failed read says 收益暂不可用 and never shows 0. No withdraw button, rate, or rule version.
struct G6RevenueAllocationsEntry: View {
    @Environment(\.g6Capabilities) private var g6
    @State private var model = G6RevenueAllocationsModel()

    var body: some View {
        Group {
            switch model.state {
            case .hidden:
                // A drawn zero-size view, so the read below still starts while the entry is hidden.
                Color.clear.frame(width: 0, height: 0).accessibilityHidden(true)
            case .error:
                HStack(spacing: CYSpacing.sm) {
                    Label("g6.revenue.unavailable", systemImage: "exclamationmark.circle").foregroundStyle(CYColor.textSecondary)
                    Spacer(minLength: CYSpacing.sm)
                    Button("action.retry") { Task { await model.load(g6) } }.disabled(model.loading)
                }
                .padding(.horizontal)
                .accessibilityIdentifier("g6.revenue.error")
            case .ready(let rows):
                NavigationLink {
                    G6RevenueAllocationsView(rows: rows)
                } label: {
                    HStack(spacing: CYSpacing.sm) {
                        Label("g6.revenue.tab", systemImage: "person.2.badge.gearshape")
                        Spacer(minLength: CYSpacing.sm)
                        Image(systemName: "chevron.right").foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .accessibilityIdentifier("g6.revenue.open")
            }
        }
        .task { await model.load(g6) }
    }
}

struct G6RevenueAllocationsView: View {
    let rows: [G6RevenueAllocations.Row]

    var body: some View {
        List {
            Section { Text("g6.revenue.note").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            ForEach(rows) { row in
                Section {
                    HStack {
                        Text(G6Copy.revenueOrder(row.orderType)).cyText(.bodyMedium)
                        Spacer(minLength: CYSpacing.sm)
                        Text(G6Copy.revenueStatus(row.status)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    if let day = row.settleableDay {
                        Text("g6.revenue.settleableFrom \(day)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    ForEach(row.lines) { line in
                        LabeledContent {
                            if let amount = line.amountText {
                                Text(verbatim: amount).monospacedDigit()
                                    .foregroundStyle(line.reversal ? CYColor.textSecondary : CYColor.textPrimary)
                            } else {
                                Text("g6.revenue.amountPending").foregroundStyle(CYColor.textTertiary)
                            }
                        } label: {
                            if line.reversal {
                                if line.role == nil { Text("g6.revenue.reversal") }
                                else { Text("g6.revenue.reversal") + Text(verbatim: " · ") + Text(G6Copy.revenueRole(line.role)) }
                            } else {
                                Text(G6Copy.revenueRole(line.role))
                            }
                        }
                    }
                }
                .accessibilityIdentifier("g6.revenue.row.\(row.id)")
            }
        }
        .appNavigationTitle("g6.revenue.tab")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Topic main characters (`scope=node`)

/// Loads the topic's main characters: reviewed NPCs of up to four merchant stops (`scope=node`). Attach to the topic list.
struct G6TopicCharactersLoader: ViewModifier {
    let chapters: [TopicChapter]
    @Environment(\.g6Capabilities) private var g6

    func body(content: Content) -> some View {
        content.task(id: chapters.map(\.id)) {
            let key = chapters.map(\.id)
            let asks = G6StoryCharacters.asks(chapters)
            guard !asks.isEmpty, let live = g6.live() else { G6SectionStore.shared.characters[key] = nil; return }
            var rows: [(npc: [String: Any], place: String)] = []
            for ask in asks {
                guard let envelope = try? await live.source.npcNodeProfiles(nodeID: ask.nodeID, token: live.token),
                      let found = G6StoryCharacters.rows(in: envelope, place: ask.place) else { continue }
                rows.append(contentsOf: found)
            }
            guard !Task.isCancelled else { return }
            G6SectionStore.shared.characters[key] = G6StoryCharacters.build(rows)
        }
    }
}

/// Topic detail 主要角色: at most eight, deduped by name. Signed-out viewers and topics without merchant stops draw nothing.
struct G6TopicCharactersSection: View {
    let chapters: [TopicChapter]
    @Environment(\.g6Capabilities) private var g6

    var body: some View {
        let characters = G6SectionStore.shared.characters[chapters.map(\.id)] ?? []
        if !characters.isEmpty, g6.live() != nil {
            Section("g6.topic.characters") {
                ForEach(characters) { character in
                    HStack(spacing: CYSpacing.md) {
                        G6Avatar(url: character.avatar)
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            Text(verbatim: character.name).cyText(.bodyMedium)
                            if let place = character.place {
                                Text(verbatim: place).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .accessibilityIdentifier("g6.topic.characters")
        }
    }
}

private struct G6Avatar: View {
    let url: String?
    var body: some View {
        Group {
            if let url, let parsed = URL(string: url), parsed.scheme == "https" {
                AsyncImage(url: parsed) { image in image.resizable().scaledToFill() } placeholder: { placeholder }
            } else {
                placeholder
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill").accessibilityHidden(true).resizable().scaledToFit().foregroundStyle(CYColor.textTertiary)
    }
}

// MARK: - Roam NPC prompt layer

@MainActor @Observable final class G6RoamNPCPromptModel {
    private(set) var bubble: String?
    private(set) var finishLine: String?
    private var coordinator: G6RoamNPCCoordinator?
    private var flags: LaunchFeatureFlags?
    private var startedBeforeFlags = false
    private var attached = false
    private var analyticsClient: AnalyticsEventClient?
    private var analyticsSessionID = 0

    func setAnalyticsSessionID(_ id: Int) {
        analyticsSessionID = id
        coordinator?.setAnalyticsSessionID(id)
    }

    func attach(_ g6: G6Capabilities, walking: Bool, sessionID: Int = 0, analytics: AnalyticsEventClient? = nil) async {
        guard !attached else { return }
        attached = true
        analyticsClient = analytics
        analyticsSessionID = sessionID
        guard g6.live() != nil, let reader = g6.flags() else { return }
        let member = g6.member()
        let coordinator = G6RoamNPCCoordinator(ports: .init(
            now: { Date().timeIntervalSince1970 * 1000 },
            sleep: { ms in try? await Task.sleep(nanoseconds: UInt64(max(0, ms)) * 1_000_000) },
            featureOn: { [weak self] in self?.flags?.isOn("roamNpcEvent") == true },
            fetchProfile: {
                guard let live = g6.live(), let envelope = try? await live.source.npcGlobalProfile(token: live.token) else { return nil }
                return G6RoamNPCCoordinator.profileID(in: envelope)
            },
            fetchLine: { profileID, eventType in
                guard let live = g6.live(),
                      let envelope = try? await live.source.npcEventLine(profileID: profileID, eventType: eventType, token: live.token) else { return nil }
                return G6RoamNPCCoordinator.line(in: envelope)
            },
            showBubble: { [weak self] line in
                guard let self else { return false }
                self.bubble = line
                return true
            },
            showFinishLine: { [weak self] line in self?.finishLine = line },
            analytics: { [weak self] name, session in
                guard let self, let client = self.analyticsClient else { return }
                MiniProgramAnalytics.track(client, name, bizType: "roam", bizID: MiniProgramAnalytics.bizID(session), pagePath: "/pages/roam/index")
            }))
        coordinator.setAnalyticsSessionID(analyticsSessionID)
        self.coordinator = coordinator
        let outcome = await reader.load(token: g6.token())
        guard g6.member() == member, case .loaded(let loaded) = outcome else { return }
        flags = loaded
        coordinator.start()
        if startedBeforeFlags || walking { coordinator.dispatch(.sessionStarted) }
    }

    func dispatch(_ event: G6RoamNPCCoordinator.Event) {
        guard let coordinator, flags != nil else {
            if event == .sessionStarted { startedBeforeFlags = true }
            return
        }
        coordinator.dispatch(event)
    }

    func dispose() {
        coordinator?.dispose()
        coordinator = nil
        bubble = nil
    }
}

/// The roam page prompt slot (lowest priority): a reviewed NPC line at the top for 6 s, and the finish line once the
/// walk ends. Only when `roamNpcEvent` is exactly true; otherwise nothing is requested or drawn.
struct G6RoamNPCPromptModifier: ViewModifier {
    let walking: Bool
    let finished: Bool
    let uniqueTiles: Int?
    var sessionID: Int = 0
    @Environment(\.g6Capabilities) private var g6
    @Environment(\.analyticsEventClient) private var analytics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = G6RoamNPCPromptModel()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let line = model.bubble {
                    G6PromptBubble(line: line)
                        .padding(.top, CYSpacing.xl)
                        .transition(.opacity)
                        .accessibilityIdentifier("g6.roam.npcBubble")
                }
            }
            .overlay(alignment: .bottom) {
                if finished, let line = model.finishLine {
                    G6PromptBubble(line: line)
                        .padding(.bottom, CYSpacing.xl)
                        .accessibilityIdentifier("g6.roam.npcFinishLine")
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.bubble)
            .task { await model.attach(g6, walking: walking, sessionID: sessionID, analytics: analytics) }
            .onChange(of: sessionID) { _, id in model.setAnalyticsSessionID(id) }
            .onChange(of: walking) { _, now in if now { model.dispatch(.sessionStarted) } }
            .onChange(of: finished) { _, now in if now { model.dispatch(.sessionFinished) } }
            .onChange(of: uniqueTiles) { _, count in if let count { model.dispatch(.uniqueTileCountChanged(count)) } }
            .onDisappear { model.dispose() }
    }
}

private struct G6PromptBubble: View {
    let line: String
    var body: some View {
        Text(verbatim: line)
            .cyText(.bodyMedium)
            .foregroundStyle(CYColor.textPrimary)
            .padding(.horizontal, CYSpacing.lg)
            .padding(.vertical, CYSpacing.md)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - AI draft history (`/api/ai/theme/draft/recovery`)

/// Simple-publish 起草记录: server history newest first, read only, plus the explicit "start a new draft"
/// confirmation when the saved identity is unknown. Nothing here executes a history row.
struct G6AIThemeDraftRecoverySection: View {
    @Environment(\.g6Capabilities) private var g6
    @State private var page: G6AIThemeDraftRecoveryPage?
    @State private var cursors: [String] = []
    @State private var failed = false
    @State private var loading = false
    @State private var canConfirmNew = false
    @State private var confirming = false
    @State private var armed = false

    var body: some View {
        if g6.live() != nil {
            Section("g6.ai.history.title") {
                if let page {
                    if page.items.isEmpty { Text("g6.ai.history.empty").foregroundStyle(CYColor.textSecondary) }
                    ForEach(page.items) { item in
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            Text(G6Copy.aiState(item.state)).cyText(.bodyMedium)
                            Text(verbatim: item.requestID + " · " + item.createdAtText)
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary).textSelection(.enabled)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if let next = page.nextCursor {
                        Button("g6.ai.history.more") { Task { await load(before: next) } }.disabled(loading)
                    }
                    if !cursors.isEmpty {
                        Button("g6.ai.history.latest") { Task { cursors = []; await load(before: nil) } }.disabled(loading)
                    }
                } else if failed {
                    Text("g6.ai.history.failed").foregroundStyle(CYColor.textSecondary)
                }
                Button("g6.ai.history.open") { Task { cursors = []; await load(before: nil) } }
                    .disabled(loading)
                    .accessibilityIdentifier("g6.ai.history.open")
                if canConfirmNew {
                    Button(armed ? LocalizedStringKey("g6.ai.confirmNew.armed") : LocalizedStringKey("g6.ai.confirmNew.open")) { confirming = true }
                        .disabled(armed)
                        .accessibilityIdentifier("g6.ai.confirmNew")
                }
            }
            .task { refreshConfirmState() }
            .confirmationDialog("g6.ai.confirmNew.title", isPresented: $confirming, titleVisibility: .visible) {
                Button("g6.ai.confirmNew.confirm") { G6AIThemeDraftAdapter.confirmedNew = true; armed = true }
                Button("g6.ai.confirmNew.keep", role: .cancel) {}
            } message: { Text("g6.ai.confirmNew.message") }
        }
    }

    private func refreshConfirmState() {
        guard let source = g6.source() else { canConfirmNew = false; return }
        let flow = G6AIThemeDraftFlow(source: source, store: G6DefaultsRequestStore.shared, member: g6.member, token: g6.token)
        canConfirmNew = flow.canConfirmNew
        armed = G6AIThemeDraftAdapter.confirmedNew
    }

    private func load(before: String?) async {
        guard let live = g6.live() else { return }
        loading = true
        defer { loading = false; refreshConfirmState() }
        let envelope = try? await live.source.aiDraftRecovery(beforeID: before, token: live.token)
        guard let envelope, envelope.ok, let parsed = G6AIThemeDraftRecoveryPage(envelope.data, before: before) else {
            failed = true
            page = nil
            return
        }
        if let before { cursors.append(before) }
        failed = false
        page = parsed
    }
}
