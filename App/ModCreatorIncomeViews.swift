import SwiftUI

@MainActor struct ModCreatorIncomeListView: View {
    @State private var model: ModCreatorIncomeBrowser
    @State private var selection: ModCreatorIncomeSelection?
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    @EnvironmentObject private var session: AppSession
    @ScaledMetric(relativeTo: .largeTitle) private var heroArtHeight: CGFloat = 132
    init(reader: ModSettlementReader) { _model = State(initialValue: ModCreatorIncomeBrowser(reader: reader)) }
    private func text(_ zh: String, _ en: String) -> String { locale.language.languageCode?.identifier == "zh" ? zh : en }
    private var payoutOpen: Bool { ReviewedAreaSwitch.payoutOpen(session: session) }
    private func shown(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : raw
    }
    var body: some View {
        List {
            Section {
                CYHeroHeader(verbatim: text("MOD 原收入事实", "Original MOD income facts")) {
                    CYCoverArt(seed: "mod-creator-income", symbol: "chart.bar.doc.horizontal", showsDebugLabel: false, cornerRadius: CYRadius.lg)
                        .frame(height: heroArtHeight)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            ModCreatorIncomeBoundary()
            if !payoutOpen {
                Section {
                    Text(verbatim: text("收入读取未开启。页面保留，本次不请求收入。未知项显示为 —。", "Income reads are off. This page stays here and does not request income. Unknown values stay —."))
                        .cyText(.label)
                }
            }
            if model.loading { CYSkeleton(label: "uiCloud24.income.loading") }
            if let issue = model.issue {
                Section {
                    CYEmptyState(
                        systemImage: "exclamationmark.triangle",
                        LocalizedStringKey(stringLiteral: modSettlementText(issue.localizationKey, locale: locale)),
                        detail: LocalizedStringKey(stringLiteral: text(
                            "本次读取未确认；不按空列表或零金额处理。已读旧页不是新的渠道观察。",
                            "This read is unconfirmed, not an empty ledger or zero amount. Earlier pages are not a new provider observation."
                        )),
                        actionTitle: LocalizedStringKey(stringLiteral: text("重读原事实首页", "Read original first page")),
                        actionStyle: .secondary,
                        kind: .failure
                    ) { if payoutOpen { Task { await model.refresh() } } }
                    .disabled(model.loading)
                }
            }
            if model.hasCurrentPage {
                Section {
                    if model.visibleFacts.isEmpty {
                        CYEmptyState(
                            systemImage: "tray",
                            LocalizedStringKey(stringLiteral: text(
                                "本次原事实首页为空。这里不包含活动售票、钱包余额或尚未确认的收入，不据此推断没有退款/拒付。",
                                "The original fact page is empty. It excludes activity tickets, wallet balances and unconfirmed income; it does not prove there are no refunds or chargebacks."
                            )),
                            kind: .orders
                        )
                    }
                    ForEach(model.visibleFacts) { fact in
                        Button { selection = model.select(fact) } label: {
                            incomeRow(fact)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("modCreatorIncome.order." + fact.orderKey)
                    }
                    if model.nextCursor != nil {
                        CYPillButton(verbatim: text("读取下一页原事实", "Read next original page"), style: .secondary) { if payoutOpen { Task { await model.more() } } }
                            .disabled(model.loading || model.loadingMore)
                            .listRowBackground(Color.clear)
                    }
                    if model.loadingMore { ProgressView() }
                    if let at = model.readAt {
                        LabeledContent(text("本机最近读取时间", "Last local read")) { Text(at, style: .time) }
                    }
                } header: {
                    CYSectionHeader(LocalizedStringKey(stringLiteral: text("本人原作品交易分配", "My original MOD allocations")))
                }
            }
        }
        .walletContentList()
        .cyGroupedSurface()
        .cyHeroScreen()
        .privacySensitive()
        .task { if payoutOpen { await model.refresh() } }
        .refreshable { if payoutOpen { await model.refresh() } }
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { if payoutOpen { Task { await model.refresh() } } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel(text("刷新原收入事实", "Refresh original income facts"))
            .disabled(model.loading)
        } }
        .navigationDestination(item: $selection) { selected in
            ModCreatorIncomeDetailView(reader: model.reader, selection: selected).id(selected.id)
        }
        .onDisappear { model.invalidate() }
        .onChange(of: phase) { _, next in if next == .active { if payoutOpen { Task { await model.refresh() } } } else { model.invalidate() } }
        .onChange(of: selection?.id) { _, id in if id == nil, payoutOpen { Task { await model.refresh() } } }
        .cyDomainScreen(.topicEditor)
    }

    private func incomeRow(_ fact: ModCreatorIncomeFact) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(alignment: .center, spacing: CYSpacing.md) {
                CYCoverArt(seed: fact.orderKey, symbol: "doc.text", showsDebugLabel: false, cornerRadius: CYRadius.sm)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text(verbatim: shown(fact.modReleaseId))
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: shown(fact.orderKey))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: CYSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(CYColor.textTertiary)
                    .accessibilityHidden(true)
            }
            Text(verbatim: fact.currency + " " + String(fact.creatorAmount) + " · " + text("原分配最小币种单位", "allocated minor units"))
                .cyText(.numericBody)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: text("原事实修订 ", "Original revision ") + String(fact.revision))
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            if fact.disputed {
                CYStatusChip(verbatim: text("原事实有争议标记", "Original dispute flag"), tone: .warning, systemImage: "exclamationmark.shield")
            }
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

@MainActor private struct ModCreatorIncomeDetailView: View {
    @State private var model: ModCreatorIncomeDetailModel
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    @EnvironmentObject private var session: AppSession
    @ScaledMetric(relativeTo: .largeTitle) private var heroArtHeight: CGFloat = 132
    init(reader: ModSettlementReader, selection: ModCreatorIncomeSelection) {
        _model = State(initialValue: ModCreatorIncomeDetailModel(reader: reader, selection: selection))
    }
    private func text(_ zh: String, _ en: String) -> String { locale.language.languageCode?.identifier == "zh" ? zh : en }
    private var payoutOpen: Bool { ReviewedAreaSwitch.payoutOpen(session: session) }
    var body: some View {
        List {
            Section {
                CYHeroHeader(verbatim: text("原单收入事实", "Original income fact")) {
                    CYCoverArt(seed: model.selection.orderKey, symbol: "doc.text.magnifyingglass", showsDebugLabel: false, cornerRadius: CYRadius.lg)
                        .frame(height: heroArtHeight)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            ModCreatorIncomeBoundary()
            if model.loading { CYSkeleton(label: "uiCloud24.incomeDetail.loading") }
            if !model.isCurrentScope {
                Text(verbatim: modSettlementText(ModSettlementIssue.stale.localizationKey, locale: locale))
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if let issue = model.issue {
                    Section {
                        CYEmptyState(
                            systemImage: "exclamationmark.triangle",
                            LocalizedStringKey(stringLiteral: modSettlementText(issue.localizationKey, locale: locale)),
                            detail: LocalizedStringKey(stringLiteral: text(
                                "原单本次结果 UNKNOWN；未改金额、原请求或收款状态。",
                                "The original order read is UNKNOWN. No amount, request or payout state was changed."
                            )),
                            kind: .failure
                        )
                    }
                }
                if let current = model.visibleCurrent {
                    Section {
                        ModCreatorIncomeFactView(fact: current)
                        if let at = model.readAt { LabeledContent(text("本机读取时间", "Local read time")) { Text(at, format: .dateTime) } }
                    } header: {
                        CYSectionHeader(LocalizedStringKey(stringLiteral: text("本次原单事实（不是渠道查询）", "Original order fact, not a provider query")))
                    }
                    Section {
                        Text(verbatim: text("按本次修订固定读取：", "Read through original revision: ") + String(current.revision))
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                        if let issue = model.historyIssue {
                            CYEmptyState(
                                systemImage: "exclamationmark.triangle",
                                LocalizedStringKey(stringLiteral: modSettlementText(issue.localizationKey, locale: locale)),
                                detail: LocalizedStringKey(stringLiteral: text(
                                    "历史本次未确认；保留独立读到的原单事实，不补造缺失修订。",
                                    "History is unconfirmed. The separately read order fact is retained; missing revisions are not synthesized."
                                )),
                                actionTitle: LocalizedStringKey(stringLiteral: text("重读同一历史范围", "Retry same history scope")),
                                actionStyle: .secondary,
                                kind: .failure
                            ) { if payoutOpen { Task { await model.retryHistory() } } }
                            .disabled(model.loading || model.loadingMore)
                        }
                        ForEach(model.revisions, id: \.revision) { fact in
                            DisclosureGroup(text("原修订 ", "Original revision ") + String(fact.revision)) { ModCreatorIncomeFactView(fact: fact) }
                        }
                        if model.nextBeforeRevision != nil {
                            CYPillButton(verbatim: text("读取更早原修订", "Read earlier original revisions"), style: .secondary) { if payoutOpen { Task { await model.moreHistory() } } }
                                .disabled(model.loading || model.loadingMore)
                                .listRowBackground(Color.clear)
                        }
                        if model.loadingMore { ProgressView() }
                        Text(verbatim: text(
                            "刷新原单会重新取得当前原事实；历史页面不把旧累计数当作现在状态。",
                            "Refreshing the order obtains its current original fact. History does not treat older totals as current state."
                        ))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        CYSectionHeader(LocalizedStringKey(stringLiteral: text("原不可变修订历史", "Original immutable revisions")))
                    }
                }
                CYPillButton(verbatim: text("只读刷新同一原单", "Refresh same original order"), style: .primary) { if payoutOpen { Task { await model.refresh() } } }
                    .disabled(model.loading)
                    .listRowBackground(Color.clear)
            }
        }
        .walletContentList()
        .cyGroupedSurface()
        .cyHeroScreen()
        .privacySensitive()
        .task { if payoutOpen { await model.refresh() } }
        .refreshable { if payoutOpen { await model.refresh() } }
        .onDisappear { model.invalidate() }
        .onChange(of: phase) { _, next in if next == .active { if payoutOpen { Task { await model.refresh() } } } else { model.invalidate() } }
        .cyDomainScreen(.topicEditor)
    }
}

private struct ModCreatorIncomeBoundary: View {
    @Environment(\.locale) private var locale
    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        Section {
            boundary(chinese
                ? "这里只读原 MOD 付费交易分配事实。金额不是买家总支付、钱包余额、已收款或可提现金额；不计算新的应付/税额/保留款。"
                : "Read-only original paid MOD allocation facts. Amounts are not buyer gross payments, wallet balances, paid-out funds or available withdrawals. No payable amount, tax or reserve is calculated.")
            boundary(chinese
                ? "退款/拒付数字仅是原 writer 已确认的累计；0 或未标记争议不证明渠道没有争议。本页不调用渠道，也不把 UNKNOWN 变为 0。"
                : "Refund/chargeback amounts are only totals confirmed by the original writer. Zero or an unset dispute flag does not prove there is no provider dispute. This view never queries a provider or converts UNKNOWN to zero.")
            boundary(chinese
                ? "作者身份、收款、税务、版权与风控批准仍看原资格/结算流程；本人历史读取不授予支付、退款、结算申请或发布权限。"
                : "Creator, payout, tax, copyright and risk approval remain in the original qualification/settlement flow. Reading owned history grants no payment, refund, settlement-application or publication permission.")
        }
    }
    private func boundary(_ line: String) -> some View {
        Text(verbatim: line)
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
private struct ModCreatorIncomeFactView: View {
    let fact: ModCreatorIncomeFact
    @Environment(\.locale) private var locale
    private func text(_ zh: String, _ en: String) -> String { locale.language.languageCode?.identifier == "zh" ? zh : en }
    private func shown(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : raw
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(verbatim: text("原作品分配额（最小币种单位）", "Original allocation (minor units)"))
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: fact.currency + " " + String(fact.creatorAmount))
                .cyText(.dataXL)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            value(text("原订单键", "Original order key"), fact.orderKey)
            value(text("原作品 release", "Original MOD release"), fact.modReleaseId)
            value(text("原事实来源", "Original source"), fact.source)
            value(text("修订", "Revision"), String(fact.revision))
            value(text("已确认退款累计（同一分配份额）", "Confirmed refunded allocation"), fact.currency + " " + String(fact.refundedAmount))
            value(text("已确认拒付累计（同一分配份额）", "Confirmed chargeback allocation"), fact.currency + " " + String(fact.chargebackAmount))
            Text(verbatim: text(
                fact.disputed ? "原事实标记有争议" : "本修订未标记争议；不是渠道无争议证明",
                fact.disputed ? "Original fact flags a dispute" : "This revision has no dispute flag; it is not proof of no provider dispute"
            ))
            .cyText(.body)
            .foregroundStyle(CYColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            LabeledContent(text("原交易支付时间（非退款/查询时间）", "Original paid time (not reversal/query time)")) { Text(fact.paidAt, format: .dateTime) }
        }
        .textSelection(.enabled)
    }
    private func value(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: title)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: shown(content))
                .cyText(.body, monospacedDigit: true)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
