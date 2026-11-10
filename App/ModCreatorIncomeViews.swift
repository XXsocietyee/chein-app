import SwiftUI

@MainActor struct ModCreatorIncomeListView: View {
    @State private var model: ModCreatorIncomeBrowser
    @State private var selection: ModCreatorIncomeSelection?
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    init(reader: ModSettlementReader) { _model = State(initialValue: ModCreatorIncomeBrowser(reader: reader)) }
    private func text(_ zh: String, _ en: String) -> String { locale.language.languageCode?.identifier == "zh" ? zh : en }
    var body: some View {
        List {
            Section { CYHeroHeader(verbatim: text("MOD 原收入事实", "Original MOD income facts")).listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            ModCreatorIncomeBoundary()
            if model.loading { ProgressView().accessibilityLabel(Text(verbatim: text("加载中", "Loading"))) }
            if let issue = model.issue {
                Section {
                    Text(modSettlementText(issue.localizationKey, locale: locale))
                    Text(text("本次读取未确认；不按空列表或零金额处理。已读旧页不是新的渠道观察。", "This read is unconfirmed, not an empty ledger or zero amount. Earlier pages are not a new provider observation."))
                    CYPillButton(verbatim: text("重读原事实首页", "Read original first page"), style: .secondary) { Task { await model.refresh() } }.disabled(model.loading)
                }
            }
            if model.hasCurrentPage {
                Section(text("本人原作品交易分配", "My original MOD allocations")) {
                    if model.visibleFacts.isEmpty {
                        Text(text("本次原事实首页为空。这里不包含活动售票、钱包余额或尚未确认的收入，不据此推断没有退款/拒付。", "The original fact page is empty. It excludes activity tickets, wallet balances and unconfirmed income; it does not prove there are no refunds or chargebacks."))
                    }
                    ForEach(model.visibleFacts) { fact in
                        Button { selection = model.select(fact) } label: {
                            VStack(alignment: .leading, spacing: Theme.Space.s2) {
                                Text(verbatim: fact.orderKey).font(Theme.Font.label).foregroundStyle(.secondary)
                                Text(verbatim: fact.modReleaseId).font(Theme.Font.cardTitle)
                                Text(verbatim: fact.currency + " " + String(fact.creatorAmount) + " · " + text("原分配最小币种单位", "allocated minor units")).font(Theme.Font.sectionTitle).monospacedDigit()
                                Text(text("原事实修订 ", "Original revision ") + String(fact.revision)).font(Theme.Font.label).foregroundStyle(.secondary)
                                if fact.disputed { CYStatusChip(verbatim: text("原事实有争议标记", "Original dispute flag"), tone: .warning, systemImage: "exclamationmark.shield") }
                            }.fixedSize(horizontal: false, vertical: true)
                        }.buttonStyle(.plain).accessibilityIdentifier("modCreatorIncome.order." + fact.orderKey)
                    }
                    if model.nextCursor != nil {
                        CYPillButton(verbatim: text("读取下一页原事实", "Read next original page"), style: .secondary) { Task { await model.more() } }
                            .disabled(model.loading || model.loadingMore)
                    }
                    if model.loadingMore { ProgressView().accessibilityLabel(Text(verbatim: text("加载中", "Loading"))) }
                    if let at = model.readAt { LabeledContent(text("本机最近读取时间", "Last local read")) { Text(at, style: .time) } }
                }
            }
        }
        .walletContentList()
        .cyHeroScreen()
        .privacySensitive()
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                .accessibilityLabel(text("刷新原收入事实", "Refresh original income facts")).disabled(model.loading)
        } }
        .navigationDestination(item: $selection) { selected in
            ModCreatorIncomeDetailView(reader: model.reader, selection: selected).id(selected.id)
        }
        .onDisappear { model.invalidate() }
        .onChange(of: phase) { _, next in if next == .active { Task { await model.refresh() } } else { model.invalidate() } }
        .onChange(of: selection?.id) { _, id in if id == nil { Task { await model.refresh() } } }
    }
}

@MainActor private struct ModCreatorIncomeDetailView: View {
    @State private var model: ModCreatorIncomeDetailModel
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    init(reader: ModSettlementReader, selection: ModCreatorIncomeSelection) {
        _model = State(initialValue: ModCreatorIncomeDetailModel(reader: reader, selection: selection))
    }
    private func text(_ zh: String, _ en: String) -> String { locale.language.languageCode?.identifier == "zh" ? zh : en }
    var body: some View {
        List {
            Section { CYHeroHeader(verbatim: text("原单收入事实", "Original income fact")).listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            ModCreatorIncomeBoundary()
            if model.loading { ProgressView().accessibilityLabel(Text(verbatim: text("加载中", "Loading"))) }
            if !model.isCurrentScope {
                Text(modSettlementText(ModSettlementIssue.stale.localizationKey, locale: locale))
            } else {
                if let issue = model.issue {
                    Section {
                        Text(modSettlementText(issue.localizationKey, locale: locale))
                        Text(text("原单本次结果 UNKNOWN；未改金额、原请求或收款状态。", "The original order read is UNKNOWN. No amount, request or payout state was changed."))
                    }
                }
                if let current = model.visibleCurrent {
                    Section(text("本次原单事实（不是渠道查询）", "Original order fact, not a provider query")) {
                        ModCreatorIncomeFactView(fact: current)
                        if let at = model.readAt { LabeledContent(text("本机读取时间", "Local read time")) { Text(at, format: .dateTime) } }
                    }
                    Section(text("原不可变修订历史", "Original immutable revisions")) {
                        Text(text("按本次修订固定读取：", "Read through original revision: ") + String(current.revision))
                            .font(Theme.Font.label)
                        if let issue = model.historyIssue {
                            Text(modSettlementText(issue.localizationKey, locale: locale))
                            Text(text("历史本次未确认；保留独立读到的原单事实，不补造缺失修订。", "History is unconfirmed. The separately read order fact is retained; missing revisions are not synthesized."))
                            CYPillButton(verbatim: text("重读同一历史范围", "Retry same history scope"), style: .secondary) { Task { await model.retryHistory() } }.disabled(model.loading || model.loadingMore)
                        }
                        ForEach(model.revisions, id: \.revision) { fact in
                            DisclosureGroup(text("原修订 ", "Original revision ") + String(fact.revision)) { ModCreatorIncomeFactView(fact: fact) }
                        }
                        if model.nextBeforeRevision != nil {
                            CYPillButton(verbatim: text("读取更早原修订", "Read earlier original revisions"), style: .secondary) { Task { await model.moreHistory() } }.disabled(model.loading || model.loadingMore)
                        }
                        if model.loadingMore { ProgressView().accessibilityLabel(Text(verbatim: text("加载中", "Loading"))) }
                        Text(text("刷新原单会重新取得当前原事实；历史页面不把旧累计数当作现在状态。", "Refreshing the order obtains its current original fact. History does not treat older totals as current state."))
                            .font(Theme.Font.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                CYPillButton(verbatim: text("只读刷新同一原单", "Refresh same original order"), style: .tertiary) { Task { await model.refresh() } }.disabled(model.loading)
            }
        }
        .walletContentList()
        .cyHeroScreen()
        .privacySensitive()
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .onDisappear { model.invalidate() }
        .onChange(of: phase) { _, next in if next == .active { Task { await model.refresh() } } else { model.invalidate() } }
    }
}

private struct ModCreatorIncomeBoundary: View {
    @Environment(\.locale) private var locale
    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        Section {
            Text(chinese ? "这里只读原 MOD 付费交易分配事实。金额不是买家总支付、钱包余额、已收款或可提现金额；不计算新的应付/税额/保留款。" : "Read-only original paid MOD allocation facts. Amounts are not buyer gross payments, wallet balances, paid-out funds or available withdrawals. No payable amount, tax or reserve is calculated.")
            Text(chinese ? "退款/拒付数字仅是原 writer 已确认的累计；0 或未标记争议不证明渠道没有争议。本页不调用渠道，也不把 UNKNOWN 变为 0。" : "Refund/chargeback amounts are only totals confirmed by the original writer. Zero or an unset dispute flag does not prove there is no provider dispute. This view never queries a provider or converts UNKNOWN to zero.")
            Text(chinese ? "作者身份、收款、税务、版权与风控批准仍看原资格/结算流程；本人历史读取不授予支付、退款、结算申请或发布权限。" : "Creator, payout, tax, copyright and risk approval remain in the original qualification/settlement flow. Reading owned history grants no payment, refund, settlement-application or publication permission.")
        }.font(Theme.Font.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
private struct ModCreatorIncomeFactView: View {
    let fact: ModCreatorIncomeFact
    @Environment(\.locale) private var locale
    private func text(_ zh: String, _ en: String) -> String { locale.language.languageCode?.identifier == "zh" ? zh : en }
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s3) {
            value(text("原订单键", "Original order key"), fact.orderKey)
            value(text("原作品 release", "Original MOD release"), fact.modReleaseId)
            value(text("原事实来源", "Original source"), fact.source)
            value(text("修订", "Revision"), String(fact.revision))
            value(text("原作品分配额（最小币种单位）", "Original allocation (minor units)"), fact.currency + " " + String(fact.creatorAmount))
            value(text("已确认退款累计（同一分配份额）", "Confirmed refunded allocation"), fact.currency + " " + String(fact.refundedAmount))
            value(text("已确认拒付累计（同一分配份额）", "Confirmed chargeback allocation"), fact.currency + " " + String(fact.chargebackAmount))
            Text(text(fact.disputed ? "原事实标记有争议" : "本修订未标记争议；不是渠道无争议证明", fact.disputed ? "Original fact flags a dispute" : "This revision has no dispute flag; it is not proof of no provider dispute"))
            LabeledContent(text("原交易支付时间（非退款/查询时间）", "Original paid time (not reversal/query time)")) { Text(fact.paidAt, format: .dateTime) }
        }.textSelection(.enabled)
    }
    private func value(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading) { Text(verbatim: title).font(.caption).foregroundStyle(.secondary); Text(verbatim: content).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true) }
    }
}
