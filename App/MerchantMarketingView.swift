import SwiftUI

/// Additive host destination. Feature visibility and all service grants are independently default off.
@MainActor struct MerchantMarketingEntry: View {
    let model: MerchantMarketingCoordinator
    var isSourceVisible = false
    var onSuggestion: (MerchantInsightDestination) -> Void = { _ in }
    var suggestionDestination: ((MerchantInsightDestination) -> AnyView)? = nil
    var recommendationOrigin: MerchantInsightOrigin? = nil
    @State private var selectedSuggestion: MerchantInsightDestination?
    var body: some View {
        if isSourceVisible {
            NavigationLink {
                MerchantMarketingView(model: model, recommendationOrigin: suggestionDestination == nil ? nil : recommendationOrigin,
                    onSuggestion: { route in onSuggestion(route); selectedSuggestion = route })
                    .navigationDestination(item: $selectedSuggestion) { route in
                        Group {
                            if case .recommendation(let target) = route, target.origin != recommendationOrigin { AnyView(Text("merchantMarketing.stale")) }
                            else if case .cooperationSettings(let origin) = route, origin != recommendationOrigin { AnyView(Text("merchantMarketing.stale")) }
                            else if case .cooperationCenter(let origin) = route, origin != recommendationOrigin { AnyView(Text("merchantMarketing.stale")) }
                            else if let suggestionDestination { suggestionDestination(route) }
                            else { AnyView(Text("merchantMarketing.unavailable")) }
                        }
                        .cyPushedChrome(domain: .merchant)
                    }
            } label: { Label("merchantMarketing.dashboard", systemImage: "chart.bar.xaxis") }
            .accessibilityIdentifier("merchantMarketing.entry")
            .onChange(of: recommendationOrigin) { _, _ in selectedSuggestion = nil }
            .onChange(of: model.scopeIdentity) { _, _ in selectedSuggestion = nil }
        }
    }
}

@MainActor struct MerchantMarketingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Bindable var model: MerchantMarketingCoordinator
    var onSuggestion: (MerchantInsightDestination) -> Void = { _ in }
    let recommendationOrigin: MerchantInsightOrigin?
    @State private var selected: MerchantMarketingCoordinator.Surface = .dashboard
    @State private var loadedRecommendationOrigin: MerchantInsightOrigin?
    @State private var refreshTask: Task<Void, Never>?
    @State private var marketingPush: MerchantMarketingPush?
    @Environment(\.merchantMarketingLinks) private var marketingLinks
    @Environment(\.merchantPredictionWorkbenchEntry) private var predictionEntry
    private var loadKey: String { selected.rawValue + ":" + model.scopeIdentity + ":" + (recommendationOrigin?.readerScope.uuidString ?? "none") + ":" + String(recommendationOrigin?.merchantID ?? 0) }
    init(model: MerchantMarketingCoordinator, initialSurface: MerchantMarketingCoordinator.Surface = .dashboard, recommendationOrigin: MerchantInsightOrigin? = nil, onSuggestion: @escaping (MerchantInsightDestination) -> Void = { _ in }) {
        self.model = model; self.onSuggestion = onSuggestion; self.recommendationOrigin = recommendationOrigin; _selected = State(initialValue: initialSurface)
    }
    /// MC7-10-1 / MC7-11-6: signed out replaces the page (no picker) with 登录后查看营销 / 请先登录 + 登录.
    private var needsSignIn: Bool { model.failure == .signIn && !model.busy }
    /// MC7-11-5 (ai-insight/index.wxml:5): 店铺参谋 shows only for marketing readers.
    private var surfaces: [MerchantMarketingCoordinator.Surface] {
        MerchantMarketingCoordinator.Surface.allCases.filter { item in
            if item == .insight { return model.homeAccess?.canReadMarketing != false }
            // MC7-18-4: one prediction inbox (pages/merchant/predict) owns selection and settlement; the 营销 copy
            // of it is dropped wherever the inbox entry is available.
            if item == .predictions { return predictionEntry == nil }
            return true
        }
    }
    var body: some View {
        Group {
        if needsSignIn {
            MerchantSignInState(title: selected == .insight ? "merchant.gate.insight.signIn" : "merchant.gate.marketing.signIn",
                                identifier: "merchantMarketing.signIn")
        } else {
        List {
            // Figma 182:8065 · Merchant/Root Header: 营销 as the large leading title; refresh is a trailing glass circle.
            MerchantRootHeader(OpsR3Text.text("r3merchant.root.marketing")) {
                Button { refreshTask?.cancel(); refreshTask = Task { await loadSurface() } } label: {
                    CYHeaderCircleLabel(systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(model.busy)
                .accessibilityLabel(Text("merchantMarketing.refresh"))
            }
            .merchantRootHeaderRow()
            Section {
                Picker("merchantMarketing.section", selection: $selected) {
                    ForEach(surfaces) { item in Text(LocalizedStringKey(item.titleKey)).tag(item) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("merchantMarketing.sectionPicker")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            if model.isRefreshingKeptValues {
                Label { Text("merchant.marketing.refreshing").cyText(.meta) } icon: { ProgressView().controlSize(.mini) }
                    .foregroundStyle(CYColor.textSecondary)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("merchantMarketing.refreshing")
            } else if model.busy {
                CYSkeleton()
                    .accessibilityLabel(Text("merchantMarketing.loading"))
                    .listRowBackground(Color.clear)
            }
            if let error = model.failure { failure(error) }
            if let result = model.acknowledgement {
                Section("merchantMarketing.acknowledged") {
                    LabeledContent("merchantMarketing.winners", value: String(result.winners))
                        .accessibilityIdentifier("merchantMarketing.winners")
                }
            }
            if let home = model.home, let access = model.homeAccess {
                MerchantMarketingHomeSections(home: home, access: access,
                    onRetry: { refreshTask?.cancel(); refreshTask = Task { await loadSurface() } },
                    onInsight: { selected = .insight }, onRoute: onSuggestion, onPush: { marketingPush = $0 })
            }
            if let insight = model.insight { insightSections(insight) }
            if let subscriptions = model.subscriptions { entitlementSections(subscriptions) }
            if let rounds = model.rounds { predictionSections(rounds) }
            if selected == .dashboard, let predictionEntry {
                Section { predictionEntry() }
            }
        }
        }
        }
        .onChange(of: model.homeAccess?.canReadMarketing) { _, canRead in if canRead == false, selected == .insight { selected = .dashboard } }
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.merchant)
        .merchantRootHidesBarTitle()
        .refreshable { await loadSurface() }
        .navigationDestination(item: $marketingPush) { push in
            Group {
                if let marketingLinks { marketingLinks.destination(push) }
            }
            .cyPushedChrome(domain: .merchant)
        }
        .task(id: loadKey) { await loadSurface() }
        .onChange(of: loadKey) { _, _ in refreshTask?.cancel(); refreshTask = nil; loadedRecommendationOrigin = nil }
        .onDisappear { refreshTask?.cancel(); refreshTask = nil }
        .background {
            if let accepted = model.review {
                MerchantPredictionReviewPresentationOwner(model: model, accepted: accepted)
                    .id(accepted.id)
            }
        }
    }
    private func loadSurface() async {
        let origin = recommendationOrigin, scope = model.service.scope
        loadedRecommendationOrigin = nil
        await model.load(selected)
        guard !Task.isCancelled, model.service.scope == scope, !model.busy,
              recommendationOrigin == origin, model.insight != nil else { return }
        loadedRecommendationOrigin = origin
    }
    /// Nothing of the selected surface is on screen: the MP replaces the page body with one state.
    private var surfaceIsEmpty: Bool {
        switch selected {
        case .dashboard: return model.home == nil
        case .insight: return model.insight == nil
        case .subscriptions: return model.subscriptions == nil
        case .predictions: return model.rounds == nil
        }
    }
    @ViewBuilder private func failure(_ error: MerchantMarketingFailure) -> some View {
        if surfaceIsEmpty, !model.busy, error != .signIn, !(error == .denied && selected == .dashboard) {
            // MC7-10-3 / MC7-11-6: 商家营销加载失败 / 当前身份不能查看店铺数据 / 店铺数据加载失败 + the server reason + 重新加载.
            Section {
                if error == .denied {
                    MerchantDeniedState(title: "merchant.gate.insight.denied", identifier: "merchantMarketing.denied")
                } else {
                    MerchantLoadFailedState(title: selected == .insight ? "merchant.gate.insight.loadFailed" : "merchant.gate.marketing.loadFailed",
                                            message: error.serverMessage, identifier: "merchantMarketing.loadFailed") {
                        refreshTask?.cancel(); refreshTask = Task { await loadSurface() }
                    }
                }
            }
            .listRowBackground(Color.clear)
        } else {
            legacyFailure(error)
        }
    }
    private func legacyFailure(_ error: MerchantMarketingFailure) -> some View {
        Section {
            if error == .denied && selected == .dashboard {
                // Source marketing/index.wxml denied inline error; the owner always has marketing read.
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.denied.title"))
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.denied.body")).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("merchantOps.marketing.denied")
                CYPillButton(verbatim: MerchantOpsCopy.text("merchantOps.marketing.denied.retry"), style: .secondary) { refreshTask?.cancel(); refreshTask = Task { await loadSurface() } }
                    .accessibilityIdentifier("merchantOps.marketing.denied.retry")
            }
            Text(LocalizedStringKey(error.key)).accessibilityIdentifier("merchantMarketing.error")
            if let message = error.serverMessage { Text(message).font(.footnote) }
        }
    }
    private func value(_ number: Int?) -> String { number.map(String.init) ?? "—" }
    private func percent(_ number: Double?) -> String { number.map { String(format: "%.1f%%", $0 * 100) } ?? "—" }
    // Source ai-insight order: visits/check-ins/redemptions, hours and new vs returning, recent visitors,
    // recommended topics, recommended partners, business interpretation. The cooperation profile comes last.
    /// Reuses the existing cooperation-center read route; no new grant or writer.
    private func cooperationCenterAction(insight: MerchantMarketingInsight) -> (() -> Void)? {
        guard let origin = loadedRecommendationOrigin, origin == recommendationOrigin,
              let scope = model.service.scope, !model.busy, model.failure == nil,
              model.insight == insight else { return nil }
        return {
            guard scenePhase == .active, model.service.scope == scope, !model.busy, model.failure == nil,
                  model.insight == insight, recommendationOrigin == origin,
                  loadedRecommendationOrigin == origin else { return }
            onSuggestion(.cooperationCenter(origin))
        }
    }
    @ViewBuilder private func insightSections(_ insight: MerchantMarketingInsight) -> some View {
        // MC8-11-1: 早上好，店名 + logo from the insight's `profile`.
        Section { MerchantInsightGreeting(profile: insight.metadata["profile"]) }
        // MC8-11-2/-3/-4/-8: hero number + 环比, 近7/30/90天, daily heat grid, 到店/打卡/核销 switch (unknown facts: none).
        if MerchantInsightAttribution(insight.facts).counts != nil {
            MerchantInsightHeroSection(facts: insight.facts, trends: insight.metadata["trends"])
        }
        MerchantInsightAttributionSummary(summary: .init(insight.facts),
            isCurrent: !model.busy && model.service.scope != nil && loadedRecommendationOrigin != nil
                && loadedRecommendationOrigin == recommendationOrigin && model.insight == insight, facts: insight.facts,
            onCoopCenter: cooperationCenterAction(insight: insight),
            onReload: { refreshTask?.cancel(); refreshTask = Task { await loadSurface() } })
        Section("merchantMarketing.facts") {
            CYListRow("merchantMarketing.window", trailing: .value(MerchantInsightAttribution(insight.facts).window ?? "—"))
            CYListRow("merchantMarketing.sample", trailing: .value(value(insight.facts["sampleMembers"].integer)))
            if insight.facts["lowSample"].isTrue { Text("merchantMarketing.lowSample") }
            CYListRow("merchantMarketing.checkins", trailing: .value(value(insight.facts["checkin"]["total"].integer)))
            CYListRow("merchantMarketing.redemptionRate", trailing: .value(percent(insight.facts["checkin"]["redeemRate"].decimal)))
            Text("merchant.insightAttribution.redemptionScope").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            CYListRow("merchantMarketing.repeatRate", trailing: .value(percent(insight.facts["checkin"]["repeatRate"].decimal)))
            Text("merchant.insightAttribution.repeatScope").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            CYListRow("merchantMarketing.wait", trailing: .value(value(insight.facts["checkin"]["avgWaitMinutes"].integer)))
            CYListRow("merchantMarketing.members", trailing: .value(value(insight.facts["crowd"]["members"].integer)))
            CYListRow("merchantMarketing.offers", trailing: .value(value(insight.facts["supply"]["activeOffers"].integer)))
            CYListRow("merchantMarketing.quotaRate", trailing: .value(percent(insight.facts["supply"]["quotaUsedRate"].decimal)))
            CYListRow("merchantMarketing.maleRate", trailing: .value(percent(insight.facts["crowd"]["sexRatio"]["male"].decimal)))
            CYListRow("merchantMarketing.femaleRate", trailing: .value(percent(insight.facts["crowd"]["sexRatio"]["female"].decimal)))
            ForEach(Array((insight.facts["crowd"]["interestTop"].array ?? []).enumerated()), id: \.offset) { _, interest in
                if let text = interest.text { CYListRow("merchantMarketing.interest", trailing: .value(text)) }
            }
        }
        // MC7-11-3 (ai-insight/index.js:611 `_buildSlots`): 到店时段 reads facts.checkin.slotBuckets (早/午/晚/夜) via Core
        // MerchantInsightSlots — four bars, 共 N 次打卡 and the peak line. No buckets or a zero total hides the section.
        if let slots = MerchantInsightSlots.build(insight.facts) {
            MerchantInsightSlotsSection(slots: slots)
        }
        // MC8-11-5: 客源主题 after 到店时段.
        MerchantInsightSourcesSection(facts: insight.facts)
        MerchantInsightRecentVisitorsSection(visitors: .init(insight.metadata["recentVisitors"]),
            isCurrent: !model.busy && model.service.scope != nil && loadedRecommendationOrigin != nil
                && loadedRecommendationOrigin == recommendationOrigin && model.insight == insight)
        Section("merchantMarketing.recommendedTopics") {
            recommendationRows(insight.recommendedTopics, kind: .topic, insight: insight)
            if let openCoopCenter = cooperationCenterAction(insight: insight) {
                CYPillButton("merchant.insightCooperationCenter.open", style: .secondary, action: openCoopCenter)
                    .accessibilityIdentifier("merchant.insightCooperationCenter.open")
            }
        }
        // MC8-11-6: 俱乐部合作 pool cards under 为你推荐的主题.
        MerchantInsightPoolCardsSection()
        Section("merchantMarketing.recommendedPartners") {
            recommendationRows(insight.recommendedPartners, kind: .partner, insight: insight)
        }
        // MC7-11-10 (owner 2026-10-23): without an interpretation the whole 经营解读 section is hidden.
        if let ai = insight.ai {
            Section {
                Text("merchantMarketing.suggestionNotice").font(.footnote)
                Text(ai["summary"].text ?? "—")
                if !model.busy, model.service.scope != nil, loadedRecommendationOrigin != nil,
                   loadedRecommendationOrigin == recommendationOrigin, model.insight == insight {
                    if insight.facts["lowSample"].isTrue { Text("merchantMarketing.lowSample").font(.footnote) }
                    if let opportunity = insight.opportunity {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("merchant.insightInterpretation.opportunity").font(.headline)
                            Text(verbatim: opportunity)
                        }.accessibilityElement(children: .combine)
                            .accessibilityIdentifier("merchant.insightInterpretation.opportunity")
                    }
                    if let problem = insight.problem {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("merchant.insightInterpretation.problem").font(.headline)
                            Text(verbatim: problem)
                        }.accessibilityElement(children: .combine)
                            .accessibilityIdentifier("merchant.insightInterpretation.problem")
                    }
                }
                ForEach(Array((ai["audiences"].array ?? []).enumerated()), id: \.offset) { _, audience in
                    VStack(alignment: .leading) { Text(audience["label"].text ?? "—"); if let reason = audience["reason"].text { Text(reason) } }
                }
                if let error = insight.aiError, !error.isEmpty { Text(error) }
            } header: {
                Text("merchantMarketing.suggestions")
            } footer: {
                // MC7-11-9 (ai-insight/index.wxml:239): the source line replaces the 生成时间 row.
                if let date = insight.generatedAt {
                    Text("merchant.insight.aiSource \(date)").accessibilityIdentifier("merchant.insight.aiSource")
                }
            }
        }
        if !insight.suggestions.isEmpty {
            Section {
                ForEach(Array(insight.suggestions.enumerated()), id: \.offset) { index, suggestion in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(suggestion.title).font(.headline)
                        if let reason = suggestion.reason { Text(reason) }
                        if let slot = suggestion.timeSlot { Text(slot) }
                        if let audience = suggestion.audience { Text(audience) }
                        if let destination = suggestion.destination {
                            CYPillButton("merchantMarketing.openSuggestion", style: index == 0 ? .primary : .secondary) { onSuggestion(destination) }
                                .accessibilityHint(suggestion.title)
                        }
                    }
                }
            }
        }
        insightProfile(insight)
        // MC8-11-7: 经营优化 cards the current role can act on.
        MerchantInsightGrowTipsSection(access: model.homeAccess,
            canOpenCoop: marketingLinks?.coopCenter != nil || cooperationCenterAction(insight: insight) != nil,
            canOpenCoupons: marketingLinks != nil) { tip in
            switch tip {
            case .coop:
                if marketingLinks?.coopCenter != nil { marketingPush = .coopCenter }
                else { cooperationCenterAction(insight: insight)?() }
            case .coupon: marketingPush = .coupons
            }
        }
    }
    private func recommendationRows(_ rows: [MerchantMarketingValue], kind: MerchantInsightRecommendationRoute.Kind, insight: MerchantMarketingInsight) -> some View {
        let scope = model.service.scope
        let origin = !model.busy && loadedRecommendationOrigin == recommendationOrigin ? loadedRecommendationOrigin : nil
        return MerchantInsightRecommendationRows(rows: rows, kind: kind, origin: origin) { route in
            guard scope != nil, model.service.scope == scope, model.insight == insight, !model.busy,
                  route.origin == recommendationOrigin, loadedRecommendationOrigin == recommendationOrigin else { return }
            onSuggestion(.recommendation(route))
        }
    }
    private func insightProfile(_ insight: MerchantMarketingInsight) -> some View {
        let scope = model.service.scope
        let origin = !model.busy && loadedRecommendationOrigin == recommendationOrigin ? loadedRecommendationOrigin : nil
        return MerchantInsightProfileSummary(profile: insight.metadata["profile"], origin: origin) { source in
            guard scope != nil, model.service.scope == scope, model.insight == insight, !model.busy,
                  source == recommendationOrigin, loadedRecommendationOrigin == recommendationOrigin else { return }
            onSuggestion(.cooperationSettings(source))
        }
    }
    @ViewBuilder private func entitlementSections(_ subscriptions: [MerchantMarketingEntitlement]) -> some View {
        Section("merchantMarketing.activeEntitlements") {
            if subscriptions.isEmpty {
                CYEmptyState(systemImage: "ticket", "merchantMarketing.noEntitlements")
                    .accessibilityIdentifier("merchantMarketing.emptyEntitlements")
            }
            ForEach(Array(subscriptions.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(entitlementTitle(item.subscriptionType))).font(.headline)
                    if item.isPermanent { Text("merchantMarketing.permanent") } else { Text(item.endDate ?? "—") }
                    if let max = item.maxUsage { LabeledContent("merchantMarketing.usage", value: "\(value(item.usedCount)) / \(max)") }
                }.accessibilityElement(children: .combine)
            }
        }
        Section("merchantMarketing.capabilities") {
            if let error = model.commerceFailure { Text(LocalizedStringKey(error.key)); if let message = error.serverMessage { Text(message) } }
            if let commerce = model.commerce {
                if let quota = commerce.premiumTemplate { quotaRow("merchantMarketing.premium", quota) }
                if let quota = commerce.cityNode { quotaRow("merchantMarketing.cityNode", quota) }
            }
        }
    }
    private func entitlementTitle(_ type: String) -> String {
        switch type { case "premium_template": return "merchantMarketing.premium"; case "promotion_slot": return "merchantMarketing.promotion"; case "brand_home": return "merchantMarketing.brand"; case "custom_event": return "merchantMarketing.customEvent"; default: return type }
    }
    private func quotaRow(_ key: String, _ quota: MerchantMarketingCommerce.Quota) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(key)).font(.headline)
            CYListRow("merchantMarketing.used", trailing: .value(value(quota.used)))
            CYListRow("merchantMarketing.limit", trailing: .value(value(quota.limit)))
            CYListRow("merchantMarketing.remaining", trailing: .value(value(quota.remaining)))
        }.accessibilityElement(children: .combine)
    }
    @ViewBuilder private func predictionSections(_ rounds: [MerchantPredictionRound]) -> some View {
        if rounds.isEmpty { Section { CYEmptyState(systemImage: "questionmark.circle", "merchantMarketing.emptyPredictions") } }
        ForEach(rounds) { round in
            Section {
                Text(round.nodeName ?? appLocalized("merchantMarketing.unnamed", locale: locale)).font(.headline)
                Text(round.playDay); if let question = round.question { Text(question) }
                if let days = round.daysLeft {
                    if days <= 0 { CYStatusChip("merchantMarketing.today", tone: .danger, systemImage: "exclamationmark.circle") }
                    else { LabeledContent("merchantMarketing.daysLeft", value: String(days)) }
                }
                if let count = round.betCount, count > 0 { LabeledContent("merchantMarketing.bets", value: String(count)) }
                else if round.betCount == 0 { Text("merchantMarketing.noBets") }
                ForEach(round.options) { option in
                    // Options are actions only where settlement is wired; otherwise they are listed as text.
                    if model.service.permitsSettlement {
                        Button { Task { await model.prepare(round, option: option.key) } } label: { Text(option.label) }
                        .disabled(model.busy)
                        .accessibilityIdentifier("merchantMarketing.option.\(option.key)")
                        .accessibilityHint(Text("merchantMarketing.reviewHint"))
                    } else {
                        Text(option.label).accessibilityIdentifier("merchantMarketing.option.\(option.key)")
                    }
                }
            }
        }
    }
}

private struct MerchantPredictionReviewView: View {
    @Environment(\.locale) private var locale
    @Bindable var model: MerchantMarketingCoordinator
    let accepted: MerchantPredictionReview
    @State private var acknowledged = false
    var body: some View {
        NavigationStack {
            Form {
                CYHeroHeader("merchantMarketing.review")
                Section("merchantMarketing.review") {
                    Text(accepted.round.nodeName ?? appLocalized("merchantMarketing.unnamed", locale: locale))
                    Text(accepted.round.playDay); Text(accepted.round.question ?? "—")
                    LabeledContent("merchantMarketing.answer", value: accepted.option.label)
                    Text("merchantMarketing.couponWarning").font(.headline)
                    Toggle("merchantMarketing.acknowledgeEffects", isOn: $acknowledged).accessibilityIdentifier("merchantMarketing.acknowledgeEffects")
                }
                Button("merchantMarketing.confirmSettlement", role: .destructive) {
                    let effectsAcknowledged = acknowledged
                    Task { await model.confirm(reviewID: accepted.id, couponEffectsAcknowledged: effectsAcknowledged) }
                }
                    .disabled(!acknowledged || model.busy || model.review?.id != accepted.id).accessibilityIdentifier("merchantMarketing.confirmSettlement")
            }
            .toolbar { Button("merchantMarketing.cancel") { model.cancelReview(id: accepted.id) }.disabled(model.busy) }
            .interactiveDismissDisabled(model.busy)
        }
    }
}

@MainActor extension MerchantMarketingCoordinator {
    func predictionReviewPresentation(for accepted: MerchantPredictionReview?) -> Binding<MerchantPredictionReview?> {
        Binding(get: {
            guard let accepted, self.review?.id == accepted.id, self.service.scope == accepted.scope else { return nil }
            return accepted
        }, set: { value in
            if value == nil, let accepted { self.cancelReview(id: accepted.id) }
        })
    }
}

@MainActor private struct MerchantPredictionReviewPresentationOwner: View {
    @Bindable var model: MerchantMarketingCoordinator
    let accepted: MerchantPredictionReview
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .cySheet(item: model.predictionReviewPresentation(for: accepted),
                   onDismiss: { model.cancelReview(id: accepted.id) }) { review in
                Group {
                    MerchantPredictionReviewView(model: model, accepted: review)
                }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
            }
    }
}
